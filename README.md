# HemoScan Edge

Offline Flutter prototype for AI-assisted anemia-risk screening from a
palpebral-conjunctiva image, with a Python workflow for governed model
training and evaluation.

## Safety status

This project is **not a clinically validated diagnostic product**. The app
must not claim that a person has or does not have anemia. The bundled
prototype model and eye detector remain disabled through their manifests until
the release gates in [`docs/RELEASE_READINESS.md`](docs/RELEASE_READINESS.md)
are completed.

The required user-facing message is:

> This application is an AI-assisted screening tool. It cannot diagnose
> anemia. Consult a qualified healthcare professional for laboratory
> confirmation.

No clinical performance metrics are claimed by this repository. Dataset
access, licensing, provenance, patient-level splitting, calibration, external
validation, and out-of-distribution behavior require independent review.

## Repository layout

| Path | Purpose |
| --- | --- |
| [`anemia_app/`](anemia_app/) | Flutter application and safety-gated local inference boundary |
| [`anemia_model/`](anemia_model/) | Training, evaluation, export, and attribution scripts |
| [`docs/`](docs/) | Engineering, privacy, dataset, and release-readiness documentation |

Clinical datasets, path-bearing metadata, virtual environments, generated
build output, and training checkpoints are intentionally excluded from Git.
Obtain data only under terms that permit the intended research use and create a
reviewed metadata CSV before running training.

## Flutter development

From `anemia_app` on Windows:

```powershell
flutter pub get
flutter analyze
flutter test
```

The tests cover app startup and fail-closed behavior when no validated eye
detector is available. Device and integration testing require a configured
Flutter target.

## Model workflow

From `anemia_model`, create an environment using the requirements appropriate
to the task:

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements-training.txt
python scripts\train_screening_model.py --metadata-csv path\to\metadata.csv
```

The metadata CSV must contain `image_path`, `patient_id`, and `hb_g_dl`.
Training derives labels from the supplied hemoglobin threshold and splits by
patient, not by image. See [`anemia_model/README.md`](anemia_model/README.md)
and [`docs/ENGINEERING_BLUEPRINT.md`](docs/ENGINEERING_BLUEPRINT.md) before
using clinical data.

## Publication boundary

This folder is the authoritative source selected from the surrounding
`Innovation` copies. The existing public GitHub repository was updated only
after explicit approval; no new repository was created and no visibility
change was made.
