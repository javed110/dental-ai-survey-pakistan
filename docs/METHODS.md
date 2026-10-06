# Statistical specification

## Measures

The analysis separates familiarity, academic and clinical tool-use responses, confidence in AI diagnostic accuracy, willingness to base a definitive diagnosis on AI output, education willingness, and individual barriers. Familiarity and confidence combine agreement and strong agreement. Tool use is an affirmative response to the combined digital-tools-and-AI question. Diagnostic willingness is an affirmative answer to its yes/no item.

Age is grouped as 20–30 versus 31–60 in models. Five practice categories remain descriptive; academic/private and academic/public are combined as mixed practice for modelling. Academic-only practice is the reference. General dentist is compared with all other recorded specialties or roles. Years of clinical practice replaces age in sensitivity analyses, either linearly or as log(1 + years).

## Descriptive and adjusted analyses

| Analysis | Specification |
|---|---|
| Proportions | Numerator/301, with Wilson 95% intervals |
| Confidence minus willingness | Whole-respondent paired bootstrap, seed 20260925, 5,000 samples |
| Clinical tool-use model | Logistic outcome; predictors age group, gender, practice setting and general-dentist status |
| Willingness model | Logistic outcome; predictors clinical tool use, age group, gender, setting and high familiarity |
| Model uncertainty | Wald intervals and P values; no stepwise selection; analyses developed after data collection |
| Absolute use association | Predict each sample covariate profile at positive and negative tool-use responses, average each set and subtract; seed 20260925, 2,000 bootstrap samples |
| Robustness | Specialty adjustment, omission of concurrent familiarity, reversed outcome, use-by-gender and use-by-setting likelihood-ratio tests, overlap and leave-one-record-out checks |

Participant resampling preserves the joint responses but assumes independent respondents. It does not incorporate site clustering, sampling weights, nonresponse adjustment or correction for convenience selection. P values and intervals are exploratory and unadjusted for multiplicity. No diagnostic accuracy, clinical decision benefit or external prediction validation is estimated.

## Descriptive pathway decompositions

Ordering A places clinical tool use before diagnostic willingness; ordering B reverses those roles. For each ordering, contrasts cover age, gender, general-dentist status and public, private or mixed practice versus academic-only practice. Age, gender and role contrasts include all 301 rows; the setting contrasts use their own two-group samples of 184, 162 and 185 rows.

An intermediate-response logistic model contains the characteristic and other background variables. The final-response logistic model also contains the intermediate response and its interaction with the characteristic. Familiarity is excluded because its timing is unknown. Each contrast adjusts for the remaining age, gender, role and setting terms as applicable.

Let F(x, xm) denote the sample-average fitted final-response probability at characteristic level x, integrated over the fitted intermediate-response distribution at level xm. The overall component is F(1,1) − F(0,0); direct is F(1,0) − F(0,0); indirect is F(1,1) − F(1,0). Components are reported in percentage points and sum algebraically before rounding.

The bootstrap uses seed 20260926 and 1,000 whole-respondent resamples per contrast. A numerical screen flags absolute regression coefficients above 15 or fitted probabilities within 1e−7 of zero or one. This is not a formal separation test. All primary resamples are retained. The diagnostic-only omission analysis measures interval-endpoint sensitivity.

The proposed DAGs include unmeasured prior interest, pre-use access, underlying behavior and selection. Their paths cannot be tested comprehensively from the recorded items. The reported decomposition uses observed self-reported use and willingness, and does not identify natural, interventional or causal mediation effects.

## Separate ensemble pilot

The methodological pilot uses three repetitions of stratified outer five-fold evaluation. Within each training set, inner five-fold out-of-fold predictions fit nonnegative convex ensemble weights. The candidates are an intercept-only predictor, main-effects logistic regression, an interaction logistic specification and a shallow decision tree. No gradient boosting learner was evaluated.

Mean Brier score was 0.2453 for main-effects logistic regression and 0.2483 for the ensemble; corresponding AUCs were 0.5850 and 0.5557. These are descriptive internal scores with no external validation or defined deployment decision. The pilot is excluded from manuscript findings and does not establish superiority or clinical usefulness.

## Methodological references

- Muller CJ, MacLehose RF. Estimating predicted probabilities from logistic regression: different methods correspond to different target populations. [DOI 10.1093/ije/dyu029](https://doi.org/10.1093/ije/dyu029).
- Textor J, van der Zander B, Gilthorpe MS, Liśkiewicz M, Ellison GTH. Robust causal inference using directed acyclic graphs: the R package dagitty. [DOI 10.1093/ije/dyw341](https://doi.org/10.1093/ije/dyw341).
- Imai K, Keele L, Tingley D. A general approach to causal mediation analysis. [DOI 10.1037/a0020761](https://doi.org/10.1037/a0020761). Cited for identification assumptions; this survey does not establish them.
- Maxwell SE, Cole DA. Bias in cross-sectional analyses of longitudinal mediation. [DOI 10.1037/1082-989X.12.1.23](https://doi.org/10.1037/1082-989X.12.1.23).
