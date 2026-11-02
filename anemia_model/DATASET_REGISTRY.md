# Dataset registry and approval status

This registry records evidence and approval status; it does not grant a license.
Download, redistribution, and deployment require review of the publisher's
current terms, ethics/provenance information, and intended-use restrictions.

| Dataset | Source/citation | Published content | License/access status | Project status |
|---|---|---|---|---|
| Eyes-defy-anemia | IEEE DataPort, DOI `10.21227/t5s2-4j73`; Dimauro et al. and linked papers | 218 eye/conjunctiva images, lab Hb, age/sex, manual conjunctiva masks | DataPort access; permissive redistribution license not verified | Candidate for pipeline development; not approved |
| Multimodal conjunctiva/palm/nail-bed | IEEE DataPort, DOI `10.21227/n7km-nr64` | 1,485 participants; 166 anemic, 1,318 non-anemic under published Hb definition; lab Hb 6.0–18.7 g/dL | DataPort access; terms must be accepted and archived | Candidate benchmark; not approved |
| ImageHB | `https://bdtd.github.io/ImageHB/` | 27,259 images, 4,430 paediatric subjects, lab/anthropometric data, selected masks | Landing page license/redistribution terms not verified | Candidate pretraining/subgroup set; not approved |

Before any model is enabled, record:

1. Download URL, version/date, checksum, and terms URL.
2. License approval for training and app redistribution.
3. Ethics/consent/provenance review.
4. Patient-level identifiers and de-identification policy.
5. Device/site/population distribution.
6. Label definition and missingness.
7. Independent reviewer and approval date.
