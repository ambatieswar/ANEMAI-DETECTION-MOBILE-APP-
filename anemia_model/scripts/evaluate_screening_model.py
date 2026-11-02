"""Evaluate held-out, external, subgroup, calibration, and OOD behavior."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.metrics import (
    accuracy_score,
    brier_score_loss,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)


def load(frame, root):
    paths = [str((root / value).resolve()) for value in frame.image_path]
    ds = tf.data.Dataset.from_tensor_slices(paths)

    def decode(path):
        image = tf.image.decode_jpeg(tf.io.read_file(path), channels=3)
        image = tf.image.resize(image, (224, 224))
        return tf.cast(image, tf.float32)

    return ds.map(decode).batch(32)


def metrics(y_true, y_prob):
    y_pred = (y_prob >= 0.5).astype(int)
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred, labels=[0, 1]).ravel()
    return {
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "precision": float(precision_score(y_true, y_pred, zero_division=0)),
        "recall_sensitivity": float(recall_score(y_true, y_pred, zero_division=0)),
        "specificity": float(tn / (tn + fp)) if tn + fp else 0,
        "f1": float(f1_score(y_true, y_pred, zero_division=0)),
        "auc": float(roc_auc_score(y_true, y_prob))
        if len(np.unique(y_true)) == 2
        else None,
        "brier_score": float(brier_score_loss(y_true, y_prob)),
        "confusion_matrix": [[int(tn), int(fp)], [int(fn), int(tp)]],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--metadata-csv", type=Path, required=True)
    parser.add_argument("--output-json", type=Path, required=True)
    parser.add_argument("--ood-csv", type=Path)
    parser.add_argument("--external-csv", type=Path)
    args = parser.parse_args()

    frame = pd.read_csv(args.metadata_csv)
    model = tf.keras.models.load_model(args.model)
    probabilities = model.predict(load(frame, args.metadata_csv.parent), verbose=0).reshape(-1)
    report = {"primary": metrics(frame.label.to_numpy(), probabilities)}

    for column in ("site", "device", "sex", "age_group"):
        if column in frame:
            report["subgroups"] = report.get("subgroups", {})
            report["subgroups"][column] = {}
            for value, subset in frame.groupby(column):
                indices = subset.index.to_numpy()
                report["subgroups"][column][str(value)] = metrics(
                    subset.label.to_numpy(), probabilities[indices]
                )

    if args.external_csv:
        external = pd.read_csv(args.external_csv)
        external_prob = model.predict(
            load(external, args.external_csv.parent), verbose=0
        ).reshape(-1)
        report["external"] = metrics(external.label.to_numpy(), external_prob)

    if args.ood_csv:
        ood = pd.read_csv(args.ood_csv)
        ood_prob = model.predict(load(ood, args.ood_csv.parent), verbose=0).reshape(-1)
        entropy = -(
            ood_prob * np.log(np.clip(ood_prob, 1e-6, 1))
            + (1 - ood_prob) * np.log(np.clip(1 - ood_prob, 1e-6, 1))
        )
        report["ood"] = {
            "method": "predictive_entropy",
            "samples": int(len(ood)),
            "mean_entropy": float(np.mean(entropy)),
            "p95_entropy": float(np.percentile(entropy, 95)),
            "note": "Entropy is a rejection signal, not clinical uncertainty calibration.",
        }

    args.output_json.write_text(json.dumps(report, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
