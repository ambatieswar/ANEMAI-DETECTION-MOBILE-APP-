"""Train the real eye/lower-eyelid acceptance model.

Required metadata columns:
    image_path, patient_id, label

`label=1` must mean a usable eye/lower-eyelid image. `label=0` must contain
real non-eye and unsuitable examples (faces, objects, pets, landscapes, closed
eyes, partial eyes, and poor framing). Do not use synthetic random negatives.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import GroupShuffleSplit

IMAGE_SIZE = (224, 224)
AUTOTUNE = tf.data.AUTOTUNE


def dataset(frame: pd.DataFrame, root: Path, batch_size: int, shuffle: bool):
    paths = [str((root / p).resolve()) for p in frame.image_path]
    labels = frame.label.astype("float32").to_numpy()
    ds = tf.data.Dataset.from_tensor_slices((paths, labels))

    def load(path, label):
        image = tf.image.decode_jpeg(tf.io.read_file(path), channels=3)
        image = tf.image.resize(image, IMAGE_SIZE)
        return tf.cast(image, tf.float32), label

    ds = ds.map(load, num_parallel_calls=AUTOTUNE)
    if shuffle:
        ds = ds.shuffle(len(frame), seed=42)
    return ds.batch(batch_size).prefetch(AUTOTUNE)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--metadata-csv", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=Path("models/eye_detector"))
    parser.add_argument("--epochs", type=int, default=25)
    args = parser.parse_args()

    frame = pd.read_csv(args.metadata_csv)
    required = {"image_path", "patient_id", "label"}
    missing = required - set(frame.columns)
    if missing:
        raise ValueError(f"Missing columns: {sorted(missing)}")
    frame["label"] = pd.to_numeric(frame["label"], errors="raise").astype("int32")
    if set(frame.label.unique()) != {0, 1}:
        raise ValueError("Eye detector metadata must contain both labels 0 and 1.")

    split = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=42)
    train_idx, test_idx = next(split.split(frame, groups=frame.patient_id))
    train = frame.iloc[train_idx]
    test = frame.iloc[test_idx]

    backbone = tf.keras.applications.MobileNetV3Small(
        input_shape=(*IMAGE_SIZE, 3),
        include_top=False,
        pooling="avg",
        weights="imagenet",
        name="eye_detector_backbone",
    )
    backbone.trainable = False
    inputs = tf.keras.Input(shape=(*IMAGE_SIZE, 3))
    x = tf.keras.applications.mobilenet_v3.preprocess_input(inputs)
    x = backbone(x, training=False)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid", name="eye_probability")(x)
    model = tf.keras.Model(inputs, outputs)
    model.compile(
        optimizer="adam",
        loss="binary_crossentropy",
        metrics=[tf.keras.metrics.AUC(name="auc"), "accuracy"],
    )
    model.fit(
        dataset(train, args.metadata_csv.parent, 32, True),
        validation_data=dataset(test, args.metadata_csv.parent, 32, False),
        epochs=args.epochs,
        callbacks=[
            tf.keras.callbacks.EarlyStopping(
                monitor="val_auc", mode="max", patience=5, restore_best_weights=True
            )
        ],
    )

    args.output_dir.mkdir(parents=True, exist_ok=True)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    exported = converter.convert()
    model_path = args.output_dir / "eye_detector_float32.tflite"
    model_path.write_bytes(exported)
    manifest = {
        "schema_version": 1,
        "model_id": "eye_detector_mobilenetv3small",
        "enabled": False,
        "status": "review_required",
        "model_sha256": hashlib.sha256(exported).hexdigest(),
        "input": {
            "width": 224,
            "height": 224,
            "channels": 3,
            "normalization": "mobilenet_v3_preprocess_input",
            "dtype": "float32",
        },
        "output": {
            "type": "binary_probability",
            "positive_class": "eye_or_lower_eyelid",
        },
        "patient_level_split": True,
        "test_patients": int(test.patient_id.nunique()),
        "review_checklist": [
            "negative examples cover non-eye and unsuitable image classes",
            "external device and lighting evaluation completed",
            "threshold selected for safe rejection behavior",
        ],
    }
    (args.output_dir / "model_manifest.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
