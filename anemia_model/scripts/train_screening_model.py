"""Train and export a governed anemia screening model.

The script intentionally requires a participant-level metadata CSV. It does
not accept directory names as labels because image-level random splits can
leak the same participant into train and test sets.

Required CSV columns:
    image_path, patient_id, hb_g_dl

Optional:
    site, device, age_years, sex

The binary label is derived from hb_g_dl using the project threshold supplied
on the command line. Clinical teams must review that threshold for the target
population before training.
"""

from __future__ import annotations

import argparse
import json
import hashlib
from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import GroupShuffleSplit
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import brier_score_loss


AUTOTUNE = tf.data.AUTOTUNE
IMAGE_SIZE = (224, 224)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--metadata-csv", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=Path("models"))
    parser.add_argument("--hb-threshold", type=float, default=12.0)
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--no-imagenet-weights", action="store_true")
    return parser.parse_args()


def validate_metadata(frame: pd.DataFrame) -> pd.DataFrame:
    required = {"image_path", "patient_id", "hb_g_dl"}
    missing = required - set(frame.columns)
    if missing:
        raise ValueError(f"Metadata is missing required columns: {sorted(missing)}")

    frame = frame.copy()
    frame["hb_g_dl"] = pd.to_numeric(frame["hb_g_dl"], errors="coerce")
    frame = frame.dropna(subset=["image_path", "patient_id", "hb_g_dl"])
    frame["image_path"] = frame["image_path"].astype(str)
    frame["patient_id"] = frame["patient_id"].astype(str)
    if frame.empty:
        raise ValueError("Metadata contains no usable rows.")
    if frame["patient_id"].nunique() < 5:
        raise ValueError("At least five unique patients are required for a split.")
    return frame


def split_by_patient(
    frame: pd.DataFrame, seed: int
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    outer = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=seed)
    train_val_idx, test_idx = next(
        outer.split(frame, groups=frame["patient_id"])
    )
    train_val = frame.iloc[train_val_idx]
    test = frame.iloc[test_idx]

    inner = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=seed)
    train_idx, val_idx = next(
        inner.split(train_val, groups=train_val["patient_id"])
    )
    return train_val.iloc[train_idx], train_val.iloc[val_idx], test


def make_dataset(
    frame: pd.DataFrame, root: Path, batch_size: int, shuffle: bool, seed: int
) -> tf.data.Dataset:
    paths = [str((root / p).resolve()) for p in frame["image_path"]]
    labels = frame["label"].astype("float32").to_numpy()
    dataset = tf.data.Dataset.from_tensor_slices((paths, labels))

    def load(path: tf.Tensor, label: tf.Tensor):
        image = tf.io.read_file(path)
        image = tf.image.decode_jpeg(image, channels=3)
        image = tf.image.resize(image, IMAGE_SIZE)
        image = tf.cast(image, tf.float32)
        return image, label

    dataset = dataset.map(load, num_parallel_calls=AUTOTUNE)
    if shuffle:
        dataset = dataset.shuffle(len(frame), seed=seed, reshuffle_each_iteration=True)
    return dataset.batch(batch_size).prefetch(AUTOTUNE)


def build_model(use_imagenet_weights: bool) -> tf.keras.Model:
    weights = "imagenet" if use_imagenet_weights else None
    backbone = tf.keras.applications.MobileNetV3Small(
        input_shape=(*IMAGE_SIZE, 3),
        include_top=False,
        weights=weights,
        pooling="avg",
        name="mobile_net_v3_small",
    )
    backbone.trainable = False
    inputs = tf.keras.Input(shape=(*IMAGE_SIZE, 3), name="image")
    x = tf.keras.layers.RandomFlip("horizontal")(inputs)
    x = tf.keras.layers.RandomRotation(0.05)(x)
    x = tf.keras.layers.RandomContrast(0.1)(x)
    x = tf.keras.applications.mobilenet_v3.preprocess_input(x)
    x = backbone(x, training=False)
    x = tf.keras.layers.Dropout(0.25)(x)
    x = tf.keras.layers.Dense(128, activation="relu", name="feature_embedding")(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid", name="risk")(x)
    return tf.keras.Model(inputs, outputs)


def calculate_metrics(y_true: np.ndarray, y_prob: np.ndarray) -> dict:
    y_pred = (y_prob >= 0.5).astype(np.int32)
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred, labels=[0, 1]).ravel()
    return {
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "precision": float(precision_score(y_true, y_pred, zero_division=0)),
        "recall_sensitivity": float(recall_score(y_true, y_pred, zero_division=0)),
        "specificity": float(tn / (tn + fp)) if tn + fp else 0.0,
        "f1": float(f1_score(y_true, y_pred, zero_division=0)),
        "auc": float(roc_auc_score(y_true, y_prob))
        if len(np.unique(y_true)) == 2
        else None,
        "brier_score": float(brier_score_loss(y_true, y_prob)),
        "confusion_matrix": [[int(tn), int(fp)], [int(fn), int(tp)]],
    }


def main() -> None:
    args = parse_args()
    tf.keras.utils.set_random_seed(args.seed)
    args.output_dir.mkdir(parents=True, exist_ok=True)

    metadata = validate_metadata(pd.read_csv(args.metadata_csv))
    metadata["label"] = (metadata["hb_g_dl"] < args.hb_threshold).astype("int32")
    train, validation, test = split_by_patient(metadata, args.seed)

    train_ds = make_dataset(
        train, args.metadata_csv.parent, args.batch_size, True, args.seed
    )
    validation_ds = make_dataset(
        validation, args.metadata_csv.parent, args.batch_size, False, args.seed
    )
    test_ds = make_dataset(
        test, args.metadata_csv.parent, args.batch_size, False, args.seed
    )

    model = build_model(not args.no_imagenet_weights)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss=tf.keras.losses.BinaryCrossentropy(),
        metrics=[
            tf.keras.metrics.BinaryAccuracy(name="accuracy"),
            tf.keras.metrics.AUC(name="auc"),
        ],
    )

    positives = int(train["label"].sum())
    negatives = len(train) - positives
    if not positives or not negatives:
        raise ValueError("Training split must contain both classes.")
    class_weight = {
        0: len(train) / (2 * negatives),
        1: len(train) / (2 * positives),
    }
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_auc", mode="max", patience=7, restore_best_weights=True
        ),
        tf.keras.callbacks.ModelCheckpoint(
            args.output_dir / "best.keras",
            monitor="val_auc",
            mode="max",
            save_best_only=True,
        ),
    ]
    model.fit(
        train_ds,
        validation_data=validation_ds,
        epochs=args.epochs,
        class_weight=class_weight,
        callbacks=callbacks,
    )

    y_true = test["label"].to_numpy()
    y_prob = model.predict(test_ds, verbose=0).reshape(-1)
    metrics = calculate_metrics(y_true, y_prob)
    calibration = LogisticRegression(solver="lbfgs")
    val_prob = model.predict(validation_ds, verbose=0).reshape(-1)
    calibration.fit(val_prob.reshape(-1, 1), validation["label"].to_numpy())
    calibrated_test_prob = calibration.predict_proba(y_prob.reshape(-1, 1))[:, 1]
    metrics["calibrated_brier_score"] = float(
        brier_score_loss(y_true, calibrated_test_prob)
    )
    metrics["calibration"] = {
        "method": "platt_scaling",
        "fitted_on": "patient_level_validation_split",
    }
    metrics["split"] = {
        "train_patients": int(train["patient_id"].nunique()),
        "validation_patients": int(validation["patient_id"].nunique()),
        "test_patients": int(test["patient_id"].nunique()),
        "train_images": len(train),
        "validation_images": len(validation),
        "test_images": len(test),
    }
    (args.output_dir / "test_metrics.json").write_text(
        json.dumps(metrics, indent=2), encoding="utf-8"
    )

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite = converter.convert()
    tflite_path = args.output_dir / "anemia_screening_float32.tflite"
    tflite_path.write_bytes(tflite)
    sha256 = hashlib.sha256(tflite).hexdigest()

    manifest = {
        "schema_version": 1,
        "model_id": "anemia_screening_mobilenetv3small",
        "enabled": False,
        "status": "review_required",
        "model_sha256": sha256,
        "input": {
            "width": IMAGE_SIZE[1],
            "height": IMAGE_SIZE[0],
            "channels": 3,
            "normalization": "mobilenet_v3_preprocess_input",
            "dtype": "float32",
        },
        "output": {
            "type": "binary_probability",
            "positive_class": "screening_increased_risk",
            "calibrated": False,
        },
        "training": {
            "hb_threshold_g_dl": args.hb_threshold,
            "patient_level_split": True,
            "metrics_path": "test_metrics.json",
            "calibration_path": "calibration.json",
        },
        "review_checklist": [
            "clinical dataset provenance and license reviewed",
            "external site/device test completed",
            "calibration completed on held-out data",
            "quality and eye detector validated",
            "medical and regulatory review completed",
        ],
    }
    (args.output_dir / "model_manifest.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8"
    )
    (args.output_dir / "calibration.json").write_text(
        json.dumps(
            {
                "method": "platt_scaling",
                "intercept": float(calibration.intercept_[0]),
                "coefficient": float(calibration.coef_[0][0]),
                "validation_patients": int(validation["patient_id"].nunique()),
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(json.dumps(metrics, indent=2))
    print(f"Exported {tflite_path}")


if __name__ == "__main__":
    main()
