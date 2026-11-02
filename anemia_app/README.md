# HemoScan Edge

Offline Flutter prototype for AI-assisted anemia-risk screening from a
palpebral-conjunctiva image.

## Safety status

This repository is **not a clinically validated diagnostic product**. The
bundled anemia model is disabled through `assets/model_manifest.json` because
its dataset provenance, patient-level split, calibration, external validation,
and out-of-distribution behavior have not been established. The eye detector
also fails closed until a real, validated detector is installed.

The app must not claim that a person has or does not have anemia. The intended
message is:

> This application is an AI-assisted screening tool. It cannot diagnose
> anemia. Consult a qualified healthcare professional for laboratory
> confirmation.

## Project documentation

- [`../docs/ENGINEERING_BLUEPRINT.md`](../docs/ENGINEERING_BLUEPRINT.md):
  dataset decision record, model/runtime selection, pipeline, diagrams,
  security checklist, and competition roadmap.
- [`../anemia_model/README.md`](../anemia_model/README.md): governed training
  workflow and model-release boundary.
- `../anemia_model/scripts/train_screening_model.py`: patient-level split,
  metrics, TFLite export, SHA-256, and review-required manifest generation.

## Local development

```powershell
flutter pub get
flutter analyze
flutter test
```

The current tests verify the UI loads and that image validation rejects input
when no real eye detector is available. Do not enable a model by editing the
manifest unless the model review checklist has been completed and the model
contract matches the manifest.
