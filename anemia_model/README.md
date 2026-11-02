# HemoScan Edge model pipeline

This directory contains code and governance documentation only. The local
clinical image folders, path-bearing image inventory, virtual environment, and
training checkpoints are excluded from Git and must not be redistributed
without a separate data and licensing review.

The existing `models/anemia_model.tflite` is retained as a development artifact
only. It is not approved for user-facing screening because its dataset
provenance, patient-level split, calibration, external validation, and
out-of-distribution behavior are not established.

Use `scripts/train_screening_model.py` only after a clinical dataset has been
obtained under terms that permit the intended research use. The required
metadata CSV must contain `image_path`, `patient_id`, and `hb_g_dl`. The script
derives the binary label from laboratory hemoglobin and splits by participant,
not by image.

The export is deliberately marked `enabled: false` in its manifest. A clinical
review process must complete the manifest checklist and independently review
the model hash before enabling it in the Android asset bundle. No accuracy or
clinical performance claim should be made from this repository's current
artifacts.

Additional scripts:

- `train_eye_detector.py` trains the real eye/lower-eyelid acceptance model
  from labeled positives and real unsuitable-image negatives.
- `evaluate_screening_model.py` reports held-out, external, subgroup,
  calibration, and predictive-entropy OOD evidence.
- `gradcam.py` generates a heatmap from the model's actual convolutional
  activations and gradients. It does not generate placeholder overlays.
