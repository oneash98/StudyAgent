# CohortMethod cmAnalysis Template v1.4.0

This document describes the executable JSON template stored at
`R/OHDSIAssistant/inst/templates/cmAnalysis_template.json`.

The template is valid JSON and is intended to be read by R code, populated from
the shell's collected analytic settings, and written as the primary CohortMethod
analysis-settings artifact.

This structure is a temporary StudyAgent-specific contract for the Strategus
CohortMethod shell. It is used only to bridge the shell's collected analytic
settings into a reproducible CohortMethod analysis JSON artifact, and should not
be treated as a general OHDSI, Strategus, or CohortMethod public schema.

## Top-Level Shape

- `description`: analytic settings profile name.
- `getDbCohortMethodDataArgs`: settings used when extracting CohortMethod data.
- `createStudyPopArgs`: settings used to define the study population.
- `trimByPsArgs`: propensity-score trimming settings, or `null`.
- `matchOnPsArgs`: propensity-score matching settings, or `null`.
- `stratifyByPsArgs`: propensity-score stratification settings, or `null`.
- `createPsArgs`: propensity-score model settings, or `null`.
- `fitOutcomeModelArgs`: outcome model settings.

## Field Notes

### `getDbCohortMethodDataArgs`

- `studyStartDate`, `studyEndDate`: date strings in `yyyyMMdd` format, or blank
  strings when not restricted.
- `firstExposureOnly`: `true` or `false`.
- `removeDuplicateSubjects`: one of `keep all`, `keep first`, `remove all`,
  or `keep first, truncate to second`.
- `restrictToCommonPeriod`: `true` or `false`.
- `washoutPeriod`: non-negative integer number of days.
- `maxCohortSize`: non-negative integer; `0` means no maximum.

### `createStudyPopArgs`

- `removeSubjectsWithPriorOutcome`: `true` or `false`.
- `priorOutcomeLookback`: non-negative integer lookback window.
- `minDaysAtRisk`: non-negative integer.
- `riskWindowStart`, `riskWindowEnd`: integer offsets from the selected anchor.
- `startAnchor`, `endAnchor`: one of `cohort start` or `cohort end`.
- `censorAtNewRiskWindow`: `true` or `false`.

### `trimByPsArgs`

- Use `null` when no PS trimming is selected.
- For percent trimming, set `trimFraction` and set `equipoiseBounds` to `null`.
- For equipoise trimming, set `equipoiseBounds` and set `trimFraction` to `null`.
- `trimFraction` is a fraction, so 5 percent is represented as `0.05`.

### `matchOnPsArgs`

- Use an object only when matching on propensity score.
- Use `null` when stratifying by PS or when no PS adjustment is selected.
- `maxRatio` is a non-negative integer; `0` means no maximum.
- `caliper` is numeric; `0` means no caliper is used.
- `caliperScale` is one of `propensity score`, `standardized`, or
  `standardized logit`.

### `stratifyByPsArgs`

- Use an object only when stratifying by propensity score.
- Use `null` when matching on PS or when no PS adjustment is selected.
- `numberOfStrata` is a positive integer.
- `baseSelection` is one of `all`, `target`, or `comparator`.

### `createPsArgs`

- Use `null` when no PS model is needed.
- `maxCohortSizeForFitting` is a non-negative integer; `0` means no
  downsampling.
- `errorOnHighCorrelation`: `true` or `false`.
- `prior` and `control` are `null` when regularization is disabled.
- `prior.priorType`: currently `laplace`.
- `prior.useCrossValidation`: `true` or `false`.
- `control.cvType`: `auto` or `grid`.
- `control.noiseLevel`: `silent`, `quiet`, or `noisy`.
- `control.startingVariance`: numeric; `-1` means estimate from data.

### `fitOutcomeModelArgs`

- `modelType`: one of `logistic`, `poisson`, or `cox`.
- `stratified`: `true` or `false`.
- `useCovariates`: `true` or `false`.
- `inversePtWeighting`: `true` or `false`.
- `prior` and `control` are `null` when regularization is disabled.
- `control` follows the same field conventions as `createPsArgs.control`.

## Generation Rules

- Matching and stratification are mutually exclusive:
  - `matchOnPsArgs` object and `stratifyByPsArgs = null`, or
  - `matchOnPsArgs = null` and `stratifyByPsArgs` object, or
  - both `null` when no PS adjustment is selected.
- If trimming is selected without matching or stratification, `createPsArgs`
  should still be present because PS values are required for trimming.
- The generated artifact should be valid JSON with no comments.
