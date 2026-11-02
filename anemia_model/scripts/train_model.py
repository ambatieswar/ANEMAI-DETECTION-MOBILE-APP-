"""Compatibility entrypoint for the governed training pipeline.

Use train_screening_model.py directly. This file remains so existing local
commands fail with a clear migration message instead of training the old
image-level-split prototype.
"""

raise SystemExit(
    "The legacy training script is disabled. "
    "Run scripts/train_screening_model.py with a patient-level metadata CSV."
)
