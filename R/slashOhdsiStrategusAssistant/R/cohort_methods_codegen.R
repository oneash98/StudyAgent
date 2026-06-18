.studyAgentCmNullish <- function(value) {
  is.null(value) || length(value) == 0 || all(is.na(value))
}

.studyAgentCmValue <- function(value, default = NULL) {
  if (.studyAgentCmNullish(value)) return(default)
  value
}

.studyAgentCmFirst <- function(values, default = NULL) {
  if (!is.list(values) || length(values) == 0) return(default)
  values[[1]]
}

.studyAgentCmNumeric <- function(value, default = NA_real_) {
  value <- .studyAgentCmValue(value, default)
  suppressWarnings(as.numeric(value))
}

.studyAgentCmInteger <- function(value, default = NA_integer_) {
  value <- .studyAgentCmValue(value, default)
  suppressWarnings(as.integer(value))
}

.studyAgentCmLogical <- function(value, default = FALSE) {
  value <- .studyAgentCmValue(value, default)
  isTRUE(value)
}

.studyAgentCmString <- function(value, default = "") {
  value <- .studyAgentCmValue(value, default)
  as.character(value)
}

.studyAgentExpandCmAnalysisPlans <- function(cmAnalysis) {
  study_periods <- cmAnalysis$getDbCohortMethodDataArgs$studyPeriods
  time_at_risks <- cmAnalysis$createStudyPopArgs$timeAtRisks
  ps_settings <- cmAnalysis$psSettings
  outcome_models <- cmAnalysis$fitOutcomeModelArgs$outcomeModels

  if (!is.list(study_periods) || length(study_periods) == 0) {
    stop("cmAnalysis$getDbCohortMethodDataArgs$studyPeriods must contain at least one entry.")
  }
  if (!is.list(time_at_risks) || length(time_at_risks) == 0) {
    stop("cmAnalysis$createStudyPopArgs$timeAtRisks must contain at least one entry.")
  }
  if (!is.list(ps_settings) || length(ps_settings) == 0) {
    stop("cmAnalysis$psSettings must contain at least one entry.")
  }
  if (!is.list(outcome_models) || length(outcome_models) == 0) {
    stop("cmAnalysis$fitOutcomeModelArgs$outcomeModels must contain at least one entry.")
  }

  plans <- list()
  analysis_id <- 1L
  for (study_period in study_periods) {
    for (time_at_risk in time_at_risks) {
      for (ps_setting in ps_settings) {
        for (outcome_model in outcome_models) {
          plans[[length(plans) + 1L]] <- list(
            analysisId = analysis_id,
            description = sprintf(
              "Study: %s; TAR: %s; PS: %s; Model: %s",
              .studyAgentCmString(study_period$description, ""),
              .studyAgentCmString(time_at_risk$description, ""),
              .studyAgentCmString(ps_setting$description, ""),
              .studyAgentCmString(outcome_model$description, "")
            ),
            studyPeriod = study_period,
            timeAtRisk = time_at_risk,
            psSetting = ps_setting,
            outcomeModel = outcome_model
          )
          analysis_id <- analysis_id + 1L
        }
      }
    }
  }
  plans
}

.studyAgentCmPsNeedsModel <- function(psSetting) {
  is.list(psSetting$matchOnPsArgs) ||
    is.list(psSetting$stratifyByPsArgs) ||
    is.list(psSetting$trimByPsArgs) ||
    isTRUE(psSetting$inversePtWeighting)
}

.studyAgentCmShouldFitOutcomeModelBeStratified <- function(psSetting) {
  match_args <- psSetting$matchOnPsArgs
  max_ratio <- if (is.list(match_args)) .studyAgentCmInteger(match_args$maxRatio, 1L) else 1L
  is.list(psSetting$stratifyByPsArgs) || (is.list(match_args) && max_ratio > 1L)
}

.studyAgentEmitRString <- function(value) {
  value <- .studyAgentCmString(value, "")
  value <- gsub("\\\\", "\\\\\\\\", value)
  value <- gsub("\"", "\\\\\"", value)
  sprintf("\"%s\"", value)
}

.studyAgentEmitRNumber <- function(value) {
  value <- .studyAgentCmNumeric(value)
  if (length(value) == 0 || is.na(value)) return("NA")
  as.character(value)
}

.studyAgentEmitRInteger <- function(value) {
  value <- .studyAgentCmInteger(value)
  if (length(value) == 0 || is.na(value)) return("NA")
  as.character(value)
}

.studyAgentEmitRBool <- function(value) {
  if (isTRUE(value)) "TRUE" else "FALSE"
}

.studyAgentEmitRNumberVector <- function(values) {
  values <- as.numeric(values)
  sprintf("c(%s)", paste(as.character(values), collapse = ", "))
}

.studyAgentIndentLines <- function(text, spaces) {
  pad <- paste(rep(" ", spaces), collapse = "")
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  paste(ifelse(nzchar(lines), paste0(pad, lines), lines), collapse = "\n")
}

.studyAgentEmitCmPrior <- function(prior, includeExclude = FALSE) {
  if (!is.list(prior)) return("NULL")
  exclude <- if (isTRUE(includeExclude)) "\n    exclude = c(0)," else ""
  sprintf(
    "Cyclops::createPrior(\n    priorType = %s,%s\n    useCrossValidation = %s\n  )",
    .studyAgentEmitRString(prior$priorType),
    exclude,
    .studyAgentEmitRBool(prior$useCrossValidation)
  )
}

.studyAgentEmitCmControl <- function(control) {
  if (!is.list(control)) return("NULL")
  sprintf(
    paste(
      "Cyclops::createControl(",
      "    tolerance = %s,",
      "    cvType = %s,",
      "    fold = %s,",
      "    cvRepetitions = %s,",
      "    noiseLevel = %s,",
      "    resetCoefficients = %s,",
      "    startingVariance = %s,",
      "    seed = 1",
      "  )",
      sep = "\n"
    ),
    .studyAgentEmitRNumber(control$tolerance),
    .studyAgentEmitRString(control$cvType),
    .studyAgentEmitRInteger(control$fold),
    .studyAgentEmitRInteger(control$cvRepetitions),
    .studyAgentEmitRString(control$noiseLevel),
    .studyAgentEmitRBool(control$resetCoefficients),
    .studyAgentEmitRNumber(control$startingVariance)
  )
}

.studyAgentEmitCmTrimByPsArgs <- function(psSetting) {
  trim_args <- psSetting$trimByPsArgs
  if (!is.list(trim_args)) return("NULL")
  if (!.studyAgentCmNullish(trim_args$trimFraction)) {
    return(sprintf(
      "CohortMethod::createTrimByPsArgs(trimFraction = %s)",
      .studyAgentEmitRNumber(trim_args$trimFraction)
    ))
  }
  if (!.studyAgentCmNullish(trim_args$equipoiseBounds)) {
    return(sprintf(
      "CohortMethod::createTrimByPsArgs(equipoiseBounds = %s)",
      .studyAgentEmitRNumberVector(trim_args$equipoiseBounds)
    ))
  }
  "NULL"
}

.studyAgentEmitCmMatchOnPsArgs <- function(psSetting) {
  match_args <- psSetting$matchOnPsArgs
  stratify_args <- psSetting$stratifyByPsArgs
  if (is.list(match_args) && is.list(stratify_args)) {
    stop("Invalid PS setting: both matchOnPsArgs and stratifyByPsArgs are set.")
  }
  if (!is.list(match_args)) return("NULL")
  sprintf(
    paste(
      "CohortMethod::createMatchOnPsArgs(",
      "    maxRatio = %s,",
      "    caliper = %s,",
      "    caliperScale = %s,",
      "    allowReverseMatch = FALSE",
      "  )",
      sep = "\n"
    ),
    .studyAgentEmitRInteger(match_args$maxRatio),
    .studyAgentEmitRNumber(match_args$caliper),
    .studyAgentEmitRString(match_args$caliperScale)
  )
}

.studyAgentEmitCmStratifyByPsArgs <- function(psSetting) {
  stratify_args <- psSetting$stratifyByPsArgs
  if (!is.list(stratify_args)) return("NULL")
  sprintf(
    paste(
      "CohortMethod::createStratifyByPsArgs(",
      "    numberOfStrata = %s,",
      "    stratificationColumns = c(),",
      "    baseSelection = %s",
      "  )",
      sep = "\n"
    ),
    .studyAgentEmitRInteger(stratify_args$numberOfStrata),
    .studyAgentEmitRString(stratify_args$baseSelection)
  )
}

.studyAgentEmitCmCreatePsArgs <- function(psSetting, cmAnalysis) {
  if (!.studyAgentCmPsNeedsModel(psSetting)) return("NULL")
  create_ps_args <- cmAnalysis$createPsArgs
  sprintf(
    paste(
      "CohortMethod::createCreatePsArgs(",
      "    maxCohortSizeForFitting = %s,",
      "    errorOnHighCorrelation = %s,",
      "    stopOnError = FALSE,",
      "    estimator = \"att\",",
      "    prior =",
      "%s,",
      "    control =",
      "%s",
      "  )",
      sep = "\n"
    ),
    .studyAgentEmitRInteger(create_ps_args$maxCohortSizeForFitting),
    .studyAgentEmitRBool(create_ps_args$errorOnHighCorrelation),
    .studyAgentIndentLines(.studyAgentEmitCmPrior(create_ps_args$prior, includeExclude = TRUE), 4),
    .studyAgentIndentLines(.studyAgentEmitCmControl(create_ps_args$control), 4)
  )
}

.studyAgentEmitCmGetDbArgs <- function(plan, cmAnalysis) {
  get_db_args <- cmAnalysis$getDbCohortMethodDataArgs
  study_period <- plan$studyPeriod
  sprintf(
    paste(
      "CohortMethod::createGetDbCohortMethodDataArgs(",
      "    restrictToCommonPeriod = %s,",
      "    firstExposureOnly = %s,",
      "    washoutPeriod = %s,",
      "    removeDuplicateSubjects = %s,",
      "    studyStartDate = %s,",
      "    studyEndDate = %s,",
      "    maxCohortSize = %s,",
      "    covariateSettings = covariateSettings",
      "  )",
      sep = "\n"
    ),
    .studyAgentEmitRBool(get_db_args$restrictToCommonPeriod),
    .studyAgentEmitRBool(get_db_args$firstExposureOnly),
    .studyAgentEmitRInteger(get_db_args$washoutPeriod),
    .studyAgentEmitRString(get_db_args$removeDuplicateSubjects),
    .studyAgentEmitRString(study_period$studyStartDate),
    .studyAgentEmitRString(study_period$studyEndDate),
    .studyAgentEmitRInteger(get_db_args$maxCohortSize)
  )
}

.studyAgentEmitCmStudyPopArgs <- function(plan, cmAnalysis) {
  study_pop_args <- cmAnalysis$createStudyPopArgs
  time_at_risk <- plan$timeAtRisk
  sprintf(
    paste(
      "CohortMethod::createCreateStudyPopulationArgs(",
      "    censorAtNewRiskWindow = %s,",
      "    removeSubjectsWithPriorOutcome = %s,",
      "    priorOutcomeLookback = %s,",
      "    riskWindowStart = %s,",
      "    startAnchor = %s,",
      "    riskWindowEnd = %s,",
      "    endAnchor = %s,",
      "    minDaysAtRisk = %s,",
      "    maxDaysAtRisk = 99999",
      "  )",
      sep = "\n"
    ),
    .studyAgentEmitRBool(study_pop_args$censorAtNewRiskWindow),
    .studyAgentEmitRBool(study_pop_args$removeSubjectsWithPriorOutcome),
    .studyAgentEmitRInteger(study_pop_args$priorOutcomeLookback),
    .studyAgentEmitRInteger(time_at_risk$riskWindowStart),
    .studyAgentEmitRString(time_at_risk$startAnchor),
    .studyAgentEmitRInteger(time_at_risk$riskWindowEnd),
    .studyAgentEmitRString(time_at_risk$endAnchor),
    .studyAgentEmitRInteger(time_at_risk$minDaysAtRisk)
  )
}

.studyAgentEmitCmFitOutcomeModelArgs <- function(plan, cmAnalysis) {
  ps_setting <- plan$psSetting
  outcome_model <- plan$outcomeModel
  fit_args <- cmAnalysis$fitOutcomeModelArgs
  sprintf(
    paste(
      "CohortMethod::createFitOutcomeModelArgs(",
      "    modelType = %s,",
      "    stratified = %s,",
      "    useCovariates = %s,",
      "    inversePtWeighting = %s,",
      "    prior =",
      "%s,",
      "    control =",
      "%s",
      "  )",
      sep = "\n"
    ),
    .studyAgentEmitRString(outcome_model$modelType),
    .studyAgentEmitRBool(.studyAgentCmShouldFitOutcomeModelBeStratified(ps_setting)),
    .studyAgentEmitRBool(outcome_model$useCovariates),
    .studyAgentEmitRBool(ps_setting$inversePtWeighting),
    .studyAgentIndentLines(.studyAgentEmitCmPrior(fit_args$prior, includeExclude = FALSE), 4),
    .studyAgentIndentLines(.studyAgentEmitCmControl(fit_args$control), 4)
  )
}

.studyAgentEmitCmAnalysis <- function(plan, cmAnalysis) {
  sprintf(
    paste(
      "CohortMethod::createCmAnalysis(",
      "  analysisId = %s,",
      "  description = %s,",
      "  getDbCohortMethodDataArgs =",
      "%s,",
      "  createStudyPopulationArgs =",
      "%s,",
      "  createPsArgs =",
      "%s,",
      "  trimByPsArgs =",
      "%s,",
      "  matchOnPsArgs =",
      "%s,",
      "  stratifyByPsArgs =",
      "%s,",
      "  computeSharedCovariateBalanceArgs = computeSharedCovariateBalanceArgs,",
      "  computeCovariateBalanceArgs = computeCovariateBalanceArgs,",
      "  fitOutcomeModelArgs =",
      "%s",
      ")",
      sep = "\n"
    ),
    .studyAgentEmitRInteger(plan$analysisId),
    .studyAgentEmitRString(plan$description),
    .studyAgentIndentLines(.studyAgentEmitCmGetDbArgs(plan, cmAnalysis), 2),
    .studyAgentIndentLines(.studyAgentEmitCmStudyPopArgs(plan, cmAnalysis), 2),
    .studyAgentIndentLines(.studyAgentEmitCmCreatePsArgs(plan$psSetting, cmAnalysis), 2),
    .studyAgentIndentLines(.studyAgentEmitCmTrimByPsArgs(plan$psSetting), 2),
    .studyAgentIndentLines(.studyAgentEmitCmMatchOnPsArgs(plan$psSetting), 2),
    .studyAgentIndentLines(.studyAgentEmitCmStratifyByPsArgs(plan$psSetting), 2),
    .studyAgentIndentLines(.studyAgentEmitCmFitOutcomeModelArgs(plan, cmAnalysis), 2)
  )
}

.studyAgentEmitCmAnalysisListBlocks <- function(cmAnalysis) {
  plans <- .studyAgentExpandCmAnalysisPlans(cmAnalysis)
  blocks <- c("cmAnalysisList <- list()")
  for (plan in plans) {
    blocks <- c(
      blocks,
      "",
      sprintf(
        "cmAnalysisList[[%s]] <- %s",
        .studyAgentEmitRInteger(plan$analysisId),
        .studyAgentEmitCmAnalysis(plan, cmAnalysis)
      )
    )
  }
  blocks
}

.studyAgentBuildCohortMethodsSpecScript <- function(base_dir,
                                                    script_header,
                                                    package_loader_lines,
                                                    cmAnalysis) {
  c(
    script_header,
    "library(Strategus)",
    "library(CohortGenerator)",
    "library(CohortIncidence)",
    "library(jsonlite)",
    "library(ParallelLogger)",
    "",
    package_loader_lines,
    "",
    sprintf("base_dir <- '%s'", base_dir),
    "output_dir <- file.path(base_dir, 'outputs')",
    "analysis_settings_dir <- file.path(base_dir, 'analysis-settings')",
    "selected_dir <- file.path(base_dir, 'selected-cohorts')",
    "patched_dir <- file.path(base_dir, 'patched-cohorts')",
    "cm_results_dir <- file.path(base_dir, 'cm-results')",
    "dir.create(analysis_settings_dir, recursive = TRUE, showWarnings = FALSE)",
    "dir.create(cm_results_dir, recursive = TRUE, showWarnings = FALSE)",
    "",
    "`%||%` <- function(x, y) if (is.null(x)) y else x",
    "defaults <- jsonlite::fromJSON(file.path(output_dir, 'cm_analysis_defaults.json'), simplifyVector = TRUE)",
    "cmAnalysis <- jsonlite::fromJSON(file.path(analysis_settings_dir, 'cmAnalysis.json'), simplifyVector = FALSE)",
    "conceptSetSelections <- jsonlite::fromJSON(file.path(output_dir, 'cm_concept_set_selections.json'), simplifyVector = FALSE)",
    "cohort_csv <- file.path(selected_dir, 'Cohorts.csv')",
    "cohort_json_dir <- if (length(list.files(patched_dir, pattern = '\\\\.(json)$')) > 0) patched_dir else selected_dir",
    "sql_dir <- file.path(cohort_json_dir, 'sql')",
    "dir.create(sql_dir, recursive = TRUE, showWarnings = FALSE)",
    "getDbDefaults <- cmAnalysis$getDbCohortMethodDataArgs",
    "studyPopulationDefaults <- cmAnalysis$createStudyPopArgs",
    "primaryStudyPeriod <- getDbDefaults$studyPeriods[[1]]",
    "primaryTimeAtRisk <- studyPopulationDefaults$timeAtRisks[[1]]",
    "covariateConceptDefaults <- defaults$covariate_concept_sets %||% list()",
    "comparison_payload <- jsonlite::fromJSON(file.path(output_dir, 'cm_comparisons.json'), simplifyVector = FALSE)",
    "comparisons <- comparison_payload$comparisons %||% list()",
    "if (length(comparisons) == 0) stop('No comparisons found in cm_comparisons.json')",
    "comparison <- comparisons[[1]]",
    "",
    "cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(",
    "  settingsFileName = cohort_csv,",
    "  jsonFolder = cohort_json_dir,",
    "  sqlFolder = sql_dir",
    ")",
    "lookup_cohort_name <- function(cohort_id, fallback = NULL) {",
    "  row <- cohortDefinitionSet[as.integer(cohortDefinitionSet$cohortId) == as.integer(cohort_id), , drop = FALSE]",
    "  if (nrow(row) > 0 && 'cohortName' %in% names(row) && nzchar(as.character(row$cohortName[1]))) {",
    "    return(as.character(row$cohortName[1]))",
    "  }",
    "  fallback %||% sprintf('Cohort %s', cohort_id)",
    "}",
    "to_ci_anchor <- function(anchor) {",
    "  anchor <- tolower(trimws(as.character(anchor %||% 'cohort start')))",
    "  if (identical(anchor, 'cohort end')) 'end' else 'start'",
    "}",
    "",
    "target_id <- as.numeric(comparison$target$cohort_id %||% NA_real_)",
    "comparator_id <- as.numeric(comparison$comparator$cohort_id %||% NA_real_)",
    "outcome_ids <- vapply(comparison$outcomes %||% list(), function(x) as.numeric(x$cohort_id %||% NA_real_), numeric(1))",
    "if (is.na(target_id)) stop('Missing target cohort ID in cm_comparisons.json')",
    "if (is.na(comparator_id)) stop('Missing comparator cohort ID in cm_comparisons.json')",
    "if (length(outcome_ids) == 0) stop('Missing outcome cohort IDs in cm_comparisons.json')",
    "target_name <- lookup_cohort_name(target_id, comparison$target$name %||% 'Target')",
    "comparator_name <- lookup_cohort_name(comparator_id, comparison$comparator$name %||% 'Comparator')",
    "outcome_names <- vapply(comparison$outcomes %||% list(), function(x) {",
    "  oid <- as.numeric(x$cohort_id %||% NA_real_)",
    "  lookup_cohort_name(oid, x$name %||% sprintf('Outcome %s', oid))",
    "}, character(1))",
    "",
    "negativeControlConceptSet <- conceptSetSelections$negative_control %||% list()",
    "covariateConceptSelections <- conceptSetSelections$covariates %||% list()",
    "includedConceptSetId <- as.integer(covariateConceptDefaults$include_concept_set_id %||% covariateConceptSelections$include$concept_set_id %||% NA_integer_)",
    "excludedConceptSetId <- as.integer(covariateConceptDefaults$exclude_concept_set_id %||% covariateConceptSelections$exclude$concept_set_id %||% NA_integer_)",
    "includedCovariateConceptIds <- numeric(0)",
    "excludedCovariateConceptIds <- numeric(0)",
    "if (!is.na(includedConceptSetId)) message('TODO: Replace dummy covariate include concept set ', includedConceptSetId, ' with actual concept IDs before production use.')",
    "if (!is.na(excludedConceptSetId)) message('TODO: Replace dummy covariate exclude concept set ', excludedConceptSetId, ' with actual concept IDs before production use.')",
    "if (isTRUE(negativeControlConceptSet$enabled %||% FALSE)) message('TODO: Negative control concept set selected as dummy placeholder: ', negativeControlConceptSet$concept_set_id %||% NA_integer_)",
    "",
    "# Shared cohort definitions are included so downstream modules can resolve cohort metadata.",
    "# Cohort generation itself is intentionally not included here; run 03_generate_cohorts.R first.",
    "cgModule <- CohortGeneratorModule$new()",
    "cohortDefinitionSharedResource <- cgModule$createCohortSharedResourceSpecifications(",
    "  cohortDefinitionSet = cohortDefinitionSet",
    ")",
    "",
    "# Characterization module: one characterization configuration for target and comparator cohorts.",
    "characterizationTargetIds <- as.numeric(unique(c(target_id, comparator_id)))",
    "characterizationModule <- CharacterizationModule$new()",
    "characterizationModuleSpecifications <- characterizationModule$createModuleSpecifications(",
    "  targetIds = characterizationTargetIds,",
    "  outcomeIds = as.numeric(outcome_ids),",
    "  limitToFirstInNDays = as.numeric(rep(if (isTRUE(getDbDefaults$firstExposureOnly %||% TRUE)) 99999 else 0, length(characterizationTargetIds))),",
    "  minPriorObservation = as.numeric(getDbDefaults$washoutPeriod %||% 0),",
    "  outcomeWashoutDays = as.numeric(rep(as.numeric(studyPopulationDefaults$priorOutcomeLookback %||% 99999), length(outcome_ids))),",
    "  riskWindowStart = as.numeric(primaryTimeAtRisk$riskWindowStart %||% 0),",
    "  startAnchor = primaryTimeAtRisk$startAnchor %||% 'cohort start',",
    "  riskWindowEnd = as.numeric(primaryTimeAtRisk$riskWindowEnd %||% 0),",
    "  endAnchor = primaryTimeAtRisk$endAnchor %||% 'cohort end',",
    "  mode = 'CohortIncidence'",
    ")",
    "",
    "# CohortIncidence module: one incidence analysis across target/comparator cohorts and outcomes.",
    "ciTargets <- list(",
    "  CohortIncidence::createCohortRef(id = target_id, name = target_name),",
    "  CohortIncidence::createCohortRef(id = comparator_id, name = comparator_name)",
    ")",
    "ciOutcomes <- lapply(seq_along(outcome_ids), function(i) {",
    "  CohortIncidence::createOutcomeDef(",
    "    id = as.numeric(outcome_ids[[i]]),",
    "    name = outcome_names[[i]],",
    "    cohortId = as.numeric(outcome_ids[[i]]),",
    "    cleanWindow = as.numeric(studyPopulationDefaults$priorOutcomeLookback %||% 99999)",
    "  )",
    "})",
    "ciTar <- CohortIncidence::createTimeAtRiskDef(",
    "  id = 1,",
    "  startWith = to_ci_anchor(primaryTimeAtRisk$startAnchor %||% 'cohort start'),",
    "  startOffset = as.numeric(primaryTimeAtRisk$riskWindowStart %||% 0),",
    "  endWith = to_ci_anchor(primaryTimeAtRisk$endAnchor %||% 'cohort end'),",
    "  endOffset = as.numeric(primaryTimeAtRisk$riskWindowEnd %||% 0)",
    ")",
    "ciAnalysis <- CohortIncidence::createIncidenceAnalysis(",
    "  targets = c(target_id, comparator_id),",
    "  outcomes = outcome_ids,",
    "  tars = c(1)",
    ")",
    "ciDesign <- CohortIncidence::createIncidenceDesign(",
    "  targetDefs = ciTargets,",
    "  outcomeDefs = ciOutcomes,",
    "  tars = list(ciTar),",
    "  analysisList = list(ciAnalysis),",
    "  strataSettings = CohortIncidence::createStrataSettings(byYear = TRUE, byGender = TRUE)",
    ")",
    "ciModule <- CohortIncidenceModule$new()",
    "cohortIncidenceModuleSpecifications <- ciModule$createModuleSpecifications(",
    "  irDesign = ciDesign$toList()",
    ")",
    "",
    "# CohortMethod module: expand cmAnalysis.json into a cmAnalysisList.",
    "outcomes <- lapply(outcome_ids, function(outcome_id) {",
    "  CohortMethod::createOutcome(",
    "    outcomeId = outcome_id,",
    "    outcomeOfInterest = TRUE,",
    "    trueEffectSize = NA,",
    "    priorOutcomeLookback = studyPopulationDefaults$priorOutcomeLookback %||% 99999",
    "  )",
    "})",
    "",
    "targetComparatorOutcomesList <- list(",
    "  CohortMethod::createTargetComparatorOutcomes(",
    "    targetId = target_id,",
    "    comparatorId = comparator_id,",
    "    outcomes = outcomes,",
    "    excludedCovariateConceptIds = excludedCovariateConceptIds,",
    "    includedCovariateConceptIds = includedCovariateConceptIds",
    "  )",
    ")",
    "",
    "covariateSettings <- FeatureExtraction::createDefaultCovariateSettings(addDescendantsToExclude = TRUE)",
    "computeSharedCovariateBalanceArgs <- CohortMethod::createComputeCovariateBalanceArgs(",
    "  maxCohortSize = 250000,",
    "  covariateFilter = NULL",
    ")",
    "computeCovariateBalanceArgs <- CohortMethod::createComputeCovariateBalanceArgs(",
    "  maxCohortSize = 250000,",
    "  covariateFilter = FeatureExtraction::getDefaultTable1Specifications()",
    ")",
    .studyAgentEmitCmAnalysisListBlocks(cmAnalysis),
    "cmDiagnosticThresholds <- CohortMethod::createCmDiagnosticThresholds()",
    "cmModule <- CohortMethodModule$new()",
    "cmAnalysesSpecifications <- CohortMethod::createCmAnalysesSpecifications(",
    "  cmAnalysisList = cmAnalysisList,",
    "  targetComparatorOutcomesList = targetComparatorOutcomesList,",
    "  analysesToExclude = NULL,",
    "  refitPsForEveryOutcome = FALSE,",
    "  refitPsForEveryStudyPopulation = TRUE,",
    "  cmDiagnosticThresholds = cmDiagnosticThresholds",
    ")",
    "cohortMethodModuleSpecifications <- cmModule$createModuleSpecifications(",
    "  cmAnalysesSpecifications = cmAnalysesSpecifications$toList()",
    ")",
    "",
    "analysisSpecifications <- Strategus::createEmptyAnalysisSpecifications()",
    "analysisSpecifications <- Strategus::addSharedResources(analysisSpecifications, cohortDefinitionSharedResource)",
    "analysisSpecifications <- Strategus::addModuleSpecifications(analysisSpecifications, characterizationModuleSpecifications)",
    "analysisSpecifications <- Strategus::addModuleSpecifications(analysisSpecifications, cohortIncidenceModuleSpecifications)",
    "analysisSpecifications <- Strategus::addModuleSpecifications(analysisSpecifications, cohortMethodModuleSpecifications)",
    "analysis_spec_path <- file.path(analysis_settings_dir, 'analysisSpecification.json')",
    "ParallelLogger::saveSettingsToJson(analysisSpecifications, analysis_spec_path)",
    "",
    "jsonlite::write_json(",
    "  list(",
    "    comparison_label = comparison$label %||% '',",
    "    target_id = target_id,",
    "    comparator_id = comparator_id,",
    "    outcome_ids = as.list(outcome_ids),",
    "    cm_analysis_count = length(cmAnalysisList),",
    "    analysis_specification_path = analysis_spec_path,",
    "    modules = c('CharacterizationModule', 'CohortIncidenceModule', 'CohortMethodModule'),",
    "    defaults_path = file.path(output_dir, 'cm_analysis_defaults.json'),",
    "    cm_analysis_json_path = file.path(analysis_settings_dir, 'cmAnalysis.json'),",
    "    concept_set_selections_path = file.path(output_dir, 'cm_concept_set_selections.json'),",
    "    negative_control_concept_set_id = negativeControlConceptSet$concept_set_id %||% NULL,",
    "    study_start_date = primaryStudyPeriod$studyStartDate %||% '',",
    "    study_end_date = primaryStudyPeriod$studyEndDate %||% '',",
    "    covariate_include_all_concepts = covariateConceptDefaults$include_all_concepts %||% covariateConceptSelections$include_all_concepts %||% TRUE,",
    "    covariate_include_concept_set_id = if (is.na(includedConceptSetId)) NULL else includedConceptSetId,",
    "    covariate_exclude_concept_set_id = if (is.na(excludedConceptSetId)) NULL else excludedConceptSetId,",
    "    analytic_settings_profile_name = defaults$profile_name %||% NULL,",
    "    analytic_settings_customized_sections = defaults$customized_sections %||% character(0),",
    "    TODO = 'Replace dummy concept set selections with actual concept definitions and concept IDs when ACP/MCP support is implemented.'",
    "  ),",
    "  file.path(output_dir, 'cm_analysis_state.json'),",
    "  pretty = TRUE,",
    "  auto_unbox = TRUE",
    ")",
    "",
    "# Execute the just-created Strategus specification.",
    "db_details_path <- file.path(base_dir, 'strategus-db-details.json')",
    "execution_settings_path <- file.path(base_dir, 'strategus-execution-settings.json')",
    "connectionDetails <- slashOhdsiStrategusAssistant::createStrategusConnectionDetails(path = db_details_path)",
    "exec <- slashOhdsiStrategusAssistant::createStrategusExecutionSettings(path = execution_settings_path)",
    "",
    "result <- Strategus::execute(",
    "  connectionDetails = connectionDetails,",
    "  executionSettings = exec$executionSettings,",
    "  analysisSpecifications = analysisSpecifications,",
    "  executionScriptFolder = cm_results_dir",
    ")",
    "result_path <- file.path(analysis_settings_dir, 'strategus_execute_result.rds')",
    "saveRDS(result, result_path)",
    "message('Strategus execution result saved to: ', result_path)",
    ""
  )
}
