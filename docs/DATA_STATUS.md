# Data provenance and access status

## Source and transformations

The local analysis input was decoded from the supplied complete coded Jamovi archive. It contains 301 rows and 42 integer fields. The export preserves row order, column order and every recorded value. There is no imputation, source-value replacement or participant exclusion during export.

The archive is a coded analysis source, not an untouched survey-system response export. The original responses, respondent-level recoding history, recruitment-site linkage, date records and exclusion history are still required for source reconciliation. Application metadata showing no removed rows cannot establish that no historical exclusions occurred.

The two use fields use 1 for No and 3 for Yes. Most other binary fields use 1 for Yes and 2 for No. Agreement items use four ordered options. A universal binary recoding rule would be incorrect. The use fields' abbreviated headings do not preserve the full administered wording, which combines digital tools and AI technologies.

## Documented quality issues

| Issue | Treatment |
|---|---|
| Identical complete response pattern in two records | Retain both; evaluate omission of one pattern copy only as a sensitivity analysis |
| Stored barrier aggregate disagrees with seven selected-item counts in five records | Preserve source values and flag locally; use individual barrier indicators in manuscript analyses |
| Stored training-method aggregate disagrees with six selected-item counts in four records | Preserve source values and flag locally; exclude the aggregate from manuscript analyses |
| Age boundaries overlap in the questionnaire | Preserve coded groups and document the missing allocation history |
| Anticipated-integration category boundaries differ between questionnaire and metadata | Preserve coded labels; do not reinterpret individual responses |
| Online-workshop column and online-course label differ | Record both labels in the codebook |
| AI-experience field differs in 52 cells in a later coded file | Retain the complete source-master values; the field is not used in manuscript models |
| Recruitment summary and final sample do not fully reconcile | Do not reconstruct a response rate, site weights or participant flow from the coded rows |

The local codebook contains all variable definitions and explicit analytical recodes. Recomputed item counts are supplied separately for transparency and are not validated scales.

## Sharing

The repository contains code and reviewed aggregate outputs only. It excludes respondent-level CSVs, coded archives, row-level quality flags, derived row tables, fitted-model RDS files, private consent or ethics documents, and the complete local ZIP package.

No direct names or contact fields occur in the coded dataset, but rare combinations of professional attributes can still permit recognition. Participation consent alone does not settle whether unrestricted respondent-level release is permitted. Institutional authorization, a disclosure review and an appropriate public or controlled-access route are still required. No institutional contact or restriction is invented in this repository.
