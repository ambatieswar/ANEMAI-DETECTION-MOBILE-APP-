# HemoScan Edge release readiness

The application must remain in **blocked prototype** status until every
release gate below has evidence attached to the release record.

## Data and clinical evidence

- [ ] Dataset terms allow the intended training and redistribution.
- [ ] Dataset source, citation, version, checksum, and license are archived.
- [ ] Consent/provenance and de-identification review is complete.
- [ ] Labels are tied to laboratory Hb and the population threshold is approved.
- [ ] Patient-level split is enforced; no subject appears across splits.
- [ ] External site/device test set is held out from model development.
- [ ] Subgroup performance and missingness are reported.
- [ ] Prospective clinical protocol and qualified reviewer are identified.

## Model evidence

- [ ] Real eye/lower-eyelid detector is trained from labeled positives and
      real negative/unsuitable images.
- [ ] Image quality gates are evaluated on a locked test set.
- [ ] Anemia model is trained from clinically sourced labels.
- [ ] Accuracy, precision, sensitivity/recall, specificity, F1, ROC-AUC,
      confusion matrix, confidence intervals, and calibration are reported.
- [ ] OOD/rejection evaluation is reported and conservative thresholds selected.
- [ ] Genuine Grad-CAM maps are generated from the same model package and
      reviewed for anatomical relevance.
- [ ] TFLite conversion parity is checked against the reference model.
- [ ] Model files, manifests, tensor contracts, and SHA-256 hashes are reviewed.

## App and privacy evidence

- [ ] App works without network access and requests no unnecessary permission.
- [ ] Temporary images are deleted after processing.
- [ ] History is encrypted at rest and exports use non-identifying patient IDs.
- [ ] No analytics, cloud upload, or silent sync is present.
- [ ] PDF reports contain the screening disclaimer and no diagnostic language.
- [ ] Unit, widget, integration, and device regression tests pass.
- [ ] Accessibility review is complete.
- [ ] Clinical, ethical, security, and regulatory reviews are signed off.

Until this checklist is complete, the manifest must keep `enabled: false` and
the UI must not display a risk score from the shipped model.
