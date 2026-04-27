#' Interactive shell to generate Strategus CohortMethod scripts
#' @param outputDir directory where scripts and artifacts will be written
#' @param acpUrl ACP base URL for placeholder cohort-method recommendation calls
#' @param studyIntent study intent text
#' @param targetStatement fixed target cohort statement used for phenotype recommendation during development
#' @param comparatorStatement fixed comparator cohort statement used for phenotype recommendation during development
#' @param outcomeStatement fixed outcome cohort statement used for phenotype recommendation during development
#' @param targetCohortId target cohort definition ID
#' @param comparatorCohortId comparator cohort definition ID
#' @param outcomeCohortIds outcome cohort definition IDs
#' @param comparisonLabel optional label for the target-comparator comparison
#' @param topK number of candidates retrieved from MCP search
#' @param maxResults max phenotypes to show
#' @param candidateLimit max candidates to pass to LLM
#' @param indexDir phenotype index directory (contains definitions/ and catalog.jsonl)
#' @param negativeControlConceptSetId optional negative control concept set ID
#' @param includeCovariateConceptSetId optional covariate include concept set ID
#' @param excludeCovariateConceptSetId optional covariate exclude concept set ID
#' @param analyticSettingsDescription optional free-text analytic settings description
#' @param analyticSettingsDescriptionPath optional path to a text file containing the free-text analytic settings description
#' @param incidenceOutputDir optional Strategus CohortIncidence output directory used for cached target/outcome cohort reuse
#' @param interactive whether to prompt for missing inputs
#' @param bannerPath optional path to ASCII banner
#' @param studyAgentBaseDir base directory to resolve relative paths
#' @param reset when TRUE, delete outputDir before running
#' @param allowCache reuse cached manual inputs when present
#' @param promptOnCache prompt before using cached manual inputs
#' @param resume when TRUE, prefer cached manual inputs when present
#' @param remapCohortIds when TRUE, assign new local cohort IDs
#' @param cohortIdBase optional starting cohort ID when remapping
#' @return invisible list with output paths
#' @export
.studyAgentAnalyticSettingsSectionPaths <- function() {
  list(
    study_population = c(
      "get_db_cohort_method_data.studyStartDate",
      "get_db_cohort_method_data.studyEndDate",
      "get_db_cohort_method_data.restrictToCommonPeriod",
      "get_db_cohort_method_data.firstExposureOnly",
      "get_db_cohort_method_data.washoutPeriod",
      "create_study_population.removeDuplicateSubjects",
      "create_study_population.censorAtNewRiskWindow",
      "create_study_population.removeSubjectsWithPriorOutcome",
      "create_study_population.priorOutcomeLookback"
      ,
      "create_study_population.maxCohortSize"
    ),
    time_at_risk = c(
      "create_study_population.minDaysAtRisk",
      "create_study_population.riskWindowStart",
      "create_study_population.startAnchor",
      "create_study_population.riskWindowEnd",
      "create_study_population.endAnchor"
    ),
    propensity_score_adjustment = c(
      "ps_adjustment.strategy",
      "ps_adjustment.trimmingStrategy",
      "ps_adjustment.trimmingPercent",
      "ps_adjustment.equipoiseLowerBound",
      "ps_adjustment.equipoiseUpperBound",
      "create_ps.maxCohortSizeForFitting",
      "create_ps.errorOnHighCorrelation",
      "create_ps.useRegularization",
      "match_on_ps.caliper",
      "match_on_ps.caliperScale",
      "match_on_ps.maxRatio",
      "stratify_by_ps.numberOfStrata",
      "stratify_by_ps.baseSelection"
    ),
    outcome_model = c(
      "fit_outcome_model.modelType",
      "fit_outcome_model.stratified",
      "fit_outcome_model.useCovariates",
      "fit_outcome_model.inversePtWeighting",
      "fit_outcome_model.useRegularization"
    )
  )
}

.studyAgentAnalyticSettingsSectionTitles <- function() {
  c(
    study_population = "Study Population",
    time_at_risk = "Time At Risk",
    propensity_score_adjustment = "Propensity Score Adjustment",
    outcome_model = "Outcome Model"
  )
}

.studyAgentAnalyticSettingDocs <- function() {
  list(
    "get_db_cohort_method_data.studyStartDate" = list(
      label = "Study start date",
      summary_label = "Study start date"
    ),
    "get_db_cohort_method_data.studyEndDate" = list(
      label = "Study end date",
      summary_label = "Study end date"
    ),
    "get_db_cohort_method_data.firstExposureOnly" = list(
      label = "First exposure only",
      summary_label = "First exposure only",
      description = "Should only the first exposure per subject be included?"
    ),
    "get_db_cohort_method_data.washoutPeriod" = list(
      label = "Washout period",
      summary_label = "Washout period",
      description = "The minimum required continuous observation time (in days) prior to index date for a person to be included in the cohort."
    ),
    "get_db_cohort_method_data.restrictToCommonPeriod" = list(
      label = "Restrict to common period",
      summary_label = "Restrict to common period",
      description = "Restrict the study to the period when both exposures are present in the data? (E.g. when both drugs are on the market)"
    ),
    "get_db_cohort_method_data.removeDuplicateSubjects" = list(
      label = "Duplicate subjects during extraction",
      summary_label = "Duplicate subjects during extraction",
      description = "Controls how people who appear in both target and comparator cohorts are handled while extracting data."
    ),
    "create_study_population.removeDuplicateSubjects" = list(
      label = "Remove duplicate subjects",
      summary_label = "Remove duplicate subjects",
      description = "Remove subjects that are in both the target and comparator cohort?"
    ),
    "create_study_population.maxCohortSize" = list(
      label = "Maximum cohort size",
      summary_label = "Maximum cohort size",
      description = "If either the target or the comparator cohort is larger than this number it will be sampled to this size. (0 for this value indicates no maximum size)"
    ),
    "create_study_population.removeSubjectsWithPriorOutcome" = list(
      label = "Remove prior outcomes",
      summary_label = "Remove prior outcomes",
      description = "Remove subjects that have the outcome prior to the risk window start?"
    ),
    "create_study_population.priorOutcomeLookback" = list(
      label = "Prior outcome lookback",
      summary_label = "Prior outcome lookback",
      description = "How many days should we look back when identifying prior outcomes?"
    ),
    "create_study_population.riskWindowStart" = list(
      label = "Risk window start",
      summary_label = "Risk window start"
    ),
    "create_study_population.minDaysAtRisk" = list(
      label = "Minimum days at risk",
      summary_label = "Minimum days at risk",
      description = "The minimum number of days at risk?"
    ),
    "create_study_population.startAnchor" = list(
      label = "Risk window start anchor",
      summary_label = "Risk window start anchor"
    ),
    "create_study_population.riskWindowEnd" = list(
      label = "Risk window end",
      summary_label = "Risk window end"
    ),
    "create_study_population.endAnchor" = list(
      label = "Risk window end anchor",
      summary_label = "Risk window end anchor"
    ),
    "create_study_population.censorAtNewRiskWindow" = list(
      label = "Censor at new risk window",
      summary_label = "Censor at new risk window",
      description = "If a subject is in multiple cohorts, should time-at-risk be censored when the new time-at-risk start to prevent overlap?"
    ),
    "ps_adjustment.strategy" = list(
      label = "PS adjustment strategy",
      summary_label = "PS adjustment strategy"
    ),
    "ps_adjustment.trimmingStrategy" = list(
      label = "PS trimming",
      summary_label = "PS trimming",
      description = "How do you want to trim your cohorts based on the propensity score distribution?"
    ),
    "ps_adjustment.trimmingPercent" = list(
      label = "Trimming percent",
      summary_label = "Trimming percent",
      description = "What percentage of each tail should be removed?"
    ),
    "ps_adjustment.equipoiseLowerBound" = list(
      label = "Equipoise lower bound",
      summary_label = "Equipoise lower bound",
      description = "What is the lower preference score bound for trimming to equipoise?"
    ),
    "ps_adjustment.equipoiseUpperBound" = list(
      label = "Equipoise upper bound",
      summary_label = "Equipoise upper bound",
      description = "What is the upper preference score bound for trimming to equipoise?"
    ),
    "create_ps.estimator" = list(
      label = "PS estimator",
      summary_label = "PS estimator",
      description = "Defines the treatment effect target used when propensity scores are converted into adjustment weights or summaries."
    ),
    "create_ps.maxCohortSizeForFitting" = list(
      label = "Max cohort size for PS fitting",
      summary_label = "Max cohort size for PS fitting",
      description = "What is the maximum number of people to include in the propensity score model when fitting? Setting this number to 0 means no down-sampling will be applied:"
    ),
    "create_ps.errorOnHighCorrelation" = list(
      label = "Test covariate correlation",
      summary_label = "Test covariate correlation",
      description = "Test each covariate for correlation with the target assignment? If any covariate has an unusually high correlation (either positive or negative), this will throw an error."
    ),
    "create_ps.useRegularization" = list(
      label = "Use regularization",
      summary_label = "Use regularization",
      description = "Use regularization when fitting the propensity model?"
    ),
    "match_on_ps.caliper" = list(
      label = "Matching caliper",
      summary_label = "Matching caliper",
      description = "What is the caliper for matching:"
    ),
    "match_on_ps.caliperScale" = list(
      label = "Caliper scale",
      summary_label = "Caliper scale",
      description = "What is the caliper scale:"
    ),
    "match_on_ps.maxRatio" = list(
      label = "Maximum match ratio",
      summary_label = "Maximum match ratio",
      description = "What is the maximum number of persons in the comparator arm to be matched to each person in the target arm within the defined caliper? (0 = means no maximum - all comparators will be assigned to a target person):"
    ),
    "stratify_by_ps.numberOfStrata" = list(
      label = "Number of strata",
      summary_label = "Number of strata",
      description = "Into how many strata should the propensity score be divided? The boundaries of the strata are automatically defined to contain equal numbers of target persons:"
    ),
    "stratify_by_ps.baseSelection" = list(
      label = "Base selection for strata bounds",
      summary_label = "Base selection for strata bounds",
      description = "What is the base selection of subjects where the strata bounds are to be determined? Strata are defined as equally-sized strata inside this selection."
    ),
    "fit_outcome_model.modelType" = list(
      label = "Outcome model",
      summary_label = "Outcome model"
    ),
    "fit_outcome_model.stratified" = list(
      label = "Condition on strata",
      summary_label = "Condition on strata",
      description = "Should the regression be conditioned on the strata defined in the population object (e.g. by matching or stratifying on propensity scores)?"
    ),
    "fit_outcome_model.useCovariates" = list(
      label = "Use covariates in outcome model",
      summary_label = "Use covariates in outcome model",
      description = "Should the covariates also be included in the outcome model?"
    ),
    "fit_outcome_model.inversePtWeighting" = list(
      label = "Use IPTW",
      summary_label = "Use IPTW",
      description = "Use inverse probability of treatment weighting?"
    ),
    "fit_outcome_model.useRegularization" = list(
      label = "Use regularization",
      summary_label = "Use regularization",
      description = "Use regularization when fitting the outcome model?"
    )
  )
}

.studyAgentSummaryLabel <- function(path) {
  docs <- .studyAgentAnalyticSettingDocs()
  doc <- docs[[path]]
  if (is.null(doc)) return(path)
  if (!is.null(doc$summary_label)) return(as.character(doc$summary_label))
  if (!is.null(doc$label)) return(as.character(doc$label))
  path
}

.studyAgentFormatDateForPrompt <- function(value) {
  if (is.null(value) || length(value) == 0 || is.na(value)) return("")
  value <- trimws(as.character(value[[1]]))
  if (!nzchar(value)) return("")
  value
}

.studyAgentFormatAnalyticSettingValue <- function(value, path = NULL) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
  if (is.null(value) || length(value) == 0 || is.na(value)) return("<not set>")
  if (is.character(value) && length(value) == 1 && !nzchar(trimws(value))) return("<blank>")
  if (!is.null(path) && path %in% c("get_db_cohort_method_data.studyStartDate", "get_db_cohort_method_data.studyEndDate")) {
    return(.studyAgentFormatDateForPrompt(value))
  }
  if (is.logical(value) && length(value) == 1) return(if (isTRUE(value)) "Yes" else "No")
  if (is.character(value) && length(value) == 1) {
    mapped <- switch(
      path %||% "",
      "create_study_population.startAnchor" = c("cohort start" = "cohort start date", "cohort end" = "cohort end date")[[value]],
      "create_study_population.endAnchor" = c("cohort start" = "cohort start date", "cohort end" = "cohort end date")[[value]],
      "ps_adjustment.strategy" = c("match_on_ps" = "Match on propensity score", "stratify_by_ps" = "Stratify on propensity score", "none" = "None")[[value]],
      "ps_adjustment.trimmingStrategy" = c("none" = "None", "by_percent" = "By percent", "by_equipoise" = "By equipoise")[[value]],
      "match_on_ps.caliperScale" = c("propensity score" = "Propensity score", "standardized" = "Standardized", "standardized logit" = "Standardized logit")[[value]],
      "fit_outcome_model.modelType" = c("cox" = "Cox proportional hazards", "poisson" = "Poisson regression", "logistic" = "Logistic regression")[[value]],
      "create_study_population.removeDuplicateSubjects" = c("keep all" = "Keep All", "keep first" = "Keep First", "remove all" = "Remove All")[[value]],
      "get_db_cohort_method_data.removeDuplicateSubjects" = c("keep all" = "Keep All", "keep first" = "Keep First", "remove all" = "Remove All", "keep first, truncate to second" = "Keep First, Truncate to Second")[[value]],
      "stratify_by_ps.baseSelection" = c("all" = "Entire study population", "target" = "Target", "comparator" = "Comparator")[[value]],
      NULL
    )
    if (!is.null(mapped) && length(mapped) == 1 && !is.na(mapped)) return(mapped)
  }
  if (!is.null(path) && identical(path, "ps_adjustment.trimmingPercent") && is.numeric(value) && length(value) == 1) {
    formatted <- formatC(as.numeric(value), format = "fg", digits = 6)
    return(sprintf("%s%%", formatted))
  }
  if (is.numeric(value) && length(value) == 1) return(as.character(value))
  paste(as.character(value), collapse = ", ")
}

.studyAgentOutcomeModelDefaults <- function(ps_strategy = "match_on_ps",
                                            match_max_ratio = 1L,
                                            model_type = "cox") {
  normalized_strategy <- as.character(if (is.null(ps_strategy)) "match_on_ps" else ps_strategy)
  normalized_ratio <- suppressWarnings(as.integer(if (is.null(match_max_ratio)) 1L else match_max_ratio))
  if (length(normalized_ratio) == 0 || is.na(normalized_ratio)) normalized_ratio <- 1L

  stratified_default <- FALSE
  if (identical(normalized_strategy, "stratify_by_ps")) {
    stratified_default <- TRUE
  } else if (identical(normalized_strategy, "match_on_ps") && normalized_ratio != 1L) {
    stratified_default <- TRUE
  }

  list(
    modelType = as.character(if (is.null(model_type)) "cox" else model_type),
    stratified = isTRUE(stratified_default),
    useCovariates = FALSE,
    inversePtWeighting = FALSE,
    useRegularization = TRUE
  )
}

.studyAgentPrintDefaultSummary <- function(header, defaults, paths) {
  docs <- .studyAgentAnalyticSettingDocs()
  cat(sprintf("%s\n", header))
  for (path in paths) {
    doc <- docs[[path]]
    if (is.null(doc)) doc <- list(label = path, description = "")
    label <- .studyAgentSummaryLabel(path)
    value <- .studyAgentFormatAnalyticSettingValue(.studyAgentGetNestedValue(defaults, path), path = path)
    cat(sprintf("  - %s: %s\n", label, value))
  }
}

.studyAgentPromptKeepDefaults <- function(question, defaults, paths, io_ask_yesno) {
  cat(sprintf("%s\n", question))
  .studyAgentPrintDefaultSummary(
    "Default settings:",
    defaults,
    paths
  )
  io_ask_yesno("Keep these defaults? Choose No if you want to set the remaining options yourself.", default = TRUE)
}

.studyAgentPrintAnalyticSettingDescription <- function(path) {
  docs <- .studyAgentAnalyticSettingDocs()
  doc <- docs[[path]]
  if (is.null(doc) || is.null(doc$description)) return(invisible(NULL))
  description <- trimws(as.character(doc$description))
  if (!nzchar(description)) return(invisible(NULL))
  cat(sprintf("%s\n", description))
  invisible(NULL)
}

.studyAgentPromptAnalyticSetting <- function(working,
                                             path,
                                             ask_yesno,
                                             ask_choice,
                                             ask_integer,
                                             ask_numeric) {
  `%||%` <- function(x, y) if (is.null(x)) y else x

  .studyAgentPrintAnalyticSettingDescription(path)

  updated <- switch(
    path,
    "get_db_cohort_method_data.restrictToCommonPeriod" = .studyAgentSetNestedValue(
      working,
      path,
      ask_yesno(
        "",
        default = isTRUE(.studyAgentGetNestedValue(working, path))
      )
    ),
    "get_db_cohort_method_data.firstExposureOnly" = .studyAgentSetNestedValue(
      working,
      path,
      ask_yesno(
        "",
        default = isTRUE(.studyAgentGetNestedValue(working, path))
      )
    ),
    "get_db_cohort_method_data.washoutPeriod" = .studyAgentSetNestedValue(
      working,
      path,
      ask_integer(
        "",
        default = as.integer(.studyAgentGetNestedValue(working, path)),
        min_value = 0L,
        allow_negative = FALSE
      )
    ),
    "create_study_population.removeDuplicateSubjects" = .studyAgentSetNestedValue(
      working,
      path,
      ask_choice(
        "",
        choices = c("keep all", "keep first", "remove all"),
        labels = c("Keep All", "Keep First", "Remove All"),
        default = .studyAgentGetNestedValue(working, path) %||% "keep all"
      )
    ),
    "create_study_population.censorAtNewRiskWindow" = .studyAgentSetNestedValue(
      working,
      path,
      ask_yesno(
        "",
        default = isTRUE(.studyAgentGetNestedValue(working, path))
      )
    ),
    "create_study_population.removeSubjectsWithPriorOutcome" = .studyAgentSetNestedValue(
      working,
      path,
      ask_yesno(
        "",
        default = isTRUE(.studyAgentGetNestedValue(working, path))
      )
    ),
    "create_study_population.priorOutcomeLookback" = .studyAgentSetNestedValue(
      working,
      path,
      ask_integer(
        "",
        default = as.integer(.studyAgentGetNestedValue(working, path)),
        min_value = 0L,
        allow_negative = FALSE
      )
    ),
    "create_study_population.maxCohortSize" = .studyAgentSetNestedValue(
      working,
      path,
      ask_integer(
        "",
        default = as.integer(.studyAgentGetNestedValue(working, path)),
        min_value = 0L,
        allow_negative = FALSE
      )
    ),
    "create_study_population.minDaysAtRisk" = .studyAgentSetNestedValue(
      working,
      path,
      ask_integer(
        "",
        default = as.integer(.studyAgentGetNestedValue(working, path)),
        min_value = 0L,
        allow_negative = FALSE
      )
    ),
    "ps_adjustment.trimmingStrategy" = {
      updated_working <- .studyAgentSetNestedValue(
        working,
        path,
        ask_choice(
          "",
          choices = c("none", "by_percent", "by_equipoise"),
          labels = c("None", "By percent", "By equipoise"),
          default = .studyAgentGetNestedValue(working, path) %||% "none"
        )
      )
      selected_strategy <- .studyAgentGetNestedValue(updated_working, path) %||% "none"
      if (identical(selected_strategy, "by_percent")) {
        updated_working <- .studyAgentSetNestedValue(
          updated_working,
          "ps_adjustment.trimmingPercent",
          ask_numeric(
            "",
            default = as.numeric(.studyAgentGetNestedValue(updated_working, "ps_adjustment.trimmingPercent") %||% 5),
            min_value = 0
          )
        )
        updated_working <- .studyAgentSetNestedValue(updated_working, "ps_adjustment.equipoiseLowerBound", 0.25)
        updated_working <- .studyAgentSetNestedValue(updated_working, "ps_adjustment.equipoiseUpperBound", 0.75)
      } else if (identical(selected_strategy, "by_equipoise")) {
        updated_working <- .studyAgentSetNestedValue(
          updated_working,
          "ps_adjustment.equipoiseLowerBound",
          ask_numeric(
            "",
            default = as.numeric(.studyAgentGetNestedValue(updated_working, "ps_adjustment.equipoiseLowerBound") %||% 0.25),
            min_value = 0
          )
        )
        updated_working <- .studyAgentSetNestedValue(
          updated_working,
          "ps_adjustment.equipoiseUpperBound",
          ask_numeric(
            "",
            default = as.numeric(.studyAgentGetNestedValue(updated_working, "ps_adjustment.equipoiseUpperBound") %||% 0.75),
            min_value = 0
          )
        )
        updated_working <- .studyAgentSetNestedValue(updated_working, "ps_adjustment.trimmingPercent", 5)
      } else {
        updated_working <- .studyAgentSetNestedValue(updated_working, "ps_adjustment.trimmingPercent", 5)
        updated_working <- .studyAgentSetNestedValue(updated_working, "ps_adjustment.equipoiseLowerBound", 0.25)
        updated_working <- .studyAgentSetNestedValue(updated_working, "ps_adjustment.equipoiseUpperBound", 0.75)
      }
      updated_working
    },
    "ps_adjustment.trimmingPercent" = .studyAgentSetNestedValue(
      working,
      path,
      ask_numeric(
        "",
        default = as.numeric(.studyAgentGetNestedValue(working, path) %||% 5),
        min_value = 0
      )
    ),
    "ps_adjustment.equipoiseLowerBound" = .studyAgentSetNestedValue(
      working,
      path,
      ask_numeric(
        "",
        default = as.numeric(.studyAgentGetNestedValue(working, path) %||% 0.25),
        min_value = 0
      )
    ),
    "ps_adjustment.equipoiseUpperBound" = .studyAgentSetNestedValue(
      working,
      path,
      ask_numeric(
        "",
        default = as.numeric(.studyAgentGetNestedValue(working, path) %||% 0.75),
        min_value = 0
      )
    ),
    "create_ps.maxCohortSizeForFitting" = .studyAgentSetNestedValue(
      working,
      path,
      ask_integer(
        "",
        default = as.integer(.studyAgentGetNestedValue(working, path)),
        min_value = 0L,
        allow_negative = FALSE
      )
    ),
    "create_ps.errorOnHighCorrelation" = .studyAgentSetNestedValue(
      working,
      path,
      ask_yesno(
        "",
        default = isTRUE(.studyAgentGetNestedValue(working, path))
      )
    ),
    "create_ps.useRegularization" = .studyAgentSetNestedValue(
      working,
      path,
      ask_yesno(
        "",
        default = isTRUE(.studyAgentGetNestedValue(working, path))
      )
    ),
    "match_on_ps.caliper" = .studyAgentSetNestedValue(
      working,
      path,
      ask_numeric(
        "",
        default = as.numeric(.studyAgentGetNestedValue(working, path)),
        min_value = 0
      )
    ),
    "match_on_ps.caliperScale" = .studyAgentSetNestedValue(
      working,
      path,
      ask_choice(
        "",
        choices = c("propensity score", "standardized", "standardized logit"),
        labels = c("Propensity score", "Standardized", "Standardized logit"),
        default = .studyAgentGetNestedValue(working, path) %||% "standardized logit"
      )
    ),
    "stratify_by_ps.baseSelection" = .studyAgentSetNestedValue(
      working,
      path,
      ask_choice(
        "",
        choices = c("all", "target", "comparator"),
        labels = c("Entire study population", "Target", "Comparator"),
        default = .studyAgentGetNestedValue(working, path) %||% "all"
      )
    ),
    "fit_outcome_model.stratified" = .studyAgentSetNestedValue(
      working,
      path,
      ask_yesno(
        "",
        default = isTRUE(.studyAgentGetNestedValue(working, path))
      )
    ),
    "fit_outcome_model.useCovariates" = .studyAgentSetNestedValue(
      working,
      path,
      ask_yesno(
        "",
        default = isTRUE(.studyAgentGetNestedValue(working, path))
      )
    ),
    "fit_outcome_model.inversePtWeighting" = .studyAgentSetNestedValue(
      working,
      path,
      ask_yesno(
        "",
        default = isTRUE(.studyAgentGetNestedValue(working, path))
      )
    ),
    "fit_outcome_model.useRegularization" = .studyAgentSetNestedValue(
      working,
      path,
      ask_yesno(
        "",
        default = isTRUE(.studyAgentGetNestedValue(working, path))
      )
    ),
    stop(sprintf("Unsupported analytic setting customization path: %s", path))
  )

  updated
}

.studyAgentCustomizeAnalyticSettings <- function(working,
                                                 paths,
                                                 ask_yesno,
                                                 ask_choice,
                                                 ask_integer,
                                                 ask_numeric) {
  updated <- working
  for (path in paths) {
    updated <- .studyAgentPromptAnalyticSetting(
      updated,
      path,
      ask_yesno = ask_yesno,
      ask_choice = ask_choice,
      ask_integer = ask_integer,
      ask_numeric = ask_numeric
    )
  }
  updated
}

.studyAgentSummaryPathsForSection <- function(section_name, section_paths, settings) {
  paths <- section_paths[[section_name]]
  if (!identical(section_name, "propensity_score_adjustment")) {
    return(paths)
  }

  strategy <- .studyAgentGetNestedValue(settings, "ps_adjustment.strategy")
  if (identical(strategy, "match_on_ps")) {
    trim_strategy <- .studyAgentGetNestedValue(settings, "ps_adjustment.trimmingStrategy")
    trim_paths <- c("ps_adjustment.trimmingStrategy")
    if (identical(trim_strategy, "by_percent")) {
      trim_paths <- c(trim_paths, "ps_adjustment.trimmingPercent")
    } else if (identical(trim_strategy, "by_equipoise")) {
      trim_paths <- c(trim_paths, "ps_adjustment.equipoiseLowerBound", "ps_adjustment.equipoiseUpperBound")
    }
    return(c(
      trim_paths,
      "ps_adjustment.strategy",
      "create_ps.maxCohortSizeForFitting",
      "create_ps.errorOnHighCorrelation",
      "create_ps.useRegularization",
      "match_on_ps.maxRatio",
      "match_on_ps.caliper",
      "match_on_ps.caliperScale"
    ))
  }
  if (identical(strategy, "stratify_by_ps")) {
    trim_strategy <- .studyAgentGetNestedValue(settings, "ps_adjustment.trimmingStrategy")
    trim_paths <- c("ps_adjustment.trimmingStrategy")
    if (identical(trim_strategy, "by_percent")) {
      trim_paths <- c(trim_paths, "ps_adjustment.trimmingPercent")
    } else if (identical(trim_strategy, "by_equipoise")) {
      trim_paths <- c(trim_paths, "ps_adjustment.equipoiseLowerBound", "ps_adjustment.equipoiseUpperBound")
    }
    return(c(
      trim_paths,
      "ps_adjustment.strategy",
      "create_ps.maxCohortSizeForFitting",
      "create_ps.errorOnHighCorrelation",
      "create_ps.useRegularization",
      "stratify_by_ps.numberOfStrata",
      "stratify_by_ps.baseSelection"
    ))
  }
  trim_strategy <- .studyAgentGetNestedValue(settings, "ps_adjustment.trimmingStrategy")
  trim_paths <- c("ps_adjustment.trimmingStrategy")
  if (identical(trim_strategy, "by_percent")) {
    trim_paths <- c(trim_paths, "ps_adjustment.trimmingPercent")
  } else if (identical(trim_strategy, "by_equipoise")) {
    trim_paths <- c(trim_paths, "ps_adjustment.equipoiseLowerBound", "ps_adjustment.equipoiseUpperBound")
  }
  c(trim_paths, "ps_adjustment.strategy")
}

.studyAgentPrintFinalSettingsSummary <- function(settings, section_paths) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
  docs <- .studyAgentAnalyticSettingDocs()
  section_titles <- .studyAgentAnalyticSettingsSectionTitles()
  cat("\nFinal analytic settings\n")
  cat(sprintf("Profile name: %s\n", .studyAgentFormatAnalyticSettingValue(settings$profile_name)))
  for (section_name in names(section_paths)) {
    title <- section_titles[[section_name]] %||% gsub("_", " ", section_name, fixed = TRUE)
    cat(sprintf("[%s]\n", title))
    for (path in .studyAgentSummaryPathsForSection(section_name, section_paths, settings)) {
      label <- .studyAgentSummaryLabel(path)
      value <- .studyAgentFormatAnalyticSettingValue(.studyAgentGetNestedValue(settings, path), path = path)
      cat(sprintf("  - %s: %s\n", label, value))
    }
  }
}

.studyAgentDefaultCohortMethodAnalyticSettings <- function(covariate_enabled = FALSE) {
  list(
    profile_name = "Analytic Setting 1",
    source = "manual_shell",
    customized_sections = character(0),
    get_db_cohort_method_data = list(
      studyStartDate = "",
      studyEndDate = "",
      firstExposureOnly = TRUE,
      washoutPeriod = 365L,
      restrictToCommonPeriod = TRUE,
      removeDuplicateSubjects = "keep first, truncate to second"
    ),
    create_study_population = list(
      maxCohortSize = 0L,
      removeDuplicateSubjects = "keep all",
      removeSubjectsWithPriorOutcome = TRUE,
      priorOutcomeLookback = 99999L,
      minDaysAtRisk = 1L,
      riskWindowStart = 0L,
      startAnchor = "cohort start",
      riskWindowEnd = 0L,
      endAnchor = "cohort end",
      censorAtNewRiskWindow = FALSE
    ),
    create_ps = list(
      estimator = "att",
      maxCohortSizeForFitting = 250000L,
      errorOnHighCorrelation = FALSE,
      useRegularization = TRUE
    ),
    ps_adjustment = list(
      strategy = "match_on_ps",
      trimmingStrategy = "none",
      trimmingPercent = 5,
      equipoiseLowerBound = 0.25,
      equipoiseUpperBound = 0.75
    ),
    match_on_ps = list(
      caliper = 0.2,
      caliperScale = "standardized logit",
      maxRatio = 1L
    ),
    stratify_by_ps = list(
      numberOfStrata = 10L,
      baseSelection = "all"
    ),
    fit_outcome_model = list(
      modelType = "cox",
      stratified = FALSE,
      useCovariates = FALSE,
      inversePtWeighting = FALSE,
      useRegularization = TRUE
    ),
    covariate_concept_sets = list(
      enabled = isTRUE(covariate_enabled),
      include_all_concepts = TRUE,
      include_concept_set_id = NA_integer_,
      exclude_concept_set_id = NA_integer_
    )
  )
}

.studyAgentGetNestedValue <- function(x, path) {
  parts <- strsplit(path, ".", fixed = TRUE)[[1]]
  current <- x
  for (part in parts) {
    if (!is.list(current) || is.null(current[[part]])) return(NULL)
    current <- current[[part]]
  }
  current
}

.studyAgentSetNestedValue <- function(x, path, value) {
  parts <- strsplit(path, ".", fixed = TRUE)[[1]]

  set_rec <- function(obj, idx = 1L) {
    key <- parts[[idx]]
    if (idx == length(parts)) {
      obj[[key]] <- value
      return(obj)
    }
    child <- obj[[key]]
    if (!is.list(child)) child <- list()
    obj[[key]] <- set_rec(child, idx + 1L)
    obj
  }

  set_rec(x, 1L)
}

.studyAgentResetSectionPaths <- function(current_settings, default_settings, paths) {
  updated <- current_settings
  for (path in paths) {
    updated <- .studyAgentSetNestedValue(
      updated,
      path,
      .studyAgentGetNestedValue(default_settings, path)
    )
  }
  updated
}

.studyAgentDeepMerge <- function(defaults, overrides) {
  if (is.null(overrides)) return(defaults)
  for (name in names(overrides)) {
    override_value <- overrides[[name]]
    default_value <- defaults[[name]]
    if (is.list(default_value) && is.list(override_value) && !is.data.frame(override_value)) {
      defaults[[name]] <- .studyAgentDeepMerge(default_value, override_value)
    } else if (!is.null(override_value)) {
      defaults[[name]] <- override_value
    }
  }
  defaults
}

.studyAgentDateStringOrEmpty <- function(value, label) {
  if (is.null(value) || length(value) == 0 || is.na(value)) return("")
  value <- trimws(as.character(value[[1]]))
  if (!nzchar(value)) return("")
  if (grepl("^[0-9]{8}$", value)) return(value)
  stop(sprintf("%s must be blank or formatted as YYYYMMDD.", label))
}

.studyAgentDefaultCmAnalysisTemplate <- function() {
  list(
    description = "",
    getDbCohortMethodDataArgs = list(
      studyStartDate = "",
      studyEndDate = "",
      firstExposureOnly = FALSE,
      removeDuplicateSubjects = "keep all",
      restrictToCommonPeriod = FALSE,
      washoutPeriod = 365L,
      maxCohortSize = 0L
    ),
    createStudyPopArgs = list(
      removeSubjectsWithPriorOutcome = TRUE,
      priorOutcomeLookback = 99999L,
      minDaysAtRisk = 1L,
      riskWindowStart = 1L,
      startAnchor = "cohort start",
      riskWindowEnd = 0L,
      endAnchor = "cohort end",
      censorAtNewRiskWindow = FALSE
    ),
    trimByPsArgs = list(
      trimFraction = 0.05,
      equipoiseBounds = NA
    ),
    matchOnPsArgs = list(
      maxRatio = 1L,
      caliper = 0.2,
      caliperScale = "standardized logit"
    ),
    stratifyByPsArgs = NA,
    createPsArgs = list(
      maxCohortSizeForFitting = 250000L,
      errorOnHighCorrelation = TRUE,
      prior = list(
        priorType = "laplace",
        useCrossValidation = TRUE
      ),
      control = list(
        tolerance = 2e-7,
        cvType = "auto",
        fold = 10L,
        cvRepetitions = 10L,
        noiseLevel = "silent",
        resetCoefficients = TRUE,
        startingVariance = 0.01
      )
    ),
    fitOutcomeModelArgs = list(
      modelType = "cox",
      stratified = FALSE,
      useCovariates = FALSE,
      inversePtWeighting = FALSE,
      prior = list(
        priorType = "laplace",
        useCrossValidation = TRUE
      ),
      control = list(
        tolerance = 2e-7,
        cvType = "auto",
        fold = 10L,
        cvRepetitions = 10L,
        noiseLevel = "quiet",
        resetCoefficients = TRUE,
        startingVariance = 0.01
      )
    )
  )
}

.studyAgentLoadCmAnalysisTemplate <- function(template_path = NULL) {
  template <- .studyAgentDefaultCmAnalysisTemplate()
  if (!is.null(template_path) && length(template_path) > 0 && !is.na(template_path) && nzchar(template_path) && file.exists(template_path)) {
    loaded <- jsonlite::fromJSON(template_path, simplifyVector = FALSE)
    template <- .studyAgentDeepMerge(template, loaded)
  }
  template
}

.studyAgentBuildCmAnalysisJson <- function(settings, template = NULL) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
  template <- template %||% .studyAgentDefaultCmAnalysisTemplate()

  ps_strategy <- settings$ps_adjustment$strategy %||% "match_on_ps"
  trimming_strategy <- settings$ps_adjustment$trimmingStrategy %||% "none"
  ps_regularized <- isTRUE(settings$create_ps$useRegularization)
  outcome_regularized <- isTRUE(settings$fit_outcome_model$useRegularization)

  ps_prior <- if (ps_regularized) template$createPsArgs$prior else NA
  ps_control <- if (ps_regularized) template$createPsArgs$control else NA
  outcome_prior <- if (outcome_regularized) template$fitOutcomeModelArgs$prior else NA
  outcome_control <- if (outcome_regularized) template$fitOutcomeModelArgs$control else NA

  trim_args <- NA
  if (identical(trimming_strategy, "by_percent")) {
    trim_args <- list(
      trimFraction = as.numeric(settings$ps_adjustment$trimmingPercent) / 100,
      equipoiseBounds = NA
    )
  } else if (identical(trimming_strategy, "by_equipoise")) {
    trim_args <- list(
      trimFraction = NA_real_,
      equipoiseBounds = c(
        as.numeric(settings$ps_adjustment$equipoiseLowerBound),
        as.numeric(settings$ps_adjustment$equipoiseUpperBound)
      )
    )
  }

  match_args <- if (identical(ps_strategy, "match_on_ps")) {
    list(
      maxRatio = as.integer(settings$match_on_ps$maxRatio),
      caliper = as.numeric(settings$match_on_ps$caliper),
      caliperScale = as.character(settings$match_on_ps$caliperScale)
    )
  } else {
    NA
  }

  stratify_args <- if (identical(ps_strategy, "stratify_by_ps")) {
    list(
      numberOfStrata = as.integer(settings$stratify_by_ps$numberOfStrata),
      baseSelection = as.character(settings$stratify_by_ps$baseSelection)
    )
  } else {
    NA
  }

  create_ps_args <- if (identical(ps_strategy, "none") && identical(trimming_strategy, "none")) {
    NA
  } else {
    list(
      maxCohortSizeForFitting = as.integer(settings$create_ps$maxCohortSizeForFitting),
      errorOnHighCorrelation = isTRUE(settings$create_ps$errorOnHighCorrelation),
      prior = ps_prior,
      control = ps_control
    )
  }

  list(
    description = as.character(settings$profile_name),
    getDbCohortMethodDataArgs = list(
      studyStartDate = as.character(settings$get_db_cohort_method_data$studyStartDate %||% ""),
      studyEndDate = as.character(settings$get_db_cohort_method_data$studyEndDate %||% ""),
      firstExposureOnly = isTRUE(settings$get_db_cohort_method_data$firstExposureOnly),
      removeDuplicateSubjects = as.character(settings$get_db_cohort_method_data$removeDuplicateSubjects),
      restrictToCommonPeriod = isTRUE(settings$get_db_cohort_method_data$restrictToCommonPeriod),
      washoutPeriod = as.integer(settings$get_db_cohort_method_data$washoutPeriod),
      maxCohortSize = as.integer(settings$create_study_population$maxCohortSize)
    ),
    createStudyPopArgs = list(
      removeSubjectsWithPriorOutcome = isTRUE(settings$create_study_population$removeSubjectsWithPriorOutcome),
      priorOutcomeLookback = as.integer(settings$create_study_population$priorOutcomeLookback),
      minDaysAtRisk = as.integer(settings$create_study_population$minDaysAtRisk),
      riskWindowStart = as.integer(settings$create_study_population$riskWindowStart),
      startAnchor = as.character(settings$create_study_population$startAnchor),
      riskWindowEnd = as.integer(settings$create_study_population$riskWindowEnd),
      endAnchor = as.character(settings$create_study_population$endAnchor),
      censorAtNewRiskWindow = isTRUE(settings$create_study_population$censorAtNewRiskWindow)
    ),
    trimByPsArgs = trim_args,
    matchOnPsArgs = match_args,
    stratifyByPsArgs = stratify_args,
    createPsArgs = create_ps_args,
    fitOutcomeModelArgs = list(
      modelType = as.character(settings$fit_outcome_model$modelType),
      stratified = isTRUE(settings$fit_outcome_model$stratified),
      useCovariates = isTRUE(settings$fit_outcome_model$useCovariates),
      inversePtWeighting = isTRUE(settings$fit_outcome_model$inversePtWeighting),
      prior = outcome_prior,
      control = outcome_control
    )
  )
}

.studyAgentCollectStepByStepAnalyticSettings <- function(default_settings,
                                                         seed_settings,
                                                         interactive = TRUE,
                                                         io = NULL) {
  `%||%` <- function(x, y) if (is.null(x)) y else x

  normalize_seed <- function(settings) {
    settings <- settings %||% list()
    if (is.null(settings$ps_adjustment)) {
      settings$ps_adjustment <- list(strategy = "match_on_ps")
    }
    if (is.null(settings$stratify_by_ps)) {
      settings$stratify_by_ps <- list(
        numberOfStrata = default_settings$stratify_by_ps$numberOfStrata,
        baseSelection = default_settings$stratify_by_ps$baseSelection
      )
    }
    settings
  }

  ask_text <- function(prompt, default = "", allow_blank = FALSE) {
    if (!isTRUE(interactive)) return(default)
    value <- io$text(prompt = prompt, default = default, allow_blank = allow_blank)
    trimmed <- trimws(as.character(value %||% ""))
    if (!nzchar(trimmed) && !isTRUE(allow_blank)) {
      stop(sprintf("A non-empty value is required for: %s", prompt))
    }
    trimmed
  }

  ask_yesno <- function(prompt, default = TRUE) {
    if (!isTRUE(interactive)) return(default)
    io$yesno(prompt = prompt, default = default)
  }

  ask_choice <- function(prompt, choices, default, labels = choices) {
    if (!isTRUE(interactive)) return(default)
    io$choice(prompt = prompt, choices = choices, default = default, labels = labels)
  }

  ask_integer <- function(prompt, default, min_value = NULL, allow_negative = TRUE) {
    if (!isTRUE(interactive)) return(as.integer(default))
    io$integer(
      prompt = prompt,
      default = default,
      min_value = min_value,
      allow_negative = allow_negative
    )
  }

  ask_numeric <- function(prompt, default, min_value = NULL) {
    if (!isTRUE(interactive)) return(as.numeric(default))
    io$numeric(prompt = prompt, default = default, min_value = min_value)
  }

  section_paths <- .studyAgentAnalyticSettingsSectionPaths()
  working <- .studyAgentDeepMerge(default_settings, normalize_seed(seed_settings))
  working <- .studyAgentSetNestedValue(
    working,
    "get_db_cohort_method_data.removeDuplicateSubjects",
    .studyAgentGetNestedValue(default_settings, "get_db_cohort_method_data.removeDuplicateSubjects")
  )
  working <- .studyAgentSetNestedValue(
    working,
    "create_ps.estimator",
    .studyAgentGetNestedValue(default_settings, "create_ps.estimator")
  )
  working <- .studyAgentSetNestedValue(
    working,
    "create_ps.errorOnHighCorrelation",
    isTRUE(.studyAgentGetNestedValue(default_settings, "create_ps.errorOnHighCorrelation"))
  )
  working <- .studyAgentSetNestedValue(
    working,
    "create_ps.useRegularization",
    isTRUE(.studyAgentGetNestedValue(default_settings, "create_ps.useRegularization"))
  )
  working <- .studyAgentSetNestedValue(
    working,
    "stratify_by_ps.baseSelection",
    .studyAgentGetNestedValue(default_settings, "stratify_by_ps.baseSelection")
  )
  working$source <- "manual_shell"
  working$customized_sections <- character(0)

  show_section <- function(label) {
    if (isTRUE(interactive) && !is.null(io$section_header)) {
      io$section_header(label)
    }
  }

  show_section("Study Population")
  study_start <- ask_text(
    "Study start date (YYYYMMDD, leave blank for no restriction)",
    default = .studyAgentFormatDateForPrompt(.studyAgentGetNestedValue(working, "get_db_cohort_method_data.studyStartDate")),
    allow_blank = TRUE
  )
  study_end <- ask_text(
    "Study end date (YYYYMMDD, leave blank for no restriction)",
    default = .studyAgentFormatDateForPrompt(.studyAgentGetNestedValue(working, "get_db_cohort_method_data.studyEndDate")),
    allow_blank = TRUE
  )
  working <- .studyAgentSetNestedValue(
    working,
    "get_db_cohort_method_data.studyStartDate",
    .studyAgentDateStringOrEmpty(study_start, "Study start date")
  )
  working <- .studyAgentSetNestedValue(
    working,
    "get_db_cohort_method_data.studyEndDate",
    .studyAgentDateStringOrEmpty(study_end, "Study end date")
  )
  study_population_non_core <- setdiff(
    section_paths$study_population,
    c(
      "get_db_cohort_method_data.studyStartDate",
      "get_db_cohort_method_data.studyEndDate"
    )
  )
  if (isTRUE(interactive)) {
    keep_study_population_defaults <- .studyAgentPromptKeepDefaults(
      "For the remaining study population settings, keep the defaults or choose each option yourself?",
      default_settings,
      study_population_non_core
      ,
      ask_yesno
    )
    if (isTRUE(keep_study_population_defaults)) {
      working <- .studyAgentResetSectionPaths(working, default_settings, study_population_non_core)
    } else {
      working <- .studyAgentCustomizeAnalyticSettings(
        working,
        study_population_non_core,
        ask_yesno = ask_yesno,
        ask_choice = ask_choice,
        ask_integer = ask_integer,
        ask_numeric = ask_numeric
      )
    }
  }

  show_section("Time At Risk")
  anchor_choices <- c("cohort start", "cohort end")
  anchor_labels <- c("cohort start date", "cohort end date")
  working <- .studyAgentSetNestedValue(
    working,
    "create_study_population.startAnchor",
    ask_choice(
      "Risk window start anchor",
      choices = anchor_choices,
      labels = anchor_labels,
      default = .studyAgentGetNestedValue(working, "create_study_population.startAnchor") %||% anchor_choices[[1]]
    )
  )
  working <- .studyAgentSetNestedValue(
    working,
    "create_study_population.riskWindowStart",
    ask_integer(
      "Risk window start (days)",
      default = as.integer(.studyAgentGetNestedValue(working, "create_study_population.riskWindowStart")),
      allow_negative = TRUE
    )
  )
  working <- .studyAgentSetNestedValue(
    working,
    "create_study_population.endAnchor",
    ask_choice(
      "Risk window end anchor",
      choices = anchor_choices,
      labels = anchor_labels,
      default = .studyAgentGetNestedValue(working, "create_study_population.endAnchor") %||% anchor_choices[[2]]
    )
  )
  working <- .studyAgentSetNestedValue(
    working,
    "create_study_population.riskWindowEnd",
    ask_integer(
      "Risk window end (days)",
      default = as.integer(.studyAgentGetNestedValue(working, "create_study_population.riskWindowEnd")),
      allow_negative = TRUE
    )
  )
  if (isTRUE(interactive)) {
    tar_non_core <- c("create_study_population.minDaysAtRisk")
    keep_tar_defaults <- .studyAgentPromptKeepDefaults(
      "For the remaining time-at-risk settings, keep the defaults or choose each option yourself?",
      default_settings,
      tar_non_core,
      ask_yesno
    )
    if (isTRUE(keep_tar_defaults)) {
      working <- .studyAgentResetSectionPaths(working, default_settings, tar_non_core)
    } else {
      working <- .studyAgentCustomizeAnalyticSettings(
        working,
        tar_non_core,
        ask_yesno = ask_yesno,
        ask_choice = ask_choice,
        ask_integer = ask_integer,
        ask_numeric = ask_numeric
      )
    }
  }

  show_section("Propensity Score Adjustment")
  strategy_choices <- c("match_on_ps", "stratify_by_ps", "none")
  strategy_labels <- c("Match on propensity score", "Stratify on propensity score", "None")
  working <- .studyAgentSetNestedValue(
    working,
    "ps_adjustment.strategy",
    ask_choice(
      "PS adjustment strategy",
      choices = strategy_choices,
      labels = strategy_labels,
      default = .studyAgentGetNestedValue(working, "ps_adjustment.strategy") %||% strategy_choices[[1]]
    )
  )
  current_strategy <- .studyAgentGetNestedValue(working, "ps_adjustment.strategy") %||% "match_on_ps"
  if (isTRUE(interactive)) {
    if (identical(current_strategy, "none")) {
      ps_default_paths <- c(
        "ps_adjustment.trimmingStrategy",
        "create_ps.maxCohortSizeForFitting",
        "create_ps.errorOnHighCorrelation",
        "create_ps.useRegularization"
      )
      keep_ps_defaults <- .studyAgentPromptKeepDefaults(
        "For the remaining propensity score adjustment settings, keep the defaults?",
        default_settings,
        ps_default_paths,
        ask_yesno
      )
      if (isTRUE(keep_ps_defaults)) {
        working <- .studyAgentResetSectionPaths(
          working,
          default_settings,
          c(
            ps_default_paths,
            "ps_adjustment.trimmingPercent",
            "ps_adjustment.equipoiseLowerBound",
            "ps_adjustment.equipoiseUpperBound"
          )
        )
      } else {
        working <- .studyAgentCustomizeAnalyticSettings(
          working,
          ps_default_paths,
          ask_yesno = ask_yesno,
          ask_choice = ask_choice,
          ask_integer = ask_integer,
          ask_numeric = ask_numeric
        )
      }
      working <- .studyAgentResetSectionPaths(
        working,
        default_settings,
        c(
          "match_on_ps.caliper",
          "match_on_ps.caliperScale",
          "match_on_ps.maxRatio",
          "stratify_by_ps.numberOfStrata",
          "stratify_by_ps.baseSelection"
        )
      )
    } else if (identical(current_strategy, "match_on_ps")) {
      working <- .studyAgentSetNestedValue(
        working,
        "match_on_ps.maxRatio",
        ask_integer(
          "Maximum match ratio (0 means no maximum)",
          default = as.integer(.studyAgentGetNestedValue(working, "match_on_ps.maxRatio")),
          min_value = 0L,
          allow_negative = FALSE
        )
      )
      ps_default_paths <- c(
        "ps_adjustment.trimmingStrategy",
        "create_ps.maxCohortSizeForFitting",
        "create_ps.errorOnHighCorrelation",
        "create_ps.useRegularization",
        "match_on_ps.caliper",
        "match_on_ps.caliperScale"
      )
      keep_ps_defaults <- .studyAgentPromptKeepDefaults(
        "For the remaining propensity score adjustment settings, keep the defaults?",
        default_settings,
        ps_default_paths,
        ask_yesno
      )
      if (isTRUE(keep_ps_defaults)) {
        working <- .studyAgentResetSectionPaths(
          working,
          default_settings,
          c(
            ps_default_paths,
            "ps_adjustment.trimmingPercent",
            "ps_adjustment.equipoiseLowerBound",
            "ps_adjustment.equipoiseUpperBound"
          )
        )
      } else {
        working <- .studyAgentCustomizeAnalyticSettings(
          working,
          ps_default_paths,
          ask_yesno = ask_yesno,
          ask_choice = ask_choice,
          ask_integer = ask_integer,
          ask_numeric = ask_numeric
        )
      }
      working <- .studyAgentResetSectionPaths(
        working,
        default_settings,
        c("stratify_by_ps.numberOfStrata", "stratify_by_ps.baseSelection")
      )
    } else if (identical(current_strategy, "stratify_by_ps")) {
      working <- .studyAgentSetNestedValue(
        working,
        "stratify_by_ps.numberOfStrata",
        ask_integer(
          "Number of strata",
          default = as.integer(.studyAgentGetNestedValue(working, "stratify_by_ps.numberOfStrata")),
          min_value = 1L,
          allow_negative = FALSE
        )
      )
      working <- .studyAgentSetNestedValue(
        working,
        "stratify_by_ps.baseSelection",
        .studyAgentGetNestedValue(default_settings, "stratify_by_ps.baseSelection")
      )
      ps_default_paths <- c(
        "ps_adjustment.trimmingStrategy",
        "create_ps.maxCohortSizeForFitting",
        "create_ps.errorOnHighCorrelation",
        "create_ps.useRegularization",
        "stratify_by_ps.baseSelection"
      )
      keep_ps_defaults <- .studyAgentPromptKeepDefaults(
        "For the remaining propensity score adjustment settings, keep the defaults?",
        default_settings,
        ps_default_paths,
        ask_yesno
      )
      if (isTRUE(keep_ps_defaults)) {
        working <- .studyAgentResetSectionPaths(
          working,
          default_settings,
          c(
            ps_default_paths,
            "ps_adjustment.trimmingPercent",
            "ps_adjustment.equipoiseLowerBound",
            "ps_adjustment.equipoiseUpperBound"
          )
        )
      } else {
        working <- .studyAgentCustomizeAnalyticSettings(
          working,
          ps_default_paths,
          ask_yesno = ask_yesno,
          ask_choice = ask_choice,
          ask_integer = ask_integer,
          ask_numeric = ask_numeric
        )
      }
      working <- .studyAgentResetSectionPaths(
        working,
        default_settings,
        c("match_on_ps.caliper", "match_on_ps.caliperScale", "match_on_ps.maxRatio")
      )
    }
  }

  show_section("Outcome Model")
  outcome_model_defaults <- .studyAgentOutcomeModelDefaults(
    ps_strategy = current_strategy,
    match_max_ratio = .studyAgentGetNestedValue(working, "match_on_ps.maxRatio"),
    model_type = .studyAgentGetNestedValue(working, "fit_outcome_model.modelType") %||% default_settings$fit_outcome_model$modelType
  )
  model_choices <- c("cox", "poisson", "logistic")
  model_labels <- c("Cox proportional hazards", "Poisson regression", "Logistic regression")
  working <- .studyAgentSetNestedValue(
    working,
    "fit_outcome_model.modelType",
    ask_choice(
      "Outcome model",
      choices = model_choices,
      labels = model_labels,
      default = .studyAgentGetNestedValue(working, "fit_outcome_model.modelType") %||% model_choices[[1]]
    )
  )
  outcome_model_defaults$modelType <- .studyAgentGetNestedValue(working, "fit_outcome_model.modelType") %||% outcome_model_defaults$modelType
  outcome_defaults_for_display <- .studyAgentDeepMerge(
    default_settings,
    list(fit_outcome_model = outcome_model_defaults)
  )
  keep_outcome_defaults <- !isTRUE(interactive)
  if (isTRUE(interactive)) {
    keep_outcome_defaults <- .studyAgentPromptKeepDefaults(
      "For the remaining outcome model settings, keep the defaults or choose each option yourself?",
      outcome_defaults_for_display,
      setdiff(section_paths$outcome_model, "fit_outcome_model.modelType")
      ,
      ask_yesno
    )
    if (!isTRUE(keep_outcome_defaults)) {
      working <- .studyAgentSetNestedValue(working, "fit_outcome_model.stratified", isTRUE(outcome_model_defaults$stratified))
      working <- .studyAgentSetNestedValue(working, "fit_outcome_model.useCovariates", isTRUE(outcome_model_defaults$useCovariates))
      working <- .studyAgentSetNestedValue(working, "fit_outcome_model.inversePtWeighting", isTRUE(outcome_model_defaults$inversePtWeighting))
      working <- .studyAgentSetNestedValue(working, "fit_outcome_model.useRegularization", isTRUE(outcome_model_defaults$useRegularization))
      working <- .studyAgentCustomizeAnalyticSettings(
        working,
        setdiff(section_paths$outcome_model, "fit_outcome_model.modelType"),
        ask_yesno = ask_yesno,
        ask_choice = ask_choice,
        ask_integer = ask_integer,
        ask_numeric = ask_numeric
      )
    }
  }
  if (isTRUE(keep_outcome_defaults)) {
    working <- .studyAgentSetNestedValue(working, "fit_outcome_model.stratified", isTRUE(outcome_model_defaults$stratified))
    working <- .studyAgentSetNestedValue(working, "fit_outcome_model.useCovariates", isTRUE(outcome_model_defaults$useCovariates))
    working <- .studyAgentSetNestedValue(working, "fit_outcome_model.inversePtWeighting", isTRUE(outcome_model_defaults$inversePtWeighting))
    working <- .studyAgentSetNestedValue(working, "fit_outcome_model.useRegularization", isTRUE(outcome_model_defaults$useRegularization))
  }

  if (isTRUE(interactive)) {
    working$profile_name <- ask_text(
      "Analytic settings profile name",
      default = as.character(working$profile_name %||% default_settings$profile_name),
      allow_blank = FALSE
    )
    .studyAgentPrintFinalSettingsSummary(working, section_paths)
  }

  customized_sections <- names(section_paths)[vapply(names(section_paths), function(section_name) {
    paths <- section_paths[[section_name]]
    any(vapply(paths, function(path) {
      !identical(
        .studyAgentGetNestedValue(working, path),
        .studyAgentGetNestedValue(default_settings, path)
      )
    }, logical(1)))
  }, logical(1))]
  working$customized_sections <- customized_sections

  list(
    settings = working,
    section_flow = names(section_paths),
    customized_sections = customized_sections
  )
}

runStrategusCohortMethodsShell <- function(outputDir = "demo-strategus-cohort-methods",
                                           acpUrl = "http://127.0.0.1:8765",
                                           studyIntent = NULL,
                                           targetStatement = NULL,
                                           comparatorStatement = NULL,
                                           outcomeStatement = NULL,
                                           targetCohortId = NULL,
                                           comparatorCohortId = NULL,
                                           outcomeCohortIds = NULL,
                                           comparisonLabel = NULL,
                                           topK = 20,
                                           maxResults = 20,
                                           candidateLimit = 20,
                                           indexDir = Sys.getenv("PHENOTYPE_INDEX_DIR", "data/phenotype_index"),
                                           negativeControlConceptSetId = NULL,
                                           includeCovariateConceptSetId = NULL,
                                           excludeCovariateConceptSetId = NULL,
                                           analyticSettingsDescription = NULL,
                                           analyticSettingsDescriptionPath = NULL,
                                           incidenceOutputDir = "demo-strategus-cohort-incidence",
                                           interactive = TRUE,
                                           bannerPath = "ohdsi-logo-ascii.txt",
                                           studyAgentBaseDir = Sys.getenv("STUDY_AGENT_BASE_DIR", ""),
                                           reset = FALSE,
                                           allowCache = TRUE,
                                           promptOnCache = TRUE,
                                           resume = FALSE,
                                           remapCohortIds = TRUE,
                                           cohortIdBase = NULL) {
  `%||%` <- function(x, y) if (is.null(x)) y else x

  ensure_dir <- function(path) {
    if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }

  prompt_yesno <- function(prompt, default = TRUE) {
    if (!isTRUE(interactive)) return(default)
    suffix <- if (default) "[Y/n]" else "[y/N]"
    resp <- tolower(trimws(readline(sprintf("%s %s ", prompt, suffix))))
    if (resp == "") return(default)
    if (resp %in% c("y", "yes")) return(TRUE)
    if (resp %in% c("n", "no")) return(FALSE)
    default
  }

  maybe_use_cache <- function(path, label) {
    if (!allowCache || !file.exists(path)) return(FALSE)
    if (isTRUE(resume)) return(TRUE)
    if (!promptOnCache) return(TRUE)
    prompt_yesno(sprintf("Use cached %s at %s?", label, path), default = TRUE)
  }

  read_json <- function(path) {
    jsonlite::fromJSON(path, simplifyVector = FALSE)
  }

  write_json <- function(x, path) {
    jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, na = "null")
  }

  is_absolute_path <- function(path) {
    grepl("^(/|[A-Za-z]:[\\\\/])", path)
  }

  resolve_path <- function(path, base_dir = "") {
    if (!nzchar(path)) return(path)
    if (is_absolute_path(path)) return(path)
    if (nzchar(base_dir)) return(file.path(base_dir, path))
    path
  }

  parse_ids <- function(x) {
    if (is.null(x)) return(integer(0))
    if (is.numeric(x) || is.integer(x)) return(as.integer(x))
    if (is.character(x)) {
      pieces <- unlist(strsplit(paste(x, collapse = ","), "[,[:space:]]+"))
      pieces <- pieces[nzchar(trimws(pieces))]
      return(as.integer(pieces))
    }
    integer(0)
  }

  normalize_selected_ids <- function(value, label, allow_multiple = FALSE) {
    ids <- unique(parse_ids(value))
    ids <- as.integer(ids[!is.na(ids)])
    if (!isTRUE(allow_multiple) && length(ids) > 1) {
      stop(sprintf("%s must contain exactly one cohort ID.", label))
    }
    ids
  }

  collect_single_id <- function(value, label) {
    ids <- parse_ids(value)
    ids <- ids[!is.na(ids)]
    if (length(ids) > 1) stop(sprintf("%s must contain exactly one cohort ID.", label))
    if (length(ids) == 1) return(as.integer(ids[[1]]))
    if (!isTRUE(interactive)) stop(sprintf("Missing %s.", label))
    entered <- trimws(readline(sprintf("%s cohort ID: ", label)))
    ids <- parse_ids(entered)
    ids <- ids[!is.na(ids)]
    if (length(ids) != 1) stop(sprintf("%s must contain exactly one cohort ID.", label))
    as.integer(ids[[1]])
  }

  collect_multiple_ids <- function(value, label) {
    ids <- parse_ids(value)
    ids <- unique(ids[!is.na(ids)])
    if (length(ids) > 0) return(as.integer(ids))
    if (!isTRUE(interactive)) stop(sprintf("Missing %s.", label))
    entered <- trimws(readline(sprintf("%s cohort IDs (comma-separated): ", label)))
    ids <- parse_ids(entered)
    ids <- unique(ids[!is.na(ids)])
    if (length(ids) == 0) stop(sprintf("%s must include at least one cohort ID.", label))
    as.integer(ids)
  }

  collect_optional_single_id <- function(value, label, prompt = NULL) {
    ids <- parse_ids(value)
    ids <- unique(ids[!is.na(ids)])
    if (length(ids) > 1) stop(sprintf("%s must contain at most one ID.", label))
    if (length(ids) == 1) return(validate_positive_integer(ids[[1]], label))
    if (!isTRUE(interactive)) return(NULL)
    entered <- trimws(readline(prompt %||% sprintf("%s ID [optional]: ", label)))
    if (!nzchar(entered)) return(NULL)
    ids <- parse_ids(entered)
    ids <- unique(ids[!is.na(ids)])
    if (length(ids) != 1) stop(sprintf("%s must contain at most one ID.", label))
    validate_positive_integer(ids[[1]], label)
  }

  prompt_yesno_strict <- function(prompt, default = TRUE) {
    if (!isTRUE(interactive)) return(default)
    suffix <- if (default) "[Y/n]" else "[y/N]"
    options <- list(
      yes = c("y", "yes", "true", "t"),
      no = c("n", "no", "false", "f")
    )

    repeat {
      prompt_text <- trimws(as.character(prompt %||% ""))
      rendered_prompt <- if (nzchar(prompt_text)) sprintf("%s %s ", prompt_text, suffix) else sprintf("%s ", suffix)
      entered <- tolower(trimws(readline(rendered_prompt)))
      if (entered == "") return(default)
      if (entered %in% options$yes) return(TRUE)
      if (entered %in% options$no) return(FALSE)
      cat("Please answer with y/yes or n/no.\n")
    }
  }

  prompt_non_null_text <- function(prompt, default = NULL) {
    if (!isTRUE(interactive)) return(default)
    repeat {
      default_value <- if (is.null(default)) "" else as.character(default)
      entered <- trimws(readline(sprintf("%s [%s]: ", prompt, default_value)))
      if (entered == "" && !is.null(default)) return(default)
      if (entered == "") {
        cat("A value is required.\n")
        next
      }
      return(entered)
    }
  }

  prompt_bool <- function(prompt, default = TRUE) {
    prompt_yesno_strict(prompt, default = default)
  }

  prompt_integer <- function(prompt, default = NULL, allow_null = FALSE, must_be_positive = FALSE, allow_negative = TRUE) {
    if (!isTRUE(interactive)) {
      if (is.null(default)) return(NULL)
      if (is.na(default) && allow_null) return(NULL)
      return(as.integer(default))
    }
    prompt_suffix <- if (is.null(default)) "" else sprintf(" [%s]", default)
    repeat {
      prompt_text <- trimws(as.character(prompt %||% ""))
      rendered_prompt <- if (nzchar(prompt_text)) sprintf("%s%s: ", prompt_text, prompt_suffix) else sprintf("%s: ", prompt_suffix)
      entered <- trimws(readline(rendered_prompt))
      if (entered == "") {
        if (allow_null) return(NULL)
        if (is.null(default)) {
          cat("A value is required.\n")
          next
        }
        return(as.integer(default))
      }
      value <- suppressWarnings(as.integer(entered))
      if (is.na(value) || !is.finite(value)) {
        cat("Please enter a valid integer.\n")
        next
      }
      if (must_be_positive && value <= 0) {
        cat("Please enter a positive integer.\n")
        next
      }
      if (!allow_negative && value < 0) {
        cat("Please enter a non-negative integer.\n")
        next
      }
      return(value)
    }
  }

  prompt_numeric <- function(prompt, default = NULL, must_be_positive = TRUE) {
    if (!isTRUE(interactive)) {
      if (is.null(default)) return(NULL)
      return(as.numeric(default))
    }
    prompt_suffix <- if (is.null(default)) "" else sprintf(" [%s]", default)
    repeat {
      prompt_text <- trimws(as.character(prompt %||% ""))
      rendered_prompt <- if (nzchar(prompt_text)) sprintf("%s%s: ", prompt_text, prompt_suffix) else sprintf("%s: ", prompt_suffix)
      entered <- trimws(readline(rendered_prompt))
      if (entered == "") {
        if (is.null(default)) {
          cat("A value is required.\n")
          next
        }
        return(as.numeric(default))
      }
      value <- suppressWarnings(as.numeric(entered))
      if (is.na(value) || !is.finite(value)) {
        cat("Please enter a valid number.\n")
        next
      }
      if (must_be_positive && value <= 0) {
        cat("Please enter a positive number.\n")
        next
      }
      return(value)
    }
  }

  prompt_enum <- function(prompt, choices, default = NULL) {
    normalized_choices <- tolower(trimws(choices))
    if (!isTRUE(interactive)) {
      return(if (is.null(default)) choices[[1]] else default)
    }

    if (!is.null(default)) {
      default <- as.character(default)
      default_norm <- tolower(trimws(default))
      default <- if (default_norm %in% normalized_choices) {
        choices[[which(normalized_choices == default_norm)[1]]]
      } else {
        choices[[1]]
      }
    } else {
      default <- choices[[1]]
    }

    repeat {
      prompt_text <- trimws(as.character(prompt %||% ""))
      rendered_prompt <- if (nzchar(prompt_text)) sprintf("%s [%s]: ", prompt_text, default) else sprintf("[%s]: ", default)
      entered <- trimws(readline(rendered_prompt))
      if (entered == "") {
        return(default)
      }
      entered_norm <- tolower(trimws(entered))
      match_index <- which(normalized_choices == entered_norm)
      if (length(match_index) != 1) {
        cat(sprintf("Please enter one of: %s\n", paste(choices, collapse = ", ")))
        next
      }
      return(choices[[match_index[1]]])
    }
  }

  collect_outcome_ids <- function(value) {
    ids <- parse_ids(value)
    ids <- unique(ids[!is.na(ids)])
    if (length(ids) > 0) return(as.integer(ids))
    if (!isTRUE(interactive)) stop("Missing Outcome.")

    collected <- integer(0)
    repeat {
      entered <- trimws(readline("Outcome cohort ID: "))
      parsed <- parse_ids(entered)
      parsed <- parsed[!is.na(parsed)]
      if (length(parsed) != 1) {
        cat("Please enter exactly one outcome cohort ID.\n")
        next
      }

      outcome_id <- as.integer(parsed[[1]])
      if (outcome_id %in% collected) {
        cat(sprintf("Outcome cohort ID %s is already selected.\n", outcome_id))
      } else {
        collected <- c(collected, outcome_id)
      }

      add_another <- prompt_yesno("Add another outcome cohort id?", default = FALSE)
      if (!isTRUE(add_another)) break
    }

    if (length(collected) == 0) stop("Outcome must include at least one cohort ID.")
    as.integer(collected)
  }

  load_catalog <- function(index_dir) {
    catalog_path <- file.path(index_dir, "catalog.jsonl")
    if (!file.exists(catalog_path)) {
      return(data.frame(
        cohortId = integer(0),
        name = character(0),
        short_description = character(0),
        stringsAsFactors = FALSE
      ))
    }
    lines <- readLines(catalog_path, warn = FALSE)
    lines <- lines[nzchar(trimws(lines))]
    if (length(lines) == 0) {
      return(data.frame(
        cohortId = integer(0),
        name = character(0),
        short_description = character(0),
        stringsAsFactors = FALSE
      ))
    }
    parsed <- lapply(lines, function(line) jsonlite::fromJSON(line, simplifyVector = TRUE))
    data.frame(
      cohortId = vapply(parsed, function(x) as.integer(x$cohortId %||% NA_integer_), integer(1)),
      name = vapply(parsed, function(x) x$name %||% "", character(1)),
      short_description = vapply(parsed, function(x) x$short_description %||% "", character(1)),
      stringsAsFactors = FALSE
    )
  }

  lookup_catalog_value <- function(cohort_id, catalog_df, field = "name", fallback = NULL) {
    idx <- which(catalog_df$cohortId == as.integer(cohort_id))[1]
    if (!is.na(idx)) {
      value <- catalog_df[[field]][[idx]]
      if (!is.null(value) && nzchar(trimws(value))) return(value)
    }
    fallback %||% sprintf("Cohort %s", cohort_id)
  }

  format_cohort_selection_summary <- function(selected_ids, catalog_df) {
    ids <- as.integer(unique(selected_ids[!is.na(selected_ids)]))
    if (length(ids) == 0) return(NULL)
    labels <- vapply(ids, function(id) {
      sprintf(
        "%s (ID %s)",
        lookup_catalog_value(id, catalog_df, "name", sprintf("Cohort %s", id)),
        id
      )
    }, character(1))
    paste(labels, collapse = ", ")
  }

  cache_label_with_selection <- function(label, selected_ids, catalog_df) {
    selection_summary <- format_cohort_selection_summary(selected_ids, catalog_df)
    if (is.null(selection_summary) || !nzchar(trimws(selection_summary))) return(label)
    sprintf("%s [%s]", label, selection_summary)
  }

  load_cached_role_selection <- function(map_path, role, role_dir) {
    if (!file.exists(map_path) || !dir.exists(role_dir)) return(NULL)
    payload <- tryCatch(read_json(map_path), error = function(e) NULL)
    if (is.null(payload)) return(NULL)
    mapping <- payload$mapping %||% payload
    is_row_mapping <- is.list(mapping) &&
      length(mapping) > 0 &&
      is.list(mapping[[1]]) &&
      any(names(mapping[[1]]) %in% c("role", "original_id", "cohort_id"))
    if (isTRUE(is_row_mapping)) {
      roles <- vapply(mapping, function(item) as.character(item$role %||% NA_character_), character(1))
      original_ids <- vapply(mapping, function(item) as.integer(item$original_id %||% NA_integer_), integer(1))
      cohort_ids <- vapply(mapping, function(item) as.integer(item$cohort_id %||% NA_integer_), integer(1))
    } else {
      roles <- as.character(unlist(mapping$role %||% character(0), use.names = FALSE))
      original_ids <- as.integer(unlist(mapping$original_id %||% integer(0), use.names = FALSE))
      cohort_ids <- as.integer(unlist(mapping$cohort_id %||% integer(0), use.names = FALSE))
    }
    if (!length(roles) || length(roles) != length(original_ids) || length(roles) != length(cohort_ids)) {
      return(NULL)
    }
    keep <- which(roles == role & !is.na(original_ids) & !is.na(cohort_ids))
    if (length(keep) == 0) return(NULL)
    selected_ids <- as.integer(unique(original_ids[keep]))
    new_ids <- as.integer(cohort_ids[keep])
    cached_files <- file.path(role_dir, sprintf("%s.json", new_ids))
    if (!all(file.exists(cached_files))) return(NULL)
    list(selected_ids = selected_ids, new_ids = new_ids)
  }

  prompt_statement <- function(label, default = NULL) {
    if (!isTRUE(interactive)) return(default)
    default_value <- trimws(as.character(default %||% ""))
    entered <- readline(sprintf("%s statement [%s]: ", label, default_value))
    if (nzchar(trimws(entered))) trimws(entered) else default_value
  }

  ensure_acp_ready <- function(url) {
    has_acp_state <- exists("acp_state", inherits = TRUE)
    has_acp_connect <- exists("acp_connect", mode = "function", inherits = TRUE)
    has_acp_post <- exists(".acp_post", mode = "function", inherits = TRUE)
    if (!has_acp_state || !has_acp_connect || !has_acp_post) return(FALSE)
    acp_state_value <- get("acp_state", inherits = TRUE)
    if (!is.null(acp_state_value$url)) return(TRUE)
    if (is.null(url) || !nzchar(trimws(url))) return(FALSE)
    tryCatch({
      acp_connect(url)
      TRUE
    }, error = function(e) {
      FALSE
    })
  }

  collect_recommendation_selection <- function(recommendations, role_label, allow_multiple = FALSE) {
    if (length(recommendations) == 0) return(integer(0))
    if (!isTRUE(interactive)) {
      if (isTRUE(allow_multiple)) {
        return(as.integer(vapply(recommendations, function(rec) rec$cohortId %||% NA_integer_, integer(1))))
      }
      return(as.integer(recommendations[[1]]$cohortId %||% NA_integer_))
    }

    labels <- vapply(seq_along(recommendations), function(i) {
      rec <- recommendations[[i]]
      sprintf("%s (ID %s)", rec$cohortName %||% "<unknown>", rec$cohortId %||% "?")
    }, character(1))
    picks <- utils::select.list(
      labels,
      multiple = isTRUE(allow_multiple),
      title = sprintf("Select %s phenotype%s", tolower(role_label), if (isTRUE(allow_multiple)) "s" else "")
    )
    if (!length(picks) || !any(nzchar(picks))) return(integer(0))
    selected_ids <- vapply(picks, function(label) {
      idx <- which(labels == label)[1]
      recommendations[[idx]]$cohortId %||% NA_integer_
    }, numeric(1))
    as.integer(selected_ids[!is.na(selected_ids)])
  }

  run_role_recommendation <- function(role_label,
                                      statement,
                                      output_path,
                                      top_k,
                                      max_results,
                                      candidate_limit,
                                      allow_multiple = FALSE,
                                      preferred_selected_ids = NULL,
                                      preferred_selection_source = "manual_input",
                                      cached_selected_ids = NULL,
                                      selected_cache_label = NULL,
                                      selected_cache_dir = NULL,
                                      cohort_method_cache = NULL,
                                      incidence_cache = NULL) {
    role_key <- tolower(role_label)
    preferred_selected_ids <- normalize_selected_ids(
      preferred_selected_ids,
      sprintf("%s cohort ID%s", role_label, if (isTRUE(allow_multiple)) "s" else ""),
      allow_multiple = allow_multiple
    )
    if (length(preferred_selected_ids) > 0) {
      return(list(
        selected_ids = preferred_selected_ids,
        selection_source = preferred_selection_source %||% "manual_input",
        recommendation_path = json_string_or_null(if (file.exists(output_path)) output_path else NULL),
        recommendation_source = "not_run",
        used_cached_recommendation = FALSE,
        used_cached_selection = FALSE,
        used_window2 = FALSE,
        used_advice = FALSE,
        statement = statement
      ))
    }
    selected_cache_ok <- !is.null(cohort_method_cache$selection$selected_ids) &&
      length(cohort_method_cache$selection$selected_ids) > 0 &&
      !is.null(cohort_method_cache$selection$cache_dir) &&
      dir.exists(cohort_method_cache$selection$cache_dir)
    if (isTRUE(selected_cache_ok)) {
      cached_selected_ids <- as.integer(unique(cohort_method_cache$selection$selected_ids))
      if (maybe_use_cache(
        cohort_method_cache$selection$cache_dir,
        cache_label_with_selection(
          selected_cache_label %||% sprintf("%s cohort selection", role_key),
          cached_selected_ids,
          catalog_df
        )
      )) {
        return(list(
          selected_ids = cached_selected_ids,
          selection_source = "cohort_method_cached_selected_cohort",
          recommendation_path = json_string_or_null(if (file.exists(output_path)) output_path else NULL),
          recommendation_source = if (file.exists(output_path)) "cached_recommendation" else "cached_selected_cohort_only",
          used_cached_recommendation = FALSE,
          used_cached_selection = TRUE,
          used_window2 = FALSE,
          used_advice = FALSE,
          statement = statement
        ))
      }
    }
    incidence_cache_ok <- !is.null(incidence_cache$selection$selected_ids) &&
      length(incidence_cache$selection$selected_ids) > 0 &&
      !is.null(incidence_cache$selection$cache_dir) &&
      dir.exists(incidence_cache$selection$cache_dir)
    if (!isTRUE(selected_cache_ok) && isTRUE(incidence_cache_ok)) {
      incidence_selected_ids <- as.integer(unique(incidence_cache$selection$selected_ids))
      if (maybe_use_cache(
        incidence_cache$selection$cache_dir,
        cache_label_with_selection(
          incidence_cache$selection$label %||% sprintf("incidence %s cohort selection", role_key),
          incidence_selected_ids,
          catalog_df
        )
      )) {
        return(list(
          selected_ids = incidence_selected_ids,
          selection_source = "incidence_cached_selected_cohort",
          recommendation_path = json_string_or_null(if (file.exists(output_path)) output_path else NULL),
          recommendation_source = "incidence_cached_selected_cohort_only",
          used_cached_recommendation = FALSE,
          used_cached_selection = TRUE,
          used_window2 = FALSE,
          used_advice = FALSE,
          statement = statement
        ))
      }
    }

    recommendation_response <- NULL
    recommendation_path <- output_path
    used_cached_recommendation <- FALSE
    used_window2 <- FALSE
    used_advice <- FALSE

    if (maybe_use_cache(output_path, sprintf("%s recommendations", role_key))) {
      recommendation_response <- read_json(output_path)
      used_cached_recommendation <- TRUE
    } else if (ensure_acp_ready(acpUrl)) {
      body <- list(
        study_intent = statement,
        top_k = top_k,
        max_results = max_results,
        candidate_limit = candidate_limit
      )
      message(sprintf("Calling ACP flow: phenotype_recommendation (%s)", role_key))
      recommendation_response <- tryCatch(
        .acp_post("/flows/phenotype_recommendation", body),
        error = function(e) {
          list(status = "error", error = conditionMessage(e))
        }
      )
      write_json(recommendation_response, output_path)
    }

    recommendations_core <- recommendation_response$recommendations %||% recommendation_response
    recommendations <- recommendations_core$phenotype_recommendations %||% list()

    if (isTRUE(interactive) && length(recommendations) > 0) {
      cat(sprintf("\n== %s Phenotype Recommendations ==\n", role_label))
      for (i in seq_along(recommendations)) {
        rec <- recommendations[[i]]
        cat(sprintf("%d. %s (ID %s)\n", i, rec$cohortName %||% "<unknown>", rec$cohortId %||% "?"))
        if (!is.null(rec$justification)) cat(sprintf("   %s\n", rec$justification))
      }
      ok_any <- prompt_yesno(sprintf("Are any of these acceptable for the %s?", role_key), default = TRUE)
      if (!ok_any && ensure_acp_ready(acpUrl)) {
        widen <- prompt_yesno("Widen candidate pool and try again?", default = TRUE)
        if (isTRUE(widen)) {
          used_window2 <- TRUE
          recommendation_path <- file.path(dirname(output_path), sprintf("%s_window2.json", tools::file_path_sans_ext(basename(output_path))))
          body <- list(
            study_intent = statement,
            top_k = top_k,
            max_results = max_results,
            candidate_limit = candidate_limit,
            candidate_offset = candidate_limit
          )
          message(sprintf("Calling ACP flow: phenotype_recommendation (%s window 2)", role_key))
          recommendation_response <- tryCatch(
            .acp_post("/flows/phenotype_recommendation", body),
            error = function(e) {
              list(status = "error", error = conditionMessage(e))
            }
          )
          write_json(recommendation_response, recommendation_path)
          recommendations_core <- recommendation_response$recommendations %||% recommendation_response
          recommendations <- recommendations_core$phenotype_recommendations %||% list()
          cat(sprintf("\n== %s Phenotype Recommendations (window 2) ==\n", role_label))
          for (i in seq_along(recommendations)) {
            rec <- recommendations[[i]]
            cat(sprintf("%d. %s (ID %s)\n", i, rec$cohortName %||% "<unknown>", rec$cohortId %||% "?"))
            if (!is.null(rec$justification)) cat(sprintf("   %s\n", rec$justification))
          }
          ok_any <- prompt_yesno(sprintf("Are any of these acceptable for the %s?", role_key), default = TRUE)
        }
        if (!ok_any) {
          used_advice <- TRUE
          message(sprintf("Calling ACP flow: phenotype_recommendation_advice (%s)", role_key))
          advice <- tryCatch(
            .acp_post("/flows/phenotype_recommendation_advice", list(study_intent = statement)),
            error = function(e) {
              list(status = "error", error = conditionMessage(e))
            }
          )
          advice_core <- advice$advice %||% advice
          cat("\n== Advisory guidance ==\n")
          cat(advice_core$advice %||% "", "\n")
          if (length(advice_core$next_steps %||% list()) > 0) {
            cat("Next steps:\n")
            for (step in advice_core$next_steps) cat(sprintf("  - %s\n", step))
          }
          recommendations <- list()
        }
      }
    }

    selected_ids <- collect_recommendation_selection(recommendations, role_label, allow_multiple = allow_multiple)
    selected_ids <- as.integer(unique(selected_ids[!is.na(selected_ids)]))

    list(
      selected_ids = selected_ids,
      selection_source = if (length(selected_ids) > 0) "recommendation" else "none",
      recommendation_path = json_string_or_null(if (file.exists(recommendation_path)) recommendation_path else NULL),
      recommendation_source = if (used_cached_recommendation) "cached_recommendation" else if (!is.null(recommendation_response)) "acp_flow" else "not_run",
      used_cached_recommendation = isTRUE(used_cached_recommendation),
      used_cached_selection = FALSE,
      used_window2 = isTRUE(used_window2),
      used_advice = isTRUE(used_advice),
      statement = statement
    )
  }

  copy_cohort_json_multi <- function(source_id, dest_id, dest_dirs, index_def_dir) {
    src <- file.path(index_def_dir, sprintf("%s.json", source_id))
    if (!file.exists(src)) stop(sprintf("Cohort JSON not found: %s", src))
    dests <- character(0)
    for (dest_dir in dest_dirs) {
      ensure_dir(dest_dir)
      dest <- file.path(dest_dir, sprintf("%s.json", dest_id))
      file.copy(src, dest, overwrite = TRUE)
      dests <- c(dests, dest)
    }
    dests
  }

  write_lines <- function(path, lines) {
    writeLines(lines, con = path, useBytes = TRUE)
  }

  assert_cohort_json_exists <- function(source_id, index_def_dir, label) {
    src <- file.path(index_def_dir, sprintf("%s.json", source_id))
    if (!file.exists(src)) {
      stop(sprintf("%s cohort JSON not found: %s", label, src))
    }
    invisible(src)
  }

  cohort_json_exists <- function(source_id, index_def_dir) {
    src <- file.path(index_def_dir, sprintf("%s.json", source_id))
    file.exists(src)
  }

  validate_positive_integer <- function(value, label) {
    if (length(value) != 1 || is.na(value) || !is.finite(value) || value <= 0) {
      stop(sprintf("%s must be a positive integer.", label))
    }
    as.integer(value)
  }

  json_int_or_null <- function(value) {
    if (is.null(value)) return(NA_integer_)
    as.integer(value)
  }

  json_string_or_null <- function(value) {
    if (is.null(value)) return(NA_character_)
    as.character(value)
  }

  deep_merge <- function(defaults, overrides) {
    if (is.null(overrides)) return(defaults)
    for (name in names(overrides)) {
      override_value <- overrides[[name]]
      default_value <- defaults[[name]]
      if (is.list(default_value) && is.list(override_value) && !is.data.frame(override_value)) {
        defaults[[name]] <- deep_merge(default_value, override_value)
      } else if (!is.null(override_value)) {
        defaults[[name]] <- override_value
      }
    }
    defaults
  }

  validate_choice <- function(value, choices, label) {
    if (length(value) != 1 || is.na(value) || !value %in% choices) {
      stop(sprintf("%s must be one of: %s", label, paste(choices, collapse = ", ")))
    }
    as.character(value)
  }

  validate_integer_value <- function(value, label, min_value = NULL) {
    parsed <- suppressWarnings(as.integer(value))
    if (length(parsed) != 1 || is.na(parsed) || !is.finite(parsed)) {
      stop(sprintf("%s must be an integer.", label))
    }
    if (!is.null(min_value) && parsed < min_value) {
      stop(sprintf("%s must be >= %s.", label, min_value))
    }
    as.integer(parsed)
  }

  validate_numeric_value <- function(value, label, min_value = NULL) {
    parsed <- suppressWarnings(as.numeric(value))
    if (length(parsed) != 1 || is.na(parsed) || !is.finite(parsed)) {
      stop(sprintf("%s must be numeric.", label))
    }
    if (!is.null(min_value) && parsed < min_value) {
      stop(sprintf("%s must be >= %s.", label, min_value))
    }
    parsed
  }

  validate_logical_value <- function(value, label) {
    if (length(value) != 1 || is.na(value) || !is.logical(value)) {
      stop(sprintf("%s must be TRUE or FALSE.", label))
    }
    isTRUE(value)
  }

  normalize_analytic_settings <- function(settings) {
    validate_date_or_blank <- function(value, label) {
      .studyAgentDateStringOrEmpty(value, label)
    }

    allowed_sections <- c(
      "study_population",
      "covariate_settings",
      "time_at_risk",
      "propensity_score_adjustment",
      "outcome_model"
    )
    section_aliases <- c(covariates = "covariate_settings")

    profile_name <- trimws(as.character(settings$profile_name %||% ""))
    if (!nzchar(profile_name)) {
      stop("analytic_settings.profile_name must be a non-empty string.")
    }

    customized_sections <- as.character(unlist(settings$customized_sections %||% character(0), use.names = FALSE))
    aliased_sections <- unname(section_aliases[customized_sections])
    customized_sections <- ifelse(is.na(aliased_sections), customized_sections, aliased_sections)
    customized_sections <- unique(customized_sections[nzchar(customized_sections)])
    invalid_sections <- setdiff(customized_sections, allowed_sections)
    if (length(invalid_sections) > 0) {
      stop(sprintf(
        "analytic_settings.customized_sections contains unsupported values: %s",
        paste(invalid_sections, collapse = ", ")
      ))
    }

    settings$profile_name <- profile_name
    settings$source <- "manual_shell"
    settings$customized_sections <- customized_sections
    settings$get_db_cohort_method_data$studyStartDate <- validate_date_or_blank(
      settings$get_db_cohort_method_data$studyStartDate,
      "analytic_settings.get_db_cohort_method_data.studyStartDate"
    )
    settings$get_db_cohort_method_data$studyEndDate <- validate_date_or_blank(
      settings$get_db_cohort_method_data$studyEndDate,
      "analytic_settings.get_db_cohort_method_data.studyEndDate"
    )
    settings$get_db_cohort_method_data$firstExposureOnly <- validate_logical_value(
      settings$get_db_cohort_method_data$firstExposureOnly,
      "analytic_settings.get_db_cohort_method_data.firstExposureOnly"
    )
    settings$get_db_cohort_method_data$washoutPeriod <- validate_integer_value(
      settings$get_db_cohort_method_data$washoutPeriod,
      "analytic_settings.get_db_cohort_method_data.washoutPeriod",
      min_value = 0L
    )
    settings$get_db_cohort_method_data$restrictToCommonPeriod <- validate_logical_value(
      settings$get_db_cohort_method_data$restrictToCommonPeriod,
      "analytic_settings.get_db_cohort_method_data.restrictToCommonPeriod"
    )
    settings$get_db_cohort_method_data$removeDuplicateSubjects <- validate_choice(
      settings$get_db_cohort_method_data$removeDuplicateSubjects,
      c("keep all", "keep first", "remove all", "keep first, truncate to second"),
      "analytic_settings.get_db_cohort_method_data.removeDuplicateSubjects"
    )
    settings$create_study_population$removeDuplicateSubjects <- validate_choice(
      settings$create_study_population$removeDuplicateSubjects,
      c("keep all", "keep first", "remove all"),
      "analytic_settings.create_study_population.removeDuplicateSubjects"
    )
    settings$create_study_population$maxCohortSize <- validate_integer_value(
      settings$create_study_population$maxCohortSize,
      "analytic_settings.create_study_population.maxCohortSize",
      min_value = 0L
    )
    settings$create_study_population$removeSubjectsWithPriorOutcome <- validate_logical_value(
      settings$create_study_population$removeSubjectsWithPriorOutcome,
      "analytic_settings.create_study_population.removeSubjectsWithPriorOutcome"
    )
    settings$create_study_population$priorOutcomeLookback <- validate_integer_value(
      settings$create_study_population$priorOutcomeLookback,
      "analytic_settings.create_study_population.priorOutcomeLookback",
      min_value = 0L
    )
    settings$create_study_population$minDaysAtRisk <- validate_integer_value(
      settings$create_study_population$minDaysAtRisk,
      "analytic_settings.create_study_population.minDaysAtRisk",
      min_value = 0L
    )
    settings$create_study_population$riskWindowStart <- validate_integer_value(
      settings$create_study_population$riskWindowStart,
      "analytic_settings.create_study_population.riskWindowStart"
    )
    settings$create_study_population$startAnchor <- validate_choice(
      settings$create_study_population$startAnchor,
      c("cohort start", "cohort end"),
      "analytic_settings.create_study_population.startAnchor"
    )
    settings$create_study_population$riskWindowEnd <- validate_integer_value(
      settings$create_study_population$riskWindowEnd,
      "analytic_settings.create_study_population.riskWindowEnd"
    )
    settings$create_study_population$endAnchor <- validate_choice(
      settings$create_study_population$endAnchor,
      c("cohort start", "cohort end"),
      "analytic_settings.create_study_population.endAnchor"
    )
    settings$create_study_population$censorAtNewRiskWindow <- validate_logical_value(
      settings$create_study_population$censorAtNewRiskWindow,
      "analytic_settings.create_study_population.censorAtNewRiskWindow"
    )
    settings$create_ps$estimator <- validate_choice(
      settings$create_ps$estimator,
      c("att", "ate"),
      "analytic_settings.create_ps.estimator"
    )
    settings$create_ps$maxCohortSizeForFitting <- validate_integer_value(
      settings$create_ps$maxCohortSizeForFitting,
      "analytic_settings.create_ps.maxCohortSizeForFitting",
      min_value = 0L
    )
    settings$create_ps$errorOnHighCorrelation <- validate_logical_value(
      settings$create_ps$errorOnHighCorrelation,
      "analytic_settings.create_ps.errorOnHighCorrelation"
    )
    settings$create_ps$useRegularization <- validate_logical_value(
      settings$create_ps$useRegularization,
      "analytic_settings.create_ps.useRegularization"
    )
    settings$match_on_ps$caliper <- validate_numeric_value(
      settings$match_on_ps$caliper,
      "analytic_settings.match_on_ps.caliper",
      min_value = 0
    )
    settings$match_on_ps$caliperScale <- validate_choice(
      settings$match_on_ps$caliperScale,
      c("propensity score", "standardized", "standardized logit"),
      "analytic_settings.match_on_ps.caliperScale"
    )
    settings$match_on_ps$maxRatio <- validate_integer_value(
      settings$match_on_ps$maxRatio,
      "analytic_settings.match_on_ps.maxRatio",
      min_value = 0L
    )
    settings$ps_adjustment$strategy <- validate_choice(
      settings$ps_adjustment$strategy,
      c("match_on_ps", "stratify_by_ps", "none"),
      "analytic_settings.ps_adjustment.strategy"
    )
    settings$ps_adjustment$trimmingStrategy <- validate_choice(
      settings$ps_adjustment$trimmingStrategy,
      c("none", "by_percent", "by_equipoise"),
      "analytic_settings.ps_adjustment.trimmingStrategy"
    )
    settings$ps_adjustment$trimmingPercent <- validate_numeric_value(
      settings$ps_adjustment$trimmingPercent,
      "analytic_settings.ps_adjustment.trimmingPercent",
      min_value = 0
    )
    if (settings$ps_adjustment$trimmingPercent >= 50) {
      stop("analytic_settings.ps_adjustment.trimmingPercent must be < 50.")
    }
    settings$ps_adjustment$equipoiseLowerBound <- validate_numeric_value(
      settings$ps_adjustment$equipoiseLowerBound,
      "analytic_settings.ps_adjustment.equipoiseLowerBound",
      min_value = 0
    )
    settings$ps_adjustment$equipoiseUpperBound <- validate_numeric_value(
      settings$ps_adjustment$equipoiseUpperBound,
      "analytic_settings.ps_adjustment.equipoiseUpperBound",
      min_value = 0
    )
    if (settings$ps_adjustment$equipoiseLowerBound >= settings$ps_adjustment$equipoiseUpperBound ||
        settings$ps_adjustment$equipoiseUpperBound > 1) {
      stop("analytic_settings.ps_adjustment equipoise bounds must satisfy 0 <= lower < upper <= 1.")
    }
    settings$stratify_by_ps$numberOfStrata <- validate_integer_value(
      settings$stratify_by_ps$numberOfStrata,
      "analytic_settings.stratify_by_ps.numberOfStrata",
      min_value = 1L
    )
    settings$stratify_by_ps$baseSelection <- validate_choice(
      settings$stratify_by_ps$baseSelection,
      c("all", "target", "comparator"),
      "analytic_settings.stratify_by_ps.baseSelection"
    )
    settings$fit_outcome_model$modelType <- validate_choice(
      settings$fit_outcome_model$modelType,
      c("cox", "logistic", "poisson"),
      "analytic_settings.fit_outcome_model.modelType"
    )
    settings$fit_outcome_model$stratified <- validate_logical_value(
      settings$fit_outcome_model$stratified,
      "analytic_settings.fit_outcome_model.stratified"
    )
    settings$fit_outcome_model$useCovariates <- validate_logical_value(
      settings$fit_outcome_model$useCovariates,
      "analytic_settings.fit_outcome_model.useCovariates"
    )
    settings$fit_outcome_model$inversePtWeighting <- validate_logical_value(
      settings$fit_outcome_model$inversePtWeighting,
      "analytic_settings.fit_outcome_model.inversePtWeighting"
    )
    settings$fit_outcome_model$useRegularization <- validate_logical_value(
      settings$fit_outcome_model$useRegularization,
      "analytic_settings.fit_outcome_model.useRegularization"
    )
    settings$covariate_concept_sets$enabled <- validate_logical_value(
      settings$covariate_concept_sets$enabled,
      "analytic_settings.covariate_concept_sets.enabled"
    )
    settings$covariate_concept_sets$include_all_concepts <- validate_logical_value(
      settings$covariate_concept_sets$include_all_concepts,
      "analytic_settings.covariate_concept_sets.include_all_concepts"
    )

    include_id <- settings$covariate_concept_sets$include_concept_set_id
    exclude_id <- settings$covariate_concept_sets$exclude_concept_set_id
    settings$covariate_concept_sets$include_concept_set_id <- if (is.null(include_id) || length(include_id) == 0 || is.na(include_id)) {
      NA_integer_
    } else {
      validate_positive_integer(include_id, "analytic_settings.covariate_concept_sets.include_concept_set_id")
    }
    settings$covariate_concept_sets$exclude_concept_set_id <- if (is.null(exclude_id) || length(exclude_id) == 0 || is.na(exclude_id)) {
      NA_integer_
    } else {
      validate_positive_integer(exclude_id, "analytic_settings.covariate_concept_sets.exclude_concept_set_id")
    }

    settings
  }

  collect_text_value <- function(value, prompt, default = "") {
    current <- value %||% default
    if (!isTRUE(interactive)) return(current)
    entered <- readline(sprintf("%s [%s]: ", prompt, current))
    if (nzchar(trimws(entered))) entered else current
  }

  collect_choice_value <- function(value, label, choices, prompt = NULL, default = NULL) {
    current <- value %||% default %||% choices[[1]]
    if (!current %in% choices) current <- default %||% choices[[1]]
    if (!isTRUE(interactive)) return(current)

    cat(sprintf("%s\n", prompt %||% label))
    for (i in seq_along(choices)) {
      marker <- if (identical(choices[[i]], current)) " [default]" else ""
      cat(sprintf("  %s. %s%s\n", i, choices[[i]], marker))
    }

    repeat {
      entered <- trimws(readline(sprintf("Select option [%s]: ", match(current, choices))))
      if (!nzchar(entered)) return(current)
      option_idx <- suppressWarnings(as.integer(entered))
      if (!is.na(option_idx) && option_idx >= 1 && option_idx <= length(choices)) {
        return(choices[[option_idx]])
      }
      if (entered %in% choices) return(entered)
      cat(sprintf("Please enter one of: %s\n", paste(seq_along(choices), collapse = ", ")))
    }
  }

  collect_integer_value <- function(value, label, prompt, default = NULL, min_value = NULL) {
    current <- value %||% default
    current <- validate_integer_value(current, label, min_value = min_value)
    if (!isTRUE(interactive)) return(current)

    repeat {
      entered <- trimws(readline(sprintf("%s [%s]: ", prompt, current)))
      if (!nzchar(entered)) return(current)
      parsed <- suppressWarnings(as.integer(entered))
      if (!is.na(parsed) && (is.null(min_value) || parsed >= min_value)) {
        return(as.integer(parsed))
      }
      if (is.null(min_value)) {
        cat(sprintf("%s must be an integer.\n", label))
      } else {
        cat(sprintf("%s must be an integer >= %s.\n", label, min_value))
      }
    }
  }

  collect_numeric_value <- function(value, label, prompt, default = NULL, min_value = NULL) {
    current <- value %||% default
    current <- validate_numeric_value(current, label, min_value = min_value)
    if (!isTRUE(interactive)) return(current)

    repeat {
      entered <- trimws(readline(sprintf("%s [%s]: ", prompt, format(current, trim = TRUE, scientific = FALSE))))
      if (!nzchar(entered)) return(current)
      parsed <- suppressWarnings(as.numeric(entered))
      if (!is.na(parsed) && (is.null(min_value) || parsed >= min_value)) {
        return(parsed)
      }
      if (is.null(min_value)) {
        cat(sprintf("%s must be numeric.\n", label))
      } else {
        cat(sprintf("%s must be numeric >= %s.\n", label, min_value))
      }
    }
  }

  flatten_named_values <- function(x, prefix = NULL) {
    if (is.list(x) && !is.data.frame(x)) {
      pieces <- unlist(
        lapply(names(x), function(name) {
          key <- if (is.null(prefix) || !nzchar(prefix)) name else paste(prefix, name, sep = ".")
          flatten_named_values(x[[name]], key)
        }),
        recursive = FALSE,
        use.names = FALSE
      )
      return(pieces)
    }

    value <- if (length(x) == 0 || all(is.na(x))) {
      "null"
    } else if (length(x) > 1) {
      paste(as.character(x), collapse = ", ")
    } else {
      as.character(x)
    }

    stats::setNames(list(value), prefix %||% "value")
  }

  build_dummy_analytic_settings_recommendation <- function(description, defaults_snapshot, input_method = "typed_text") {
    list(
      mode = "free_text",
      input_method = input_method,
      source = "manual_shell",
      status = "dummy_generated",
      profile_name = "Recommended from free-text description",
      raw_description = description,
      study_population = "TODO: derive study population settings from free-text description",
      time_at_risk = "TODO: derive time-at-risk settings from free-text description",
      propensity_score_adjustment = "TODO: derive propensity score adjustment settings from free-text description",
      outcome_model = "TODO: derive outcome model settings from free-text description",
      deferred_inputs = list(
        function_argument_description = "implemented",
        description_file_path = "implemented",
        interactive_typed_description = "implemented"
      ),
      defaults_snapshot = defaults_snapshot
    )
  }

  call_cohort_methods_specifications_recommendation <- function(acp_url,
                                                                body,
                                                                defaults_snapshot,
                                                                input_method = "typed_text") {
    flow_name <- "cohort_methods_specifications_recommendation"
    dummy_recommendation <- build_dummy_analytic_settings_recommendation(
      description = body$analytic_settings_description %||% body$study_description %||% "",
      defaults_snapshot = defaults_snapshot,
      input_method = input_method
    )

    ensure_connected <- function(url) {
      has_acp_state <- exists("acp_state", inherits = TRUE)
      has_acp_connect <- exists("acp_connect", mode = "function", inherits = TRUE)
      if (!has_acp_state || !has_acp_connect) return(FALSE)
      if (!is.null(get("acp_state", inherits = TRUE)$url)) return(TRUE)
      if (is.null(url) || !nzchar(trimws(url))) return(FALSE)
      tryCatch({
        acp_connect(url)
        TRUE
      }, error = function(e) {
        FALSE
      })
    }

    use_acp <- ensure_connected(acp_url)
    has_acp_post <- exists(".acp_post", mode = "function", inherits = TRUE)
    if (!isTRUE(use_acp) || !has_acp_post) {
      return(list(
        flow = flow_name,
        source = "stub_acp_placeholder",
        status = "stub",
        message = "ACP bridge unavailable, ACP helpers not loaded, or ACP not connected. Returning placeholder cohort methods specifications recommendation.",
        request = body,
        recommendation = dummy_recommendation
      ))
    }

    response <- tryCatch(
      .acp_post(sprintf("/flows/%s", flow_name), body),
      error = function(e) {
        list(
          flow = flow_name,
          source = "stub_acp_placeholder",
          status = "stub",
          error = conditionMessage(e),
          message = "ACP flow failed or is not yet implemented. Returning placeholder cohort methods specifications recommendation.",
          request = body,
          recommendation = dummy_recommendation
        )
      }
    )

    if (is.list(response) && identical(response$source, "stub_acp_placeholder")) {
      return(response)
    }

    recommendation <- response$recommendation %||%
      response$recommendations %||%
      response$cohort_methods_specifications_recommendation %||%
      dummy_recommendation
    if (!is.list(recommendation)) recommendation <- dummy_recommendation

    list(
      flow = flow_name,
      source = "acp_flow",
      status = "received",
      request = body,
      response = response,
      recommendation = recommendation
    )
  }

  study_base_dir <- ""
  if (nzchar(studyAgentBaseDir)) {
    study_base_dir <- normalizePath(studyAgentBaseDir, winslash = "/", mustWork = FALSE)
  }

  if (!is.null(analyticSettingsDescription)) {
    analyticSettingsDescription <- trimws(as.character(analyticSettingsDescription))
    if (!nzchar(analyticSettingsDescription)) analyticSettingsDescription <- NULL
  }
  if (!is.null(analyticSettingsDescriptionPath)) {
    analyticSettingsDescriptionPath <- trimws(as.character(analyticSettingsDescriptionPath))
    if (!nzchar(analyticSettingsDescriptionPath)) analyticSettingsDescriptionPath <- NULL
  }

  outputDir <- resolve_path(outputDir, study_base_dir)
  outputDir <- normalizePath(outputDir, winslash = "/", mustWork = FALSE)
  if (isTRUE(reset) && dir.exists(outputDir)) {
    ok <- TRUE
    if (isTRUE(interactive)) {
      ok <- prompt_yesno(sprintf("Delete existing output directory %s?", outputDir), default = FALSE)
    }
    if (ok) unlink(outputDir, recursive = TRUE, force = TRUE)
  }

  base_dir <- outputDir
  incidence_base_dir <- resolve_path(incidenceOutputDir, study_base_dir)
  incidence_base_dir <- normalizePath(incidence_base_dir, winslash = "/", mustWork = FALSE)
  index_dir <- resolve_path(indexDir, study_base_dir)
  index_dir <- normalizePath(index_dir, winslash = "/", mustWork = FALSE)
  catalog_df <- load_catalog(index_dir)
  analytic_settings_description_path_resolved <- if (is.null(analyticSettingsDescriptionPath)) {
    NULL
  } else {
    normalizePath(resolve_path(analyticSettingsDescriptionPath, study_base_dir), winslash = "/", mustWork = FALSE)
  }
  if (!dir.exists(index_dir) && !is_absolute_path(indexDir) && !nzchar(studyAgentBaseDir)) {
    alt <- file.path(getwd(), "OHDSI-Study-Agent", indexDir)
    if (dir.exists(alt)) index_dir <- normalizePath(alt, winslash = "/", mustWork = FALSE)
  }
  index_def_dir <- file.path(index_dir, "definitions")
  if (!dir.exists(index_def_dir)) stop(sprintf("Missing phenotype index definitions folder: %s", index_def_dir))

  output_dir <- file.path(base_dir, "outputs")
  selected_dir <- file.path(base_dir, "selected-cohorts")
  patched_dir <- file.path(base_dir, "patched-cohorts")
  selected_target_dir <- file.path(base_dir, "selected-target-cohorts")
  selected_comparator_dir <- file.path(base_dir, "selected-comparator-cohorts")
  selected_outcome_dir <- file.path(base_dir, "selected-outcome-cohorts")
  patched_target_dir <- file.path(base_dir, "patched-target-cohorts")
  patched_comparator_dir <- file.path(base_dir, "patched-comparator-cohorts")
  patched_outcome_dir <- file.path(base_dir, "patched-outcome-cohorts")
  concept_sets_dir <- file.path(base_dir, "concept-sets")
  keeper_dir <- file.path(base_dir, "keeper-case-review")
  analysis_settings_dir <- file.path(base_dir, "analysis-settings")
  scripts_dir <- file.path(base_dir, "scripts")
  cm_results_dir <- file.path(base_dir, "cm-results")
  cm_diagnostics_dir <- file.path(base_dir, "cm-diagnostics")
  cm_data_dir <- file.path(base_dir, "cm-data")

  dirs <- c(
    output_dir, selected_dir, patched_dir, selected_target_dir, selected_comparator_dir,
    selected_outcome_dir, patched_target_dir, patched_comparator_dir, patched_outcome_dir,
    concept_sets_dir,
    keeper_dir, analysis_settings_dir, scripts_dir, cm_results_dir, cm_diagnostics_dir,
    cm_data_dir
  )
  for (dir_path in dirs) ensure_dir(dir_path)

  manual_intent_path <- file.path(output_dir, "manual_intent.json")
  manual_inputs_path <- file.path(output_dir, "manual_inputs.json")
  cohort_roles_path <- file.path(output_dir, "cohort_roles.json")
  cohort_id_map_path <- file.path(output_dir, "cohort_id_map.json")
  incidence_cohort_id_map_path <- file.path(incidence_base_dir, "outputs", "cohort_id_map.json")
  incidence_selected_target_dir <- file.path(incidence_base_dir, "selected-target-cohorts")
  incidence_selected_outcome_dir <- file.path(incidence_base_dir, "selected-outcome-cohorts")
  cm_comparisons_path <- file.path(output_dir, "cm_comparisons.json")
  improvements_status_path <- file.path(output_dir, "improvements_status.json")
  cm_evaluation_todo_path <- file.path(output_dir, "cm_evaluation_todo.json")
  acp_mcp_todo_path <- file.path(output_dir, "acp_mcp_todo.json")
  cm_defaults_path <- file.path(output_dir, "cm_analysis_defaults.json")
  cm_analysis_json_path <- file.path(analysis_settings_dir, "cmAnalysis.json")
  cm_analysis_template_path <- system.file("templates", "cmAnalysis_template.json", package = "OHDSIAssistant")
  if (!nzchar(cm_analysis_template_path)) {
    cm_analysis_template_path <- resolve_path("R/OHDSIAssistant/inst/templates/cmAnalysis_template.json", study_base_dir)
    cm_analysis_template_path <- normalizePath(cm_analysis_template_path, winslash = "/", mustWork = FALSE)
  }
  if (!file.exists(cm_analysis_template_path)) {
    cm_analysis_template_path <- NA_character_
  }
  cm_acp_specifications_recommendation_path <- file.path(output_dir, "cm_acp_specifications_recommendation.json")
  cm_analytic_settings_recommendation_path <- file.path(output_dir, "cm_analytic_settings_recommendation.json")
  cm_concept_set_selections_path <- file.path(output_dir, "cm_concept_set_selections.json")
  recs_target_path <- file.path(output_dir, "recommendations_target.json")
  recs_comparator_path <- file.path(output_dir, "recommendations_comparator.json")
  recs_outcome_path <- file.path(output_dir, "recommendations_outcome.json")
  state_path <- file.path(output_dir, "study_agent_state.json")

  cached_inputs <- NULL
  if (maybe_use_cache(manual_inputs_path, "manual cohort-method inputs")) {
    cached_inputs <- jsonlite::fromJSON(manual_inputs_path, simplifyVector = TRUE)
  }
  cached_manual_intent <- NULL
  if (maybe_use_cache(manual_intent_path, "manual cohort-method statements")) {
    cached_manual_intent <- read_json(manual_intent_path)
  }
  cached_cm_target_selection <- load_cached_role_selection(cohort_id_map_path, "target", selected_target_dir)
  cached_cm_comparator_selection <- load_cached_role_selection(cohort_id_map_path, "comparator", selected_comparator_dir)
  cached_cm_outcome_selection <- load_cached_role_selection(cohort_id_map_path, "outcome", selected_outcome_dir)
  cached_incidence_target_selection <- load_cached_role_selection(incidence_cohort_id_map_path, "target", incidence_selected_target_dir)
  cached_incidence_outcome_selection <- load_cached_role_selection(incidence_cohort_id_map_path, "outcome", incidence_selected_outcome_dir)

  if (interactive) {
    banner_path <- resolve_path(bannerPath, study_base_dir)
    banner_path <- normalizePath(banner_path, winslash = "/", mustWork = FALSE)
    if (!file.exists(banner_path) && !is_absolute_path(bannerPath) && !nzchar(studyAgentBaseDir)) {
      alt <- file.path(getwd(), "OHDSI-Study-Agent", bannerPath)
      if (file.exists(alt)) banner_path <- normalizePath(alt, winslash = "/", mustWork = FALSE)
    }
    if (file.exists(banner_path)) {
      cat(paste(readLines(banner_path, warn = FALSE), collapse = "\n"), "\n")
    }
    cat("\nStudy Agent: Strategus CohortMethod shell\n")
  }

  default_intent <- studyIntent %||% cached_inputs$study_intent %||%
    "Compare a target exposure versus a comparator exposure on one or more outcomes using a cohort method design."
  if (isTRUE(interactive)) {
    entered <- readline(sprintf("Study intent [%s]: ", default_intent))
    if (nzchar(trimws(entered))) {
      studyIntent <- entered
    } else {
      studyIntent <- default_intent
    }
  } else if (is.null(studyIntent) || !nzchar(trimws(studyIntent))) {
    studyIntent <- default_intent
  }

  target_statement_default <- targetStatement %||%
    cached_manual_intent$target_statement %||%
    cached_inputs$target_statement %||%
    "Patients with a metformin prescription."
  comparator_statement_default <- comparatorStatement %||%
    cached_manual_intent$comparator_statement %||%
    cached_inputs$comparator_statement %||%
    "Patients with a sulfonylurea prescription."
  outcome_statement_default <- outcomeStatement %||%
    cached_manual_intent$outcome_statement %||%
    cached_inputs$outcome_statement %||%
    "Gastrointestinal bleeding."

  if (isTRUE(interactive)) {
    cat("\nStudy intent split is deferred for cohort methods. Using fixed target/comparator/outcome statements for development.\n")
  }
  targetStatement <- prompt_statement("Target", default = target_statement_default)
  comparatorStatement <- prompt_statement("Comparator", default = comparator_statement_default)
  outcomeStatement <- prompt_statement("Outcome", default = outcome_statement_default)

  target_rec <- run_role_recommendation(
    role_label = "Target",
    statement = targetStatement,
    output_path = recs_target_path,
    top_k = topK,
    max_results = maxResults,
    candidate_limit = candidateLimit,
    allow_multiple = FALSE,
    preferred_selected_ids = targetCohortId,
    preferred_selection_source = "function_argument",
    cached_selected_ids = cached_inputs$target_cohort_id %||% NULL,
    selected_cache_label = "target cohort selection",
    selected_cache_dir = selected_target_dir,
    cohort_method_cache = list(
      selection = list(
        selected_ids = cached_cm_target_selection$selected_ids %||% NULL,
        cache_dir = selected_target_dir
      )
    ),
    incidence_cache = list(
      selection = list(
        selected_ids = cached_incidence_target_selection$selected_ids %||% NULL,
        cache_dir = incidence_selected_target_dir,
        label = "incidence target cohort selection"
      )
    )
  )
  comparator_rec <- run_role_recommendation(
    role_label = "Comparator",
    statement = comparatorStatement,
    output_path = recs_comparator_path,
    top_k = topK,
    max_results = maxResults,
    candidate_limit = candidateLimit,
    allow_multiple = FALSE,
    preferred_selected_ids = comparatorCohortId,
    preferred_selection_source = "function_argument",
    cached_selected_ids = cached_inputs$comparator_cohort_id %||% NULL,
    selected_cache_label = "comparator cohort selection",
    selected_cache_dir = selected_comparator_dir,
    cohort_method_cache = list(
      selection = list(
        selected_ids = cached_cm_comparator_selection$selected_ids %||% NULL,
        cache_dir = selected_comparator_dir
      )
    ),
    incidence_cache = list(
      selection = list(
        selected_ids = NULL,
        cache_dir = NULL,
        label = NULL
      )
    )
  )
  outcome_rec <- run_role_recommendation(
    role_label = "Outcome",
    statement = outcomeStatement,
    output_path = recs_outcome_path,
    top_k = topK,
    max_results = maxResults,
    candidate_limit = candidateLimit,
    allow_multiple = TRUE,
    preferred_selected_ids = outcomeCohortIds,
    preferred_selection_source = "function_argument",
    cached_selected_ids = cached_inputs$outcome_cohort_ids %||% NULL,
    selected_cache_label = "outcome cohort selections",
    selected_cache_dir = selected_outcome_dir,
    cohort_method_cache = list(
      selection = list(
        selected_ids = cached_cm_outcome_selection$selected_ids %||% NULL,
        cache_dir = selected_outcome_dir
      )
    ),
    incidence_cache = list(
      selection = list(
        selected_ids = cached_incidence_outcome_selection$selected_ids %||% NULL,
        cache_dir = incidence_selected_outcome_dir,
        label = "incidence outcome cohort selection"
      )
    )
  )

  targetCohortId <- if (length(target_rec$selected_ids) > 0) {
    as.integer(target_rec$selected_ids[[1]])
  } else {
    collect_single_id(targetCohortId %||% cached_inputs$target_cohort_id, "Target")
  }
  if (!length(target_rec$selected_ids)) target_rec$selection_source <- "manual_input"
  comparatorCohortId <- if (length(comparator_rec$selected_ids) > 0) {
    as.integer(comparator_rec$selected_ids[[1]])
  } else {
    collect_single_id(comparatorCohortId %||% cached_inputs$comparator_cohort_id, "Comparator")
  }
  if (!length(comparator_rec$selected_ids)) comparator_rec$selection_source <- "manual_input"
  outcomeCohortIds <- if (length(outcome_rec$selected_ids) > 0) {
    as.integer(outcome_rec$selected_ids)
  } else {
    collect_outcome_ids(outcomeCohortIds %||% cached_inputs$outcome_cohort_ids)
  }
  if (!length(outcome_rec$selected_ids)) outcome_rec$selection_source <- "manual_input"

  validate_manual_ids <- function(target_id, comparator_id, outcome_ids) {
    if (target_id == comparator_id) {
      return("Target and comparator cohort IDs must be different.")
    }
    if (any(outcome_ids %in% c(target_id, comparator_id))) {
      return("Outcome cohort IDs must be distinct from the target and comparator cohort IDs.")
    }
    if (!cohort_json_exists(target_id, index_def_dir)) {
      return(sprintf("Target cohort ID %s was not found in %s. Please enter a valid target cohort ID.", target_id, index_def_dir))
    }
    if (!cohort_json_exists(comparator_id, index_def_dir)) {
      return(sprintf("Comparator cohort ID %s was not found in %s. Please enter a valid comparator cohort ID.", comparator_id, index_def_dir))
    }
    missing_outcomes <- outcome_ids[!vapply(outcome_ids, cohort_json_exists, logical(1), index_def_dir = index_def_dir)]
    if (length(missing_outcomes) > 0) {
      return(sprintf(
        "Outcome cohort ID(s) %s were not found in %s. Please enter valid outcome cohort IDs.",
        paste(missing_outcomes, collapse = ", "),
        index_def_dir
      ))
    }
    NULL
  }

  validation_error <- validate_manual_ids(targetCohortId, comparatorCohortId, outcomeCohortIds)
  while (!is.null(validation_error) && isTRUE(interactive)) {
    cat(sprintf("%s\n", validation_error))
    targetCohortId <- collect_single_id(NULL, "Target")
    comparatorCohortId <- collect_single_id(NULL, "Comparator")
    outcomeCohortIds <- collect_outcome_ids(NULL)
    validation_error <- validate_manual_ids(targetCohortId, comparatorCohortId, outcomeCohortIds)
  }
  if (!is.null(validation_error)) {
    stop(validation_error)
  }

  target_name <- lookup_catalog_value(targetCohortId, catalog_df, "name", sprintf("Target cohort %s", targetCohortId))
  comparator_name <- lookup_catalog_value(comparatorCohortId, catalog_df, "name", sprintf("Comparator cohort %s", comparatorCohortId))
  outcome_names <- vapply(
    outcomeCohortIds,
    function(id) lookup_catalog_value(id, catalog_df, "name", sprintf("Outcome cohort %s", id)),
    character(1)
  )
  target_desc <- lookup_catalog_value(targetCohortId, catalog_df, "short_description", "")
  comparator_desc <- lookup_catalog_value(comparatorCohortId, catalog_df, "short_description", "")
  outcome_descs <- vapply(
    outcomeCohortIds,
    function(id) lookup_catalog_value(id, catalog_df, "short_description", ""),
    character(1)
  )

  comparisonLabel <- comparisonLabel %||% cached_inputs$comparison_label
  if (is.null(comparisonLabel) || !nzchar(trimws(comparisonLabel))) {
    comparisonLabel <- sprintf("%s vs %s", target_name, comparator_name)
  }
  if (isTRUE(interactive)) {
    entered <- readline(sprintf("Comparison label [%s]: ", comparisonLabel))
    if (nzchar(trimws(entered))) comparisonLabel <- entered
  }

  default_cohort_id_base <- max(c(targetCohortId, comparatorCohortId, outcomeCohortIds), na.rm = TRUE) + 1000L
  use_mapping <- isTRUE(remapCohortIds)
  if (isTRUE(interactive)) {
    use_mapping <- prompt_yesno("Map cohort IDs to a new range (avoid collisions)?", default = isTRUE(remapCohortIds))
  }
  if (use_mapping) {
    cohortIdBase <- cohortIdBase %||% cached_inputs$cohort_id_base %||% default_cohort_id_base
    cohortIdBase <- suppressWarnings(as.integer(cohortIdBase))
    if (isTRUE(interactive)) {
      entered <- trimws(readline(sprintf("Cohort ID base [%s]: ", cohortIdBase)))
      if (nzchar(entered)) cohortIdBase <- suppressWarnings(as.integer(entered))
    }
    cohortIdBase <- validate_positive_integer(cohortIdBase, "cohortIdBase")
  } else {
    cohortIdBase <- NA_integer_
  }

  cached_analytic_settings <- cached_inputs$analytic_settings %||% list()
  cached_analytics <- if (is.null(cached_analytic_settings)) list() else cached_analytic_settings
  cached_covariate_settings <- cached_analytics$covariate_concept_sets %||% list()

  negative_control_enabled <- isTRUE(cached_inputs$negative_control_enabled) ||
    !is.null(negativeControlConceptSetId %||% cached_inputs$negative_control_concept_set_id)
  if (isTRUE(interactive)) {
    negative_control_enabled <- prompt_yesno(
      "Add a negative control concept set selection?",
      default = negative_control_enabled
    )
  }
  if (isTRUE(negative_control_enabled)) {
    negativeControlConceptSetId <- collect_optional_single_id(
      negativeControlConceptSetId %||% cached_inputs$negative_control_concept_set_id,
      "Negative control concept set",
      "Negative control concept set ID: "
    )
    if (is.null(negativeControlConceptSetId)) {
      stop("Negative control concept set ID is required when negative control concept set selection is enabled.")
    }
  } else {
    negativeControlConceptSetId <- NULL
  }

  cached_include_covariate_id <- cached_covariate_settings$include_concept_set_id %||%
    cached_inputs$covariate_include_concept_set_id
  cached_exclude_covariate_id <- cached_covariate_settings$exclude_concept_set_id %||%
    cached_inputs$covariate_exclude_concept_set_id
  cached_include_all_covariates <- cached_covariate_settings$include_all_concepts %||%
    cached_inputs$covariate_include_all_concepts
  covariate_enabled <- isTRUE(cached_covariate_settings$enabled %||% cached_inputs$covariate_concept_sets_enabled) ||
    !is.null(includeCovariateConceptSetId %||% excludeCovariateConceptSetId %||%
      cached_include_covariate_id %||% cached_exclude_covariate_id)
  if (isTRUE(interactive)) {
    covariate_enabled <- prompt_yesno(
      "Add covariate concept set selections?",
      default = covariate_enabled
    )
  }
  include_all_covariates <- isTRUE(cached_include_all_covariates) || !isTRUE(covariate_enabled)
  if (isTRUE(covariate_enabled)) {
    includeCovariateConceptSetId <- collect_optional_single_id(
      includeCovariateConceptSetId %||% cached_include_covariate_id,
      "Covariate include concept set",
      "Covariate include concept set ID [optional; leave blank if you want to include all concepts or only set an exclude concept set]: "
    )
    excludeCovariateConceptSetId <- collect_optional_single_id(
      excludeCovariateConceptSetId %||% cached_exclude_covariate_id,
      "Covariate exclude concept set",
      "Covariate exclude concept set ID [optional]: "
    )
    include_all_covariates <- is.null(includeCovariateConceptSetId)
  } else {
    includeCovariateConceptSetId <- NULL
    excludeCovariateConceptSetId <- NULL
  }

  default_analytic_settings <- .studyAgentDefaultCohortMethodAnalyticSettings(
    covariate_enabled = covariate_enabled
  )

  cached_get_db <- cached_analytics$get_db_cohort_method_data %||% list()
  cached_study_pop <- cached_analytics$create_study_population %||% list()
  cached_ps <- cached_analytics$create_ps %||% list()
  cached_ps_adjustment <- cached_analytics$ps_adjustment %||% list()
  cached_match <- cached_analytics$match_on_ps %||% list()
  cached_stratify <- cached_analytics$stratify_by_ps %||% list()
  cached_outcome_model <- cached_analytics$fit_outcome_model %||% list()
  cached_covariates <- cached_analytics$covariate_concept_sets %||% list()

  merge_or_default <- function(default_value, cache_value) {
    if (is.null(cache_value) || (is.numeric(cache_value) && length(cache_value) == 0)) {
      default_value
    } else {
      cache_value
    }
  }

  effective_analytic_settings <- list(
    profile_name = merge_or_default(default_analytic_settings$profile_name, cached_analytics$profile_name),
    source = "manual_shell",
    customized_sections = character(0),
    get_db_cohort_method_data = list(
      studyStartDate = merge_or_default(
        default_analytic_settings$get_db_cohort_method_data$studyStartDate,
        cached_get_db$studyStartDate
      ),
      studyEndDate = merge_or_default(
        default_analytic_settings$get_db_cohort_method_data$studyEndDate,
        cached_get_db$studyEndDate
      ),
      firstExposureOnly = merge_or_default(
        default_analytic_settings$get_db_cohort_method_data$firstExposureOnly,
        cached_get_db$firstExposureOnly
      ),
      washoutPeriod = as.integer(merge_or_default(
        default_analytic_settings$get_db_cohort_method_data$washoutPeriod,
        cached_get_db$washoutPeriod
      )),
      restrictToCommonPeriod = isTRUE(cached_get_db$restrictToCommonPeriod %||% default_analytic_settings$get_db_cohort_method_data$restrictToCommonPeriod),
      removeDuplicateSubjects = merge_or_default(
        default_analytic_settings$get_db_cohort_method_data$removeDuplicateSubjects,
        cached_get_db$removeDuplicateSubjects
      )
    ),
    create_study_population = list(
      maxCohortSize = as.integer(merge_or_default(
        default_analytic_settings$create_study_population$maxCohortSize,
        cached_study_pop$maxCohortSize
      )),
      removeDuplicateSubjects = merge_or_default(
        default_analytic_settings$create_study_population$removeDuplicateSubjects,
        cached_study_pop$removeDuplicateSubjects
      ),
      removeSubjectsWithPriorOutcome = isTRUE(cached_study_pop$removeSubjectsWithPriorOutcome %||%
        default_analytic_settings$create_study_population$removeSubjectsWithPriorOutcome),
      priorOutcomeLookback = as.integer(merge_or_default(
        default_analytic_settings$create_study_population$priorOutcomeLookback,
        cached_study_pop$priorOutcomeLookback
      )),
      minDaysAtRisk = as.integer(merge_or_default(
        default_analytic_settings$create_study_population$minDaysAtRisk,
        cached_study_pop$minDaysAtRisk
      )),
      riskWindowStart = as.integer(merge_or_default(
        default_analytic_settings$create_study_population$riskWindowStart,
        cached_study_pop$riskWindowStart
      )),
      startAnchor = merge_or_default(
        default_analytic_settings$create_study_population$startAnchor,
        cached_study_pop$startAnchor
      ),
      riskWindowEnd = as.integer(merge_or_default(
        default_analytic_settings$create_study_population$riskWindowEnd,
        cached_study_pop$riskWindowEnd
      )),
      endAnchor = merge_or_default(
        default_analytic_settings$create_study_population$endAnchor,
        cached_study_pop$endAnchor
      ),
      censorAtNewRiskWindow = isTRUE(cached_study_pop$censorAtNewRiskWindow %||%
        default_analytic_settings$create_study_population$censorAtNewRiskWindow)
    ),
    create_ps = list(
      estimator = merge_or_default(
        default_analytic_settings$create_ps$estimator,
        cached_ps$estimator
      ),
      maxCohortSizeForFitting = as.integer(merge_or_default(
        default_analytic_settings$create_ps$maxCohortSizeForFitting,
        cached_ps$maxCohortSizeForFitting
      )),
      errorOnHighCorrelation = isTRUE(cached_ps$errorOnHighCorrelation %||% default_analytic_settings$create_ps$errorOnHighCorrelation),
      useRegularization = isTRUE(cached_ps$useRegularization %||% default_analytic_settings$create_ps$useRegularization)
    ),
    ps_adjustment = list(
      strategy = merge_or_default(
        default_analytic_settings$ps_adjustment$strategy,
        cached_ps_adjustment$strategy
      ),
      trimmingStrategy = merge_or_default(
        default_analytic_settings$ps_adjustment$trimmingStrategy,
        cached_ps_adjustment$trimmingStrategy
      ),
      trimmingPercent = as.numeric(merge_or_default(
        default_analytic_settings$ps_adjustment$trimmingPercent,
        cached_ps_adjustment$trimmingPercent
      )),
      equipoiseLowerBound = as.numeric(merge_or_default(
        default_analytic_settings$ps_adjustment$equipoiseLowerBound,
        cached_ps_adjustment$equipoiseLowerBound
      )),
      equipoiseUpperBound = as.numeric(merge_or_default(
        default_analytic_settings$ps_adjustment$equipoiseUpperBound,
        cached_ps_adjustment$equipoiseUpperBound
      ))
    ),
    match_on_ps = list(
      caliper = as.numeric(merge_or_default(
        default_analytic_settings$match_on_ps$caliper,
        cached_match$caliper
      )),
      caliperScale = merge_or_default(
        default_analytic_settings$match_on_ps$caliperScale,
        cached_match$caliperScale
      ),
      maxRatio = as.integer(merge_or_default(
        default_analytic_settings$match_on_ps$maxRatio,
        cached_match$maxRatio
      ))
    ),
    stratify_by_ps = list(
      numberOfStrata = as.integer(merge_or_default(
        default_analytic_settings$stratify_by_ps$numberOfStrata,
        cached_stratify$numberOfStrata
      )),
      baseSelection = merge_or_default(
        default_analytic_settings$stratify_by_ps$baseSelection,
        cached_stratify$baseSelection
      )
    ),
    fit_outcome_model = list(
      modelType = merge_or_default(
        default_analytic_settings$fit_outcome_model$modelType,
        cached_outcome_model$modelType
      ),
      stratified = isTRUE(cached_outcome_model$stratified %||% default_analytic_settings$fit_outcome_model$stratified),
      useCovariates = isTRUE(cached_outcome_model$useCovariates %||% default_analytic_settings$fit_outcome_model$useCovariates),
      inversePtWeighting = isTRUE(cached_outcome_model$inversePtWeighting %||% default_analytic_settings$fit_outcome_model$inversePtWeighting),
      useRegularization = isTRUE(cached_outcome_model$useRegularization %||% default_analytic_settings$fit_outcome_model$useRegularization)
    ),
    covariate_concept_sets = list(
      enabled = isTRUE(cached_covariates$enabled %||% covariate_enabled),
      include_all_concepts = isTRUE(cached_covariates$include_all_concepts %||% include_all_covariates %||% TRUE),
      include_concept_set_id = json_int_or_null(merge_or_default(cached_covariates$include_concept_set_id, includeCovariateConceptSetId)),
      exclude_concept_set_id = json_int_or_null(merge_or_default(cached_covariates$exclude_concept_set_id, excludeCovariateConceptSetId))
    )
  )

  has_function_argument_description <- !is.null(analyticSettingsDescription) || !is.null(analytic_settings_description_path_resolved)
  cached_mode <- as.character(cached_inputs$analytic_settings_mode %||% if (has_function_argument_description) "free_text" else "step_by_step")
  analytic_settings_mode <- if (isTRUE(interactive)) {
    mode_default <- if (has_function_argument_description || identical(cached_mode, "free_text")) "free-text" else "step-by-step"
    cat("\nHow would you like to configure analytic settings?\n")
    cat("  1. Step-by-step\n")
    cat("     Walk through the required analytic settings sections in order.\n")
    cat("     In the current stage, the shell walks the section flow and shows the OHDSI defaults for the remaining sub-settings.\n")
    cat("  2. Free-text\n")
    cat("     Describe the analytic settings you want in natural language.\n")
    cat("     The shell will create a dummy recommendation JSON, show the proposed key/value pairs, and ask you to confirm.\n")
    mode_choice <- collect_choice_value(
      value = mode_default,
      label = "Analytic settings configuration mode",
      choices = c("step-by-step", "free-text"),
      prompt = "Choose analytic settings mode by number.",
      default = mode_default
    )
    if (identical(mode_choice, "free-text")) "free_text" else "step_by_step"
  } else if (has_function_argument_description ||
             (identical(cached_mode, "free_text") &&
              (nzchar(trimws(as.character(cached_inputs$analytic_settings_description %||% ""))) ||
               nzchar(trimws(as.character(cached_inputs$analytic_settings_description_path %||% "")))))) {
    "free_text"
  } else {
    "step_by_step"
  }
  analytic_settings_selection_source <- if (isTRUE(interactive)) "manual_prompt" else if (!is.null(cached_inputs$analytic_settings_mode)) "cached" else "default_non_interactive"
  analytic_settings_input_method <- if (identical(analytic_settings_mode, "free_text")) {
    as.character(cached_inputs$analytic_settings_input_method %||% "typed_text")
  } else {
    "step_by_step"
  }
  analytic_settings_description <- cached_inputs$analytic_settings_description %||% NULL
  analytic_settings_description_path <- cached_inputs$analytic_settings_description_path %||% NULL
  analytic_settings_recommendation_source <- as.character(cached_inputs$analytic_settings_recommendation_source %||% if (identical(analytic_settings_mode, "free_text")) "pending" else "not_applicable")
  analytic_settings_acp_response_path <- json_string_or_null(cached_inputs$analytic_settings_acp_response_path)
  analytic_settings_recommendation_path <- json_string_or_null(cached_inputs$analytic_settings_recommendation_path)
  analytic_settings_recommendation_status <- as.character(cached_inputs$analytic_settings_recommendation_status %||% if (identical(analytic_settings_mode, "free_text")) "pending" else "not_applicable")
  analytic_settings_confirmed <- isTRUE(cached_inputs$analytic_settings_confirmed %||% FALSE)
  analytic_settings_section_flow <- c("study_population", "time_at_risk", "propensity_score_adjustment", "outcome_model")

  effective_analytic_settings$covariate_concept_sets$include_all_concepts <- isTRUE(!isTRUE(covariate_enabled)) ||
    isTRUE(include_all_covariates)

  if (identical(analytic_settings_mode, "step_by_step")) {
    if (isTRUE(interactive)) {
      cat("\nAnalytic settings mode: step-by-step\n")
      cat("The shell will collect each required section in order and ask for the analytic settings profile name last.\n")
    }

    step_by_step_io <- list(
      section_header = function(label) {
        cat(sprintf("\n[%s]\n", label))
      },
      text = function(prompt, default = "", allow_blank = FALSE) {
        entered <- trimws(readline(sprintf("%s [%s]: ", prompt, default)))
        if (!nzchar(entered)) {
          if (isTRUE(allow_blank)) return(default)
          return(default)
        }
        entered
      },
      yesno = function(prompt, default = TRUE) {
        prompt_yesno_strict(prompt, default = default)
      },
      choice = function(prompt, choices, default, labels = choices) {
        default_index <- match(default, choices)
        if (is.na(default_index)) default_index <- 1L
        selected_label <- collect_choice_value(
          value = labels[[default_index]],
          label = prompt,
          choices = labels,
          prompt = prompt,
          default = labels[[default_index]]
        )
        choices[[match(selected_label, labels)]]
      },
      integer = function(prompt, default, min_value = NULL, allow_negative = TRUE) {
        repeat {
          value <- prompt_integer(
            prompt = prompt,
            default = default,
            allow_null = FALSE,
            must_be_positive = FALSE,
            allow_negative = allow_negative
          )
          if (!is.null(min_value) && value < min_value) {
            cat(sprintf("Please enter an integer >= %s.\n", min_value))
            next
          }
          return(value)
        }
      },
      numeric = function(prompt, default, min_value = NULL) {
        repeat {
          value <- prompt_numeric(
            prompt = prompt,
            default = default,
            must_be_positive = FALSE
          )
          if (!is.null(min_value) && value < min_value) {
            cat(sprintf("Please enter a number >= %s.\n", min_value))
            next
          }
          return(value)
        }
      }
    )
    step_by_step_result <- .studyAgentCollectStepByStepAnalyticSettings(
      default_settings = default_analytic_settings,
      seed_settings = effective_analytic_settings,
      interactive = interactive,
      io = step_by_step_io
    )
    effective_analytic_settings <- step_by_step_result$settings
    analytic_settings_section_flow <- step_by_step_result$section_flow

    analytic_settings_description <- NULL
    analytic_settings_description_path <- NULL
    analytic_settings_recommendation_source <- "not_applicable"
    analytic_settings_acp_response_path <- NA_character_
    analytic_settings_recommendation_path <- NA_character_
    analytic_settings_recommendation_status <- "not_applicable"
    analytic_settings_confirmed <- TRUE
  } else {
    repeat {
      if (!is.null(analyticSettingsDescription)) {
        analytic_settings_input_method <- "function_argument_text"
        analytic_settings_description <- analyticSettingsDescription
        analytic_settings_description_path <- NULL
      } else if (!is.null(analytic_settings_description_path_resolved)) {
        if (!file.exists(analytic_settings_description_path_resolved)) {
          stop(sprintf("Analytic settings description file not found: %s", analytic_settings_description_path_resolved))
        }
        file_lines <- readLines(analytic_settings_description_path_resolved, warn = FALSE)
        analytic_settings_description <- trimws(paste(file_lines, collapse = "\n"))
        if (!nzchar(analytic_settings_description)) {
          stop(sprintf("Analytic settings description file is empty: %s", analytic_settings_description_path_resolved))
        }
        analytic_settings_input_method <- "function_argument_path"
        analytic_settings_description_path <- analytic_settings_description_path_resolved
      } else if (!is.null(analytic_settings_description) && nzchar(trimws(as.character(analytic_settings_description)))) {
        analytic_settings_description <- trimws(as.character(analytic_settings_description))
        analytic_settings_input_method <- as.character(cached_inputs$analytic_settings_input_method %||% "typed_text")
      } else if (!is.null(analytic_settings_description_path) && nzchar(trimws(as.character(analytic_settings_description_path)))) {
        cached_description_path <- normalizePath(resolve_path(as.character(analytic_settings_description_path), study_base_dir), winslash = "/", mustWork = FALSE)
        if (!file.exists(cached_description_path)) {
          stop(sprintf("Cached analytic settings description file not found: %s", cached_description_path))
        }
        file_lines <- readLines(cached_description_path, warn = FALSE)
        analytic_settings_description <- trimws(paste(file_lines, collapse = "\n"))
        if (!nzchar(analytic_settings_description)) {
          stop(sprintf("Cached analytic settings description file is empty: %s", cached_description_path))
        }
        analytic_settings_input_method <- "cached_path"
        analytic_settings_description_path <- cached_description_path
      } else if (isTRUE(interactive)) {
        analytic_settings_description <- prompt_non_null_text(
          "Study description for analytic settings",
          default = analytic_settings_description
        )
        analytic_settings_input_method <- "typed_text"
        analytic_settings_description_path <- NULL
      } else {
        stop("Free-text analytic settings mode requires `analyticSettingsDescription`, `analyticSettingsDescriptionPath`, or a cached description in non-interactive runs.")
      }

      acp_request_body <- list(
        study_intent = studyIntent,
        study_description = analytic_settings_description,
        analytic_settings_description = analytic_settings_description,
        target_cohort_id = as.integer(targetCohortId),
        comparator_cohort_id = as.integer(comparatorCohortId),
        outcome_cohort_ids = as.list(as.integer(outcomeCohortIds)),
        comparison_label = comparisonLabel,
        defaults_snapshot = effective_analytic_settings
      )
      if (isTRUE(interactive)) {
        cat("Calling ACP flow: cohort_methods_specifications_recommendation\n")
      } else {
        message("Calling ACP flow: cohort_methods_specifications_recommendation")
      }
      acp_specifications_response <- call_cohort_methods_specifications_recommendation(
        acp_url = acpUrl,
        body = acp_request_body,
        defaults_snapshot = effective_analytic_settings,
        input_method = analytic_settings_input_method
      )
      write_json(acp_specifications_response, cm_acp_specifications_recommendation_path)
      analytic_settings_acp_response_path <- cm_acp_specifications_recommendation_path
      analytic_settings_recommendation_source <- as.character(acp_specifications_response$source %||% "unknown")

      analytic_settings_recommendation <- acp_specifications_response$recommendation %||%
        build_dummy_analytic_settings_recommendation(
          description = analytic_settings_description,
          defaults_snapshot = effective_analytic_settings,
          input_method = analytic_settings_input_method
        )
      write_json(analytic_settings_recommendation, cm_analytic_settings_recommendation_path)
      analytic_settings_recommendation_path <- cm_analytic_settings_recommendation_path

      if (isTRUE(interactive)) {
        cat("\nAnalytic settings recommendation preview (dummy JSON)\n")
        flattened_recommendation <- flatten_named_values(analytic_settings_recommendation)
        for (item_name in names(flattened_recommendation)) {
          cat(sprintf("  - %s: %s\n", item_name, flattened_recommendation[[item_name]]))
        }
        analytic_settings_confirmed <- prompt_yesno_strict(
          "Confirm this analytic settings recommendation?",
          default = TRUE
        )
        if (!isTRUE(analytic_settings_confirmed)) {
          cat("Let's revise the free-text description.\n")
          next
        }
      } else {
        analytic_settings_confirmed <- isTRUE(cached_inputs$analytic_settings_confirmed %||% TRUE)
      }

      effective_analytic_settings$profile_name <- as.character(
        analytic_settings_recommendation$profile_name %||% effective_analytic_settings$profile_name
      )
      analytic_settings_recommendation_status <- if (identical(analytic_settings_recommendation_source, "acp_flow")) {
        if (isTRUE(analytic_settings_confirmed)) "confirmed_via_acp" else "received_from_acp"
      } else {
        if (isTRUE(analytic_settings_confirmed)) "dummy_fallback" else "dummy_generated"
      }
      break
    }
  }

  effective_analytic_settings$customized_sections <- names(.studyAgentAnalyticSettingsSectionPaths())[vapply(
    names(.studyAgentAnalyticSettingsSectionPaths()),
    function(section_name) {
      paths <- .studyAgentAnalyticSettingsSectionPaths()[[section_name]]
      any(vapply(paths, function(path) {
        !identical(
          .studyAgentGetNestedValue(effective_analytic_settings, path),
          .studyAgentGetNestedValue(default_analytic_settings, path)
        )
      }, logical(1)))
    },
    logical(1)
  )]

  effective_analytic_settings <- normalize_analytic_settings(effective_analytic_settings)
  covariate_enabled <- isTRUE(effective_analytic_settings$covariate_concept_sets$enabled)
  include_all_covariates <- isTRUE(effective_analytic_settings$covariate_concept_sets$include_all_concepts)
  includeCovariateConceptSetId <- if (is.na(effective_analytic_settings$covariate_concept_sets$include_concept_set_id)) {
    NULL
  } else {
    as.integer(effective_analytic_settings$covariate_concept_sets$include_concept_set_id)
  }
  excludeCovariateConceptSetId <- if (is.na(effective_analytic_settings$covariate_concept_sets$exclude_concept_set_id)) {
    NULL
  } else {
    as.integer(effective_analytic_settings$covariate_concept_sets$exclude_concept_set_id)
  }

  manual_intent <- list(
    source = "fixed_statements",
    study_intent = studyIntent,
    target_statement = targetStatement,
    comparator_statement = comparatorStatement,
    outcome_statement = outcomeStatement
  )
  write_json(manual_intent, manual_intent_path)

  manual_inputs <- list(
    study_intent = studyIntent,
    target_statement = targetStatement,
    comparator_statement = comparatorStatement,
    outcome_statement = outcomeStatement,
    comparison_label = comparisonLabel,
    target_cohort_id = as.integer(targetCohortId),
    comparator_cohort_id = as.integer(comparatorCohortId),
    outcome_cohort_ids = as.integer(outcomeCohortIds),
    target_recommendation = list(
      statement = targetStatement,
      path = json_string_or_null(target_rec$recommendation_path),
      source = target_rec$recommendation_source,
      selection_source = target_rec$selection_source,
      used_cached_recommendation = isTRUE(target_rec$used_cached_recommendation),
      used_cached_selection = isTRUE(target_rec$used_cached_selection),
      used_window2 = isTRUE(target_rec$used_window2),
      used_advice = isTRUE(target_rec$used_advice)
    ),
    comparator_recommendation = list(
      statement = comparatorStatement,
      path = json_string_or_null(comparator_rec$recommendation_path),
      source = comparator_rec$recommendation_source,
      selection_source = comparator_rec$selection_source,
      used_cached_recommendation = isTRUE(comparator_rec$used_cached_recommendation),
      used_cached_selection = isTRUE(comparator_rec$used_cached_selection),
      used_window2 = isTRUE(comparator_rec$used_window2),
      used_advice = isTRUE(comparator_rec$used_advice)
    ),
    outcome_recommendation = list(
      statement = outcomeStatement,
      path = json_string_or_null(outcome_rec$recommendation_path),
      source = outcome_rec$recommendation_source,
      selection_source = outcome_rec$selection_source,
      used_cached_recommendation = isTRUE(outcome_rec$used_cached_recommendation),
      used_cached_selection = isTRUE(outcome_rec$used_cached_selection),
      used_window2 = isTRUE(outcome_rec$used_window2),
      used_advice = isTRUE(outcome_rec$used_advice)
    ),
    negative_control_enabled = isTRUE(negative_control_enabled),
    negative_control_concept_set_id = json_int_or_null(negativeControlConceptSetId),
    covariate_concept_sets_enabled = isTRUE(covariate_enabled),
    covariate_include_all_concepts = isTRUE(include_all_covariates),
    covariate_include_concept_set_id = json_int_or_null(includeCovariateConceptSetId),
    covariate_exclude_concept_set_id = json_int_or_null(excludeCovariateConceptSetId),
    target_name = target_name,
    comparator_name = comparator_name,
    outcome_names = as.list(outcome_names),
    target_description = target_desc,
    comparator_description = comparator_desc,
    outcome_descriptions = as.list(outcome_descs),
    customized_sections = as.list(effective_analytic_settings$customized_sections),
    analytic_settings_mode = analytic_settings_mode,
    analytic_settings_selection_source = analytic_settings_selection_source,
    analytic_settings_input_method = analytic_settings_input_method,
    analytic_settings_description = json_string_or_null(analytic_settings_description),
    analytic_settings_description_path = json_string_or_null(analytic_settings_description_path),
    analytic_settings_recommendation_source = analytic_settings_recommendation_source,
    analytic_settings_acp_response_path = json_string_or_null(analytic_settings_acp_response_path),
    analytic_settings_recommendation_path = json_string_or_null(analytic_settings_recommendation_path),
    analytic_settings_recommendation_status = analytic_settings_recommendation_status,
    analytic_settings_confirmed = isTRUE(analytic_settings_confirmed),
    analytic_settings_section_flow = as.list(analytic_settings_section_flow),
    cm_analysis_json_path = cm_analysis_json_path,
    cm_analysis_template_path = json_string_or_null(cm_analysis_template_path),
    remap_cohort_ids = use_mapping,
    cohort_id_base = cohortIdBase
  )
  manual_inputs$analytic_settings <- effective_analytic_settings
  write_json(manual_inputs, manual_inputs_path)

  next_id <- cohortIdBase
  map_ids <- function(ids) {
    if (!use_mapping) return(as.integer(ids))
    new_ids <- seq.int(next_id, length.out = length(ids))
    next_id <<- max(new_ids) + 1L
    as.integer(new_ids)
  }

  selected_target_id <- as.integer(targetCohortId)
  selected_comparator_id <- as.integer(comparatorCohortId)
  selected_outcome_ids <- as.integer(outcomeCohortIds)
  new_target_id <- map_ids(selected_target_id)
  new_comparator_id <- map_ids(selected_comparator_id)
  new_outcome_ids <- map_ids(selected_outcome_ids)

  copy_cohort_json_multi(selected_target_id, new_target_id, c(selected_target_dir, selected_dir), index_def_dir)
  copy_cohort_json_multi(selected_comparator_id, new_comparator_id, c(selected_comparator_dir, selected_dir), index_def_dir)
  for (i in seq_along(selected_outcome_ids)) {
    copy_cohort_json_multi(selected_outcome_ids[[i]], new_outcome_ids[[i]], c(selected_outcome_dir, selected_dir), index_def_dir)
  }

  cohort_map <- data.frame(
    original_id = c(selected_target_id, selected_comparator_id, selected_outcome_ids),
    cohort_id = c(new_target_id, new_comparator_id, new_outcome_ids),
    role = c("target", "comparator", rep("outcome", length(new_outcome_ids))),
    cohort_name = c(target_name, comparator_name, outcome_names),
    short_description = c(target_desc, comparator_desc, outcome_descs),
    stringsAsFactors = FALSE
  )
  write_json(list(mapping = cohort_map), cohort_id_map_path)

  write_json(
    list(
      comparison_label = comparisonLabel,
      targets = as.integer(new_target_id),
      comparators = as.integer(new_comparator_id),
      outcomes = as.integer(new_outcome_ids)
    ),
    cohort_roles_path
  )

  cm_comparisons <- list(
    comparisons = list(
      list(
        comparison_id = 1L,
        label = comparisonLabel,
        study_intent = studyIntent,
        target = list(
          source_id = as.integer(selected_target_id),
          cohort_id = as.integer(new_target_id),
          name = target_name
        ),
        comparator = list(
          source_id = as.integer(selected_comparator_id),
          cohort_id = as.integer(new_comparator_id),
          name = comparator_name
        ),
        outcomes = lapply(seq_along(new_outcome_ids), function(i) {
          list(
            source_id = as.integer(selected_outcome_ids[[i]]),
            cohort_id = as.integer(new_outcome_ids[[i]]),
            name = outcome_names[[i]]
          )
        })
      )
    )
  )
  write_json(cm_comparisons, cm_comparisons_path)

  improvements_status <- list(
    status = "todo",
    applies_to = c("target", "comparator", "outcome"),
    reason = "Current stage is R-only manual shell. ACP phenotype_improvements integration is deferred.",
    future_acp_flow = "phenotype_improvements"
  )
  write_json(improvements_status, improvements_status_path)

  cm_evaluation_todo <- list(
    status = "todo",
    items = list(
      list(
        name = "negative_controls",
        status = if (isTRUE(negative_control_enabled)) "dummy_selected" else "todo",
        enabled = isTRUE(negative_control_enabled),
        concept_set_id = json_int_or_null(negativeControlConceptSetId),
        source = json_string_or_null(if (isTRUE(negative_control_enabled)) "manual_shell" else NULL)
      ),
      list(name = "positive_control_synthesis", status = "todo"),
      list(name = "empirical_calibration", status = "todo")
    ),
    note = "Current stage only scaffolds CohortMethod execution for outcomes of interest."
  )
  write_json(cm_evaluation_todo, cm_evaluation_todo_path)

  acp_mcp_todo <- list(
    status = "in_progress",
    acp = list(
      phenotype_intent_split = "DEFERRED_FIXED_STATEMENTS_IN_USE",
      phenotype_recommendation = list(
        target = if (length(targetCohortId) == 1) "COMPLETED" else "FALLBACK_MANUAL",
        comparator = if (length(comparatorCohortId) == 1) "COMPLETED" else "FALLBACK_MANUAL",
        outcome = if (length(outcomeCohortIds) > 0) "COMPLETED" else "FALLBACK_MANUAL"
      ),
      phenotype_recommendation_advice = list(
        target = if (isTRUE(target_rec$used_advice)) "USED" else "NOT_USED",
        comparator = if (isTRUE(comparator_rec$used_advice)) "USED" else "NOT_USED",
        outcome = if (isTRUE(outcome_rec$used_advice)) "USED" else "NOT_USED"
      ),
      phenotype_improvements = "TODO",
      cohort_methods_specifications_recommendation = "STUB_CALLED_FROM_R_SHELL"
    ),
    mcp = list(
      comparator_setting_reuse = "TODO",
      phenotype_index_search = "TODO"
    ),
    note = "Study intent split is deferred; this shell currently uses fixed target/comparator/outcome statements and cached recommendation artifacts during development."
  )
  write_json(acp_mcp_todo, acp_mcp_todo_path)

  create_dummy_concept_set <- function(path, concept_set_id, label) {
    if (is.null(concept_set_id)) return(NULL)
    payload <- list(
      conceptSetId = as.integer(concept_set_id),
      name = sprintf("Dummy %s %s", label, concept_set_id),
      expression = list(items = list()),
      note = "Placeholder only. Replace this dummy concept set with real concept set content in a later stage."
    )
    write_json(payload, path)
    path
  }

  negative_control_path <- create_dummy_concept_set(
    file.path(concept_sets_dir, "negative_control_concept_set.json"),
    negativeControlConceptSetId,
    "negative control concept set"
  )
  covariate_include_path <- create_dummy_concept_set(
    file.path(concept_sets_dir, "covariate_include_concept_set.json"),
    includeCovariateConceptSetId,
    "covariate include concept set"
  )
  covariate_exclude_path <- create_dummy_concept_set(
    file.path(concept_sets_dir, "covariate_exclude_concept_set.json"),
    excludeCovariateConceptSetId,
    "covariate exclude concept set"
  )

  cm_concept_set_selections <- list(
    negative_control = list(
      enabled = isTRUE(negative_control_enabled),
      concept_set_id = json_int_or_null(negativeControlConceptSetId),
      artifact_path = json_string_or_null(negative_control_path),
      status = if (isTRUE(negative_control_enabled)) "dummy_selected" else "not_selected"
    ),
    covariates = list(
      enabled = isTRUE(covariate_enabled),
      include_all_concepts = isTRUE(include_all_covariates),
      include = list(
        concept_set_id = json_int_or_null(includeCovariateConceptSetId),
        artifact_path = json_string_or_null(covariate_include_path)
      ),
      exclude = list(
        concept_set_id = json_int_or_null(excludeCovariateConceptSetId),
        artifact_path = json_string_or_null(covariate_exclude_path)
      ),
      status = if (isTRUE(covariate_enabled)) "dummy_selected" else "not_selected"
    ),
    note = "Concept set IDs are manual placeholders in the current R-only stage."
  )
  write_json(cm_concept_set_selections, cm_concept_set_selections_path)

  cm_defaults <- list(
    analysis_id = 1L,
    description = effective_analytic_settings$profile_name,
    profile_name = effective_analytic_settings$profile_name,
    source = "manual_shell",
    mode = analytic_settings_mode,
    input_method = analytic_settings_input_method,
    recommendation_path = json_string_or_null(analytic_settings_recommendation_path),
    customized_sections = effective_analytic_settings$customized_sections,
    get_db_cohort_method_data = effective_analytic_settings$get_db_cohort_method_data,
    create_study_population = effective_analytic_settings$create_study_population,
    create_ps = effective_analytic_settings$create_ps,
    ps_adjustment = effective_analytic_settings$ps_adjustment,
    match_on_ps = effective_analytic_settings$match_on_ps,
    stratify_by_ps = effective_analytic_settings$stratify_by_ps,
    fit_outcome_model = effective_analytic_settings$fit_outcome_model,
    covariate_concept_sets = effective_analytic_settings$covariate_concept_sets
  )
  cm_defaults$covariate_concept_sets$enabled <- isTRUE(effective_analytic_settings$covariate_concept_sets$enabled)
  cm_defaults$covariate_concept_sets$note <- "Placeholder only. Dummy concept set IDs are captured for future concept set materialization."
  cm_defaults$get_db_cohort_method_data$removeDuplicateSubjects <- as.character(cm_defaults$get_db_cohort_method_data$removeDuplicateSubjects)
  cm_defaults$create_study_population$removeDuplicateSubjects <- as.character(cm_defaults$create_study_population$removeDuplicateSubjects)
  cm_defaults$cm_analysis_json_path <- cm_analysis_json_path
  write_json(cm_defaults, cm_defaults_path)

  cm_analysis_template <- .studyAgentLoadCmAnalysisTemplate(cm_analysis_template_path)
  cm_analysis_json <- .studyAgentBuildCmAnalysisJson(
    settings = effective_analytic_settings,
    template = cm_analysis_template
  )
  write_json(cm_analysis_json, cm_analysis_json_path)

  cohort_rows <- list(
    data.frame(
      atlas_id = selected_target_id,
      cohort_id = new_target_id,
      cohort_name = target_name,
      cohort_type = "target",
      logic_description = if (nzchar(target_desc)) target_desc else "Manual target cohort selection",
      generate_stats = TRUE,
      stringsAsFactors = FALSE
    ),
    data.frame(
      atlas_id = selected_comparator_id,
      cohort_id = new_comparator_id,
      cohort_name = comparator_name,
      cohort_type = "comparator",
      logic_description = if (nzchar(comparator_desc)) comparator_desc else "Manual comparator cohort selection",
      generate_stats = TRUE,
      stringsAsFactors = FALSE
    )
  )
  if (length(new_outcome_ids) > 0) {
    for (i in seq_along(new_outcome_ids)) {
      cohort_rows[[length(cohort_rows) + 1]] <- data.frame(
        atlas_id = selected_outcome_ids[[i]],
        cohort_id = new_outcome_ids[[i]],
        cohort_name = outcome_names[[i]],
        cohort_type = "outcome",
        logic_description = if (nzchar(outcome_descs[[i]])) outcome_descs[[i]] else "Manual outcome cohort selection",
        generate_stats = TRUE,
        stringsAsFactors = FALSE
      )
    }
  }
  cohort_df <- do.call(rbind, cohort_rows)
  cohort_csv <- file.path(selected_dir, "Cohorts.csv")
  write.csv(cohort_df, cohort_csv, row.names = FALSE)

  state <- list(
    study_intent = studyIntent,
    target_statement = targetStatement,
    comparator_statement = comparatorStatement,
    outcome_statement = outcomeStatement,
    comparison_label = comparisonLabel,
    output_dir = output_dir,
    selected_dir = selected_dir,
    patched_dir = patched_dir,
    selected_target_dir = selected_target_dir,
    selected_comparator_dir = selected_comparator_dir,
    selected_outcome_dir = selected_outcome_dir,
    patched_target_dir = patched_target_dir,
    patched_comparator_dir = patched_comparator_dir,
    patched_outcome_dir = patched_outcome_dir,
    keeper_dir = keeper_dir,
    analysis_settings_dir = analysis_settings_dir,
    scripts_dir = scripts_dir,
    cm_results_dir = cm_results_dir,
    cm_diagnostics_dir = cm_diagnostics_dir,
    cm_data_dir = cm_data_dir,
    manual_intent_path = manual_intent_path,
    manual_inputs_path = manual_inputs_path,
    cohort_id_map_path = cohort_id_map_path,
    cohort_roles_path = cohort_roles_path,
    cm_comparisons_path = cm_comparisons_path,
    improvements_status_path = improvements_status_path,
    cm_evaluation_todo_path = cm_evaluation_todo_path,
    acp_mcp_todo_path = acp_mcp_todo_path,
    cm_defaults_path = cm_defaults_path,
    cm_analysis_json_path = cm_analysis_json_path,
    cm_analysis_template_path = json_string_or_null(cm_analysis_template_path),
    cm_acp_specifications_recommendation_path = json_string_or_null(analytic_settings_acp_response_path),
    cm_analytic_settings_recommendation_path = json_string_or_null(analytic_settings_recommendation_path),
    cm_concept_set_selections_path = cm_concept_set_selections_path,
    cohort_csv = cohort_csv,
    used_cached_inputs = !is.null(cached_inputs),
    resume_enabled = isTRUE(resume),
    remap_cohort_ids = use_mapping,
    cohort_id_base = cohortIdBase,
    analytic_settings_mode = analytic_settings_mode,
    analytic_settings_selection_source = analytic_settings_selection_source,
    analytic_settings_input_method = analytic_settings_input_method,
    analytic_settings_description = json_string_or_null(analytic_settings_description),
    analytic_settings_description_path = json_string_or_null(analytic_settings_description_path),
    analytic_settings_recommendation_source = analytic_settings_recommendation_source,
    analytic_settings_acp_response_path = json_string_or_null(analytic_settings_acp_response_path),
    analytic_settings_recommendation_status = analytic_settings_recommendation_status,
    analytic_settings_confirmed = isTRUE(analytic_settings_confirmed),
    analytic_settings_section_flow = as.list(analytic_settings_section_flow),
    analytic_settings_profile_name = effective_analytic_settings$profile_name,
    analytic_settings_customized_sections = as.character(effective_analytic_settings$customized_sections),
    analytic_settings = effective_analytic_settings,
    negative_control_enabled = isTRUE(negative_control_enabled),
    negative_control_concept_set_id = json_int_or_null(negativeControlConceptSetId),
    covariate_concept_sets_enabled = isTRUE(covariate_enabled),
    covariate_include_all_concepts = isTRUE(include_all_covariates),
    covariate_include_concept_set_id = json_int_or_null(includeCovariateConceptSetId),
    covariate_exclude_concept_set_id = json_int_or_null(excludeCovariateConceptSetId),
    target_recommendation_path = json_string_or_null(target_rec$recommendation_path),
    comparator_recommendation_path = json_string_or_null(comparator_rec$recommendation_path),
    outcome_recommendation_path = json_string_or_null(outcome_rec$recommendation_path),
    target_recommendation_source = target_rec$recommendation_source,
    comparator_recommendation_source = comparator_rec$recommendation_source,
    outcome_recommendation_source = outcome_rec$recommendation_source,
    target_selection_source = target_rec$selection_source,
    comparator_selection_source = comparator_rec$selection_source,
    outcome_selection_source = outcome_rec$selection_source,
    target_used_cached_recommendation = isTRUE(target_rec$used_cached_recommendation),
    comparator_used_cached_recommendation = isTRUE(comparator_rec$used_cached_recommendation),
    outcome_used_cached_recommendation = isTRUE(outcome_rec$used_cached_recommendation),
    target_used_cached_selection = isTRUE(target_rec$used_cached_selection),
    comparator_used_cached_selection = isTRUE(comparator_rec$used_cached_selection),
    outcome_used_cached_selection = isTRUE(outcome_rec$used_cached_selection),
    target_ids = as.integer(new_target_id),
    comparator_ids = as.integer(new_comparator_id),
    outcome_ids = as.integer(new_outcome_ids)
  )
  write_json(state, state_path)

  package_root <- resolve_path("R/OHDSIAssistant", study_base_dir)
  if (!dir.exists(package_root)) {
    alt <- file.path(getwd(), "R", "OHDSIAssistant")
    if (dir.exists(alt)) package_root <- alt
  }
  package_root <- normalizePath(package_root, winslash = "/", mustWork = FALSE)

  script_header <- c(
    "# Generated by OHDSIAssistant::runStrategusCohortMethodsShell",
    "# Edit values as needed and run in order.",
    "# Current stage: manual shell output with TODO placeholders for ACP/MCP integrations.",
    ""
  )
  package_loader_lines <- c(
    sprintf("package_root <- '%s'", package_root),
    "if (!requireNamespace('OHDSIAssistant', quietly = TRUE)) {",
    "  if (requireNamespace('devtools', quietly = TRUE) && dir.exists(package_root)) {",
    "    devtools::load_all(package_root)",
    "  } else {",
    "    stop('OHDSIAssistant is not installed and devtools::load_all(package_root) is unavailable: ', package_root)",
    "  }",
    "}",
    "library(OHDSIAssistant)"
  )

  script_03 <- c(
    script_header,
    "library(Strategus)",
    "library(CohortGenerator)",
    "library(DatabaseConnector)",
    "library(dplyr)",
    "library(CirceR)",
    "library(SqlRender)",
    "",
    package_loader_lines,
    "library(jsonlite)",
    "library(ParallelLogger)",
    "`%||%` <- function(x, y) if (is.null(x)) y else x",
    "",
    sprintf("base_dir <- '%s'", base_dir),
    "selected_dir <- file.path(base_dir, 'selected-cohorts')",
    "patched_dir <- file.path(base_dir, 'patched-cohorts')",
    "cohort_csv <- file.path(selected_dir, 'Cohorts.csv')",
    "cohort_json_dir <- if (length(list.files(patched_dir, pattern = '\\\\.(json)$')) > 0) patched_dir else selected_dir",
    "sql_dir <- file.path(selected_dir, 'sql')",
    "dir.create(sql_dir, recursive = TRUE, showWarnings = FALSE)",
    "",
    "connectionDetails <- OHDSIAssistant::createStrategusConnectionDetails(path = '<FILL IN>')",
    "dbms <- connectionDetails$dbms %||% 'postgresql'",
    "exec <- OHDSIAssistant::createStrategusExecutionSettings(path = '<FILL IN>')",
    "executionSettings_cohorts <- exec$executionSettings",
    "cdmDatabaseSchema <- exec$cdmDatabaseSchema",
    "workDatabaseSchema <- exec$workDatabaseSchema",
    "resultsDatabaseSchema <- exec$resultsDatabaseSchema",
    "vocabularyDatabaseSchema <- exec$vocabularyDatabaseSchema",
    "cohortTable <- exec$cohortTable",
    "cohortIdFieldName <- exec$cohortIdFieldName",
    "dir.create(exec$workFolder, recursive = TRUE, showWarnings = FALSE)",
    "dir.create(exec$resultsFolder, recursive = TRUE, showWarnings = FALSE)",
    "",
    "cohort_settings <- read.csv(cohort_csv, stringsAsFactors = FALSE)",
    "if (nrow(cohort_settings) > 0) {",
    "  id_col <- if ('cohort_id' %in% names(cohort_settings)) 'cohort_id' else 'cohortId'",
    "  for (i in seq_len(nrow(cohort_settings))) {",
    "    cohort_id <- cohort_settings[[id_col]][i]",
    "    sql_path <- file.path(sql_dir, sprintf('%s.sql', cohort_id))",
    "    if (!file.exists(sql_path)) {",
    "      json_path <- file.path(cohort_json_dir, sprintf('%s.json', cohort_id))",
    "      if (!file.exists(json_path)) stop('Missing cohort JSON: ', json_path)",
    "      json_text <- readChar(json_path, nchars = file.info(json_path)$size, useBytes = TRUE)",
    "      cohort_expression <- CirceR::cohortExpressionFromJson(json_text)",
    "      generateOptions <- CirceR::createGenerateOptions(",
    "        cohortIdFieldName = cohortIdFieldName,",
    "        cdmSchema = cdmDatabaseSchema,",
    "        targetTable = paste0(workDatabaseSchema, '.', cohortTable),",
    "        resultSchema = resultsDatabaseSchema,",
    "        vocabularySchema = vocabularyDatabaseSchema,",
    "        generateStats = TRUE",
    "      )",
    "      sql <- CirceR::buildCohortQuery(cohort_expression, generateOptions)",
    "      sql <- SqlRender::render(sql)",
    "      sql <- SqlRender::translate(sql, targetDialect = dbms)",
    "      writeLines(sql, sql_path, useBytes = TRUE)",
    "    }",
    "  }",
    "}",
    "",
    "cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(",
    "  settingsFileName = cohort_csv,",
    "  jsonFolder = cohort_json_dir,",
    "  sqlFolder = sql_dir",
    ")",
    "",
    "cgModule <- CohortGeneratorModule$new()",
    "cohortDefinitionSharedResource <- cgModule$createCohortSharedResourceSpecifications(",
    "  cohortDefinitionSet = cohortDefinitionSet",
    ")",
    "cohortGeneratorModuleSpecifications <- cgModule$createModuleSpecifications(generateStats = TRUE)",
    "",
    "analysisSpecifications <- createEmptyAnalysisSpecifications() %>%",
    "  addSharedResources(cohortDefinitionSharedResource) %>%",
    "  addModuleSpecifications(cohortGeneratorModuleSpecifications)",
    "",
    "execute(",
    "  analysisSpecifications = analysisSpecifications,",
    "  executionSettings = executionSettings_cohorts,",
    "  connectionDetails = connectionDetails",
    ")",
    ""
  )
  write_lines(file.path(scripts_dir, "03_generate_cohorts.R"), script_03)

  script_04 <- c(
    script_header,
    "library(Keeper)",
    "library(jsonlite)",
    "library(DatabaseConnector)",
    "",
    package_loader_lines,
    "",
    sprintf("base_dir <- '%s'", base_dir),
    "output_dir <- file.path(base_dir, 'outputs')",
    "keeper_dir <- file.path(base_dir, 'keeper-case-review')",
    "dir.create(keeper_dir, recursive = TRUE, showWarnings = FALSE)",
    "id_map <- jsonlite::fromJSON(file.path(output_dir, 'cohort_id_map.json'), simplifyVector = TRUE)$mapping",
    "connectionDetails <- OHDSIAssistant::createStrategusConnectionDetails(path = '<FILL IN>')",
    "exec <- OHDSIAssistant::createStrategusExecutionSettings(path = '<FILL IN>')",
    "databaseId <- '<FILL IN>'",
    "cdmDatabaseSchema <- exec$cdmDatabaseSchema",
    "cohortDatabaseSchema <- exec$workDatabaseSchema",
    "cohortTable <- exec$cohortTable",
    "",
    "# TODO: Replace these placeholder concept vectors with study-specific Keeper settings.",
    "keeperConcepts <- list(",
    "  doi = integer(0),",
    "  symptoms = integer(0),",
    "  comorbidities = integer(0),",
    "  drugs = integer(0),",
    "  diagnosticProcedures = integer(0),",
    "  measurements = integer(0),",
    "  alternativeDiagnosis = integer(0),",
    "  treatmentProcedures = integer(0),",
    "  complications = integer(0)",
    ")",
    "",
    "for (i in seq_len(nrow(id_map))) {",
    "  cid <- id_map$cohort_id[i]",
    "  role <- id_map$role[i]",
    "  cohort_name <- id_map$cohort_name[i]",
    "  role_dir <- file.path(keeper_dir, role)",
    "  dir.create(role_dir, recursive = TRUE, showWarnings = FALSE)",
    "  keeper <- createKeeper(",
    "    connectionDetails = connectionDetails,",
    "    databaseId = databaseId,",
    "    cdmDatabaseSchema = cdmDatabaseSchema,",
    "    cohortDatabaseSchema = cohortDatabaseSchema,",
    "    cohortTable = cohortTable,",
    "    cohortDefinitionId = cid,",
    "    cohortName = cohort_name,",
    "    sampleSize = 100,",
    "    assignNewId = TRUE,",
    "    useAncestor = TRUE,",
    "    doi = keeperConcepts$doi,",
    "    symptoms = keeperConcepts$symptoms,",
    "    comorbidities = keeperConcepts$comorbidities,",
    "    drugs = keeperConcepts$drugs,",
    "    diagnosticProcedures = keeperConcepts$diagnosticProcedures,",
    "    measurements = keeperConcepts$measurements,",
    "    alternativeDiagnosis = keeperConcepts$alternativeDiagnosis,",
    "    treatmentProcedures = keeperConcepts$treatmentProcedures,",
    "    complications = keeperConcepts$complications",
    "  )",
    "  out_path <- file.path(role_dir, sprintf('%s.csv', cid))",
    "  write.csv(keeper, out_path, row.names = FALSE)",
    "}",
    "",
    "# TODO: When ACP is implemented for cohort methods, add optional LLM-based Keeper row review here.",
    ""
  )
  write_lines(file.path(scripts_dir, "04_keeper_review.R"), script_04)

  script_05 <- c(
    script_header,
    "library(Strategus)",
    "library(CohortDiagnostics)",
    "library(CohortGenerator)",
    "library(DatabaseConnector)",
    "library(dplyr)",
    "",
    package_loader_lines,
    "",
    sprintf("base_dir <- '%s'", base_dir),
    "selected_dir <- file.path(base_dir, 'selected-cohorts')",
    "patched_dir <- file.path(base_dir, 'patched-cohorts')",
    "cohort_csv <- file.path(selected_dir, 'Cohorts.csv')",
    "cohort_json_dir <- if (length(list.files(patched_dir, pattern = '\\\\.(json)$')) > 0) patched_dir else selected_dir",
    "sql_dir <- file.path(selected_dir, 'sql')",
    "dir.create(sql_dir, recursive = TRUE, showWarnings = FALSE)",
    "",
    "connectionDetails <- OHDSIAssistant::createStrategusConnectionDetails(path = '<FILL IN>')",
    "exec <- OHDSIAssistant::createStrategusExecutionSettings(path = '<FILL IN>')",
    "executionSettings_diagnostics <- exec$executionSettings",
    "",
    "cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(",
    "  settingsFileName = cohort_csv,",
    "  jsonFolder = cohort_json_dir,",
    "  sqlFolder = sql_dir",
    ")",
    "",
    "cgModule <- CohortGeneratorModule$new()",
    "cohortDefinitionSharedResource <- cgModule$createCohortSharedResourceSpecifications(",
    "  cohortDefinitionSet = cohortDefinitionSet",
    ")",
    "",
    "cdModule <- CohortDiagnosticsModule$new()",
    "cohortDiagnosticsModuleSpecifications <- cdModule$createModuleSpecifications(",
    "  runInclusionStatistics = TRUE,",
    "  runIncludedSourceConcepts = TRUE,",
    "  runOrphanConcepts = TRUE,",
    "  runTimeSeries = FALSE,",
    "  runVisitContext = TRUE,",
    "  runBreakdownIndexEvents = TRUE,",
    "  runIncidenceRate = TRUE,",
    "  runCohortRelationship = TRUE,",
    "  runTemporalCohortCharacterization = TRUE",
    ")",
    "",
    "analysisSpecifications <- createEmptyAnalysisSpecifications() %>%",
    "  addSharedResources(cohortDefinitionSharedResource) %>%",
    "  addModuleSpecifications(cohortDiagnosticsModuleSpecifications)",
    "",
    "execute(",
    "  analysisSpecifications = analysisSpecifications,",
    "  executionSettings = executionSettings_diagnostics,",
    "  connectionDetails = connectionDetails",
    ")",
    ""
  )
  write_lines(file.path(scripts_dir, "05_diagnostics.R"), script_05)

  script_06 <- c(
    script_header,
    "library(CohortMethod)",
    "library(FeatureExtraction)",
    "library(jsonlite)",
    "",
    sprintf("base_dir <- '%s'", base_dir),
    "output_dir <- file.path(base_dir, 'outputs')",
    "analysis_settings_dir <- file.path(base_dir, 'analysis-settings')",
    "dir.create(analysis_settings_dir, recursive = TRUE, showWarnings = FALSE)",
    "",
    "`%||%` <- function(x, y) if (is.null(x)) y else x",
    "defaults <- jsonlite::fromJSON(file.path(output_dir, 'cm_analysis_defaults.json'), simplifyVector = TRUE)",
    "conceptSetSelections <- jsonlite::fromJSON(file.path(output_dir, 'cm_concept_set_selections.json'), simplifyVector = FALSE)",
    "getDbDefaults <- defaults$get_db_cohort_method_data",
    "studyPopulationDefaults <- defaults$create_study_population",
    "psDefaults <- defaults$create_ps",
    "psAdjustmentDefaults <- defaults$ps_adjustment %||% list()",
    "matchDefaults <- defaults$match_on_ps",
    "stratifyDefaults <- defaults$stratify_by_ps %||% list()",
    "outcomeModelDefaults <- defaults$fit_outcome_model",
    "covariateConceptDefaults <- defaults$covariate_concept_sets %||% list()",
    "comparison_payload <- jsonlite::fromJSON(file.path(output_dir, 'cm_comparisons.json'), simplifyVector = FALSE)",
    "comparisons <- comparison_payload$comparisons %||% list()",
    "if (length(comparisons) == 0) stop('No comparisons found in cm_comparisons.json')",
    "comparison <- comparisons[[1]]",
    "analyticSettingsProfile <- defaults$profile_name %||% 'Analytic Setting 1'",
    "psAdjustmentStrategy <- psAdjustmentDefaults$strategy %||% 'match_on_ps'",
    "psTrimmingStrategy <- psAdjustmentDefaults$trimmingStrategy %||% 'none'",
    "psTrimmingPercent <- as.numeric(psAdjustmentDefaults$trimmingPercent %||% 5)",
    "if (is.na(psTrimmingPercent)) psTrimmingPercent <- 5",
    "equipoiseLowerBound <- as.numeric(psAdjustmentDefaults$equipoiseLowerBound %||% 0.25)",
    "equipoiseUpperBound <- as.numeric(psAdjustmentDefaults$equipoiseUpperBound %||% 0.75)",
    "if (is.na(equipoiseLowerBound)) equipoiseLowerBound <- 0.25",
    "if (is.na(equipoiseUpperBound)) equipoiseUpperBound <- 0.75",
    "matchMaxRatio <- as.integer(matchDefaults$maxRatio %||% 1L)",
    "if (is.na(matchMaxRatio)) matchMaxRatio <- 1L",
    "derivedOutcomeStratified <- if (identical(psAdjustmentStrategy, 'stratify_by_ps')) {",
    "  TRUE",
    "} else if (identical(psAdjustmentStrategy, 'match_on_ps')) {",
    "  matchMaxRatio != 1L",
    "} else {",
    "  FALSE",
    "}",
    "",
    "target_id <- as.integer(comparison$target$cohort_id %||% NA_integer_)",
    "comparator_id <- as.integer(comparison$comparator$cohort_id %||% NA_integer_)",
    "outcome_ids <- vapply(comparison$outcomes %||% list(), function(x) as.integer(x$cohort_id %||% NA_integer_), integer(1))",
    "if (is.na(target_id)) stop('Missing target cohort ID in cm_comparisons.json')",
    "if (is.na(comparator_id)) stop('Missing comparator cohort ID in cm_comparisons.json')",
    "if (length(outcome_ids) == 0) stop('Missing outcome cohort IDs in cm_comparisons.json')",
    "",
    "negativeControlConceptSet <- conceptSetSelections$negative_control %||% list()",
    "covariateConceptSelections <- conceptSetSelections$covariates %||% list()",
    "includedConceptSetId <- as.integer(covariateConceptDefaults$include_concept_set_id %||% covariateConceptSelections$include$concept_set_id %||% NA_integer_)",
    "excludedConceptSetId <- as.integer(covariateConceptDefaults$exclude_concept_set_id %||% covariateConceptSelections$exclude$concept_set_id %||% NA_integer_)",
    "includedCovariateConceptIds <- integer(0)",
    "excludedCovariateConceptIds <- integer(0)",
    "if (!is.na(includedConceptSetId)) message('TODO: Replace dummy covariate include concept set ', includedConceptSetId, ' with actual concept IDs before production use.')",
    "if (!is.na(excludedConceptSetId)) message('TODO: Replace dummy covariate exclude concept set ', excludedConceptSetId, ' with actual concept IDs before production use.')",
    "if (isTRUE(negativeControlConceptSet$enabled %||% FALSE)) message('TODO: Negative control concept set selected as dummy placeholder: ', negativeControlConceptSet$concept_set_id %||% NA_integer_)",
    "",
    "priorOutcomeLookback <- studyPopulationDefaults$priorOutcomeLookback %||% 99999L",
    "riskWindowStart <- studyPopulationDefaults$riskWindowStart %||% 0L",
    "startAnchor <- studyPopulationDefaults$startAnchor %||% 'cohort start'",
    "riskWindowEnd <- studyPopulationDefaults$riskWindowEnd %||% 0L",
    "endAnchor <- studyPopulationDefaults$endAnchor %||% 'cohort end'",
    "outcomes <- lapply(outcome_ids, function(outcome_id) {",
    "  CohortMethod::createOutcome(",
    "    outcomeId = outcome_id,",
    "    outcomeOfInterest = TRUE,",
    "    priorOutcomeLookback = priorOutcomeLookback,",
    "    riskWindowStart = riskWindowStart,",
    "    startAnchor = startAnchor,",
    "    riskWindowEnd = riskWindowEnd,",
    "    endAnchor = endAnchor",
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
    "covariateSettings <- FeatureExtraction::createDefaultCovariateSettings()",
    "getDbCohortMethodDataArgs <- CohortMethod::createGetDbCohortMethodDataArgs(",
    "  removeDuplicateSubjects = getDbDefaults$removeDuplicateSubjects,",
    "  firstExposureOnly = getDbDefaults$firstExposureOnly,",
    "  washoutPeriod = getDbDefaults$washoutPeriod,",
    "  restrictToCommonPeriod = getDbDefaults$restrictToCommonPeriod,",
    "  studyStartDate = getDbDefaults$studyStartDate %||% '',",
    "  studyEndDate = getDbDefaults$studyEndDate %||% '',",
    "  covariateSettings = covariateSettings",
    ")",
    "createStudyPopulationArgs <- CohortMethod::createCreateStudyPopulationArgs(",
    "  maxCohortSize = studyPopulationDefaults$maxCohortSize,",
    "  removeDuplicateSubjects = studyPopulationDefaults$removeDuplicateSubjects,",
    "  removeSubjectsWithPriorOutcome = studyPopulationDefaults$removeSubjectsWithPriorOutcome,",
    "  priorOutcomeLookback = studyPopulationDefaults$priorOutcomeLookback,",
    "  minDaysAtRisk = studyPopulationDefaults$minDaysAtRisk,",
    "  riskWindowStart = studyPopulationDefaults$riskWindowStart,",
    "  startAnchor = studyPopulationDefaults$startAnchor,",
    "  riskWindowEnd = studyPopulationDefaults$riskWindowEnd,",
    "  endAnchor = studyPopulationDefaults$endAnchor,",
    "  censorAtNewRiskWindow = studyPopulationDefaults$censorAtNewRiskWindow",
    ")",
    "psPrior <- if (isTRUE(psDefaults$useRegularization %||% TRUE)) {",
    "  Cyclops::createPrior(priorType = 'laplace', exclude = c(0), useCrossValidation = TRUE)",
    "} else {",
    "  Cyclops::createPrior(priorType = 'none')",
    "}",
    "createPsArgs <- if (identical(psAdjustmentStrategy, 'none') && identical(psTrimmingStrategy, 'none')) NULL else CohortMethod::createCreatePsArgs(",
    "  estimator = psDefaults$estimator,",
    "  maxCohortSizeForFitting = psDefaults$maxCohortSizeForFitting,",
    "  errorOnHighCorrelation = isTRUE(psDefaults$errorOnHighCorrelation %||% FALSE),",
    "  prior = psPrior",
    ")",
    "trimByPsArgs <- if (identical(psTrimmingStrategy, 'by_percent')) {",
    "  CohortMethod::createTrimByPsArgs(",
    "    trimFraction = psTrimmingPercent / 100,",
    "    trimMethod = 'symmetric'",
    "  )",
    "} else if (identical(psTrimmingStrategy, 'by_equipoise')) {",
    "  CohortMethod::createTrimByPsArgs(",
    "    equipoiseBounds = c(equipoiseLowerBound, equipoiseUpperBound)",
    "  )",
    "} else {",
    "  NULL",
    "}",
    "matchOnPsArgs <- if (identical(psAdjustmentStrategy, 'match_on_ps')) CohortMethod::createMatchOnPsArgs(",
    "  caliper = matchDefaults$caliper,",
    "  caliperScale = matchDefaults$caliperScale,",
    "  maxRatio = matchDefaults$maxRatio",
    ") else NULL",
    "stratifyByPsArgs <- if (identical(psAdjustmentStrategy, 'stratify_by_ps')) CohortMethod::createStratifyByPsArgs(",
    "  numberOfStrata = stratifyDefaults$numberOfStrata,",
    "  baseSelection = stratifyDefaults$baseSelection",
    ") else NULL",
    "fitOutcomeModelArgs <- CohortMethod::createFitOutcomeModelArgs(",
    "  modelType = outcomeModelDefaults$modelType,",
    "  stratified = outcomeModelDefaults$stratified %||% derivedOutcomeStratified,",
    "  useCovariates = isTRUE(outcomeModelDefaults$useCovariates %||% FALSE),",
    "  inversePtWeighting = isTRUE(outcomeModelDefaults$inversePtWeighting %||% FALSE),",
    "  useRegularization = isTRUE(outcomeModelDefaults$useRegularization %||% TRUE)",
    ")",
    "",
    "cmAnalysisList <- list(",
    "  CohortMethod::createCmAnalysis(",
    "    analysisId = as.integer(defaults$analysis_id %||% 1L),",
    "    description = analyticSettingsProfile %||% comparison$label %||% 'Default cohort method analysis',",
    "    getDbCohortMethodDataArgs = getDbCohortMethodDataArgs,",
    "    createStudyPopulationArgs = createStudyPopulationArgs,",
    "    createPsArgs = createPsArgs,",
    "    trimByPsArgs = trimByPsArgs,",
    "    matchOnPsArgs = matchOnPsArgs,",
    "    stratifyByPsArgs = stratifyByPsArgs,",
    "    fitOutcomeModelArgs = fitOutcomeModelArgs",
    "  )",
    ")",
    "",
    "CohortMethod::saveTargetComparatorOutcomesList(",
    "  targetComparatorOutcomesList,",
    "  file.path(analysis_settings_dir, 'targetComparatorOutcomesList.json')",
    ")",
    "CohortMethod::saveCmAnalysisList(",
    "  cmAnalysisList,",
    "  file.path(analysis_settings_dir, 'cmAnalysisList.json')",
    ")",
    "jsonlite::write_json(",
    "  list(",
    "    comparison_label = comparison$label %||% '',",
    "    target_id = target_id,",
    "    comparator_id = comparator_id,",
    "    outcome_ids = as.list(outcome_ids),",
    "    defaults_path = file.path(output_dir, 'cm_analysis_defaults.json'),",
    "    cm_analysis_json_path = file.path(analysis_settings_dir, 'cmAnalysis.json'),",
    "    concept_set_selections_path = file.path(output_dir, 'cm_concept_set_selections.json'),",
    "    negative_control_concept_set_id = negativeControlConceptSet$concept_set_id %||% NULL,",
    "    study_start_date = getDbDefaults$studyStartDate %||% '',",
    "    study_end_date = getDbDefaults$studyEndDate %||% '',",
    "    ps_adjustment_strategy = psAdjustmentStrategy,",
    "    ps_trimming_strategy = psTrimmingStrategy,",
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
    ""
  )
  write_lines(file.path(scripts_dir, "06_cm_spec.R"), script_06)

  script_07 <- c(
    script_header,
    "library(CohortMethod)",
    "library(ParallelLogger)",
    "",
    package_loader_lines,
    "",
    sprintf("base_dir <- '%s'", base_dir),
    "analysis_settings_dir <- file.path(base_dir, 'analysis-settings')",
    "cm_results_dir <- file.path(base_dir, 'cm-results')",
    "cm_diagnostics_dir <- file.path(base_dir, 'cm-diagnostics')",
    "dir.create(cm_results_dir, recursive = TRUE, showWarnings = FALSE)",
    "dir.create(cm_diagnostics_dir, recursive = TRUE, showWarnings = FALSE)",
    "",
    "connectionDetails <- OHDSIAssistant::createStrategusConnectionDetails(path = '<FILL IN>')",
    "exec <- OHDSIAssistant::createStrategusExecutionSettings(path = '<FILL IN>')",
    "cmAnalysisList <- CohortMethod::loadCmAnalysisList(file.path(analysis_settings_dir, 'cmAnalysisList.json'))",
    "targetComparatorOutcomesList <- CohortMethod::loadTargetComparatorOutcomesList(file.path(analysis_settings_dir, 'targetComparatorOutcomesList.json'))",
    "",
    "multiThreadingSettings <- CohortMethod::createDefaultMultiThreadingSettings(parallel::detectCores())",
    "result <- CohortMethod::runCmAnalyses(",
    "  connectionDetails = connectionDetails,",
    "  cdmDatabaseSchema = exec$cdmDatabaseSchema,",
    "  exposureDatabaseSchema = exec$workDatabaseSchema,",
    "  exposureTable = exec$cohortTable,",
    "  outcomeDatabaseSchema = exec$workDatabaseSchema,",
    "  outcomeTable = exec$cohortTable,",
    "  cdmVersion = '5',",
    "  outputFolder = cm_results_dir,",
    "  cmAnalysisList = cmAnalysisList,",
    "  targetComparatorOutcomesList = targetComparatorOutcomesList,",
    "  refitPsForEveryOutcome = FALSE,",
    "  refitPsForEveryStudyPopulation = TRUE,",
    "  multiThreadingSettings = multiThreadingSettings",
    ")",
    "",
    "file_reference <- CohortMethod::getFileReference(cm_results_dir)",
    "results_summary <- CohortMethod::getResultsSummary(cm_results_dir)",
    "diagnostics_summary <- CohortMethod::getDiagnosticsSummary(cm_results_dir)",
    "write.csv(as.data.frame(file_reference), file.path(cm_results_dir, 'file_reference.csv'), row.names = FALSE)",
    "write.csv(as.data.frame(results_summary), file.path(cm_results_dir, 'results_summary.csv'), row.names = FALSE)",
    "write.csv(as.data.frame(diagnostics_summary), file.path(cm_diagnostics_dir, 'diagnostics_summary.csv'), row.names = FALSE)",
    "",
    "CohortMethod::exportToCsv(",
    "  cm_results_dir,",
    "  exportFolder = file.path(cm_results_dir, 'export'),",
    "  databaseId = '<FILL IN>',",
    "  minCellCount = 5,",
    "  maxCores = parallel::detectCores()",
    ")",
    "",
    "# TODO: Add negative / positive control calibration outputs in a later stage.",
    ""
  )
  write_lines(file.path(scripts_dir, "07_cm_run_analyses.R"), script_07)

  if (interactive) {
    cat("\n== Session Summary ==\n")
    cat(sprintf("Study intent: %s\n", studyIntent))
    cat(sprintf("Comparison: %s\n", comparisonLabel))
    cat(sprintf("Target: %s (atlas %s -> cohort %s)\n", target_name, selected_target_id, new_target_id))
    cat(sprintf("Comparator: %s (atlas %s -> cohort %s)\n", comparator_name, selected_comparator_id, new_comparator_id))
    cat("Outcomes:\n")
    for (i in seq_along(new_outcome_ids)) {
      cat(sprintf("  - %s (atlas %s -> cohort %s)\n", outcome_names[[i]], selected_outcome_ids[[i]], new_outcome_ids[[i]]))
    }
    if (isTRUE(negative_control_enabled)) {
      cat(sprintf("Negative control concept set: %s\n", negativeControlConceptSetId))
    }
    if (isTRUE(covariate_enabled)) {
      include_label <- if (is.null(includeCovariateConceptSetId)) "all concepts" else as.character(includeCovariateConceptSetId)
      exclude_label <- if (is.null(excludeCovariateConceptSetId)) "none" else as.character(excludeCovariateConceptSetId)
      cat(sprintf("Covariate concept sets: include=%s, exclude=%s\n", include_label, exclude_label))
    }
    cat(sprintf("Cohort ID remap: %s\n", if (isTRUE(use_mapping)) sprintf("enabled (base %s)", cohortIdBase) else "disabled"))
    cat(sprintf("Analytic settings mode: %s\n", analytic_settings_mode))
    cat(sprintf("Analytic settings profile: %s\n", effective_analytic_settings$profile_name))
    section_label <- if (length(effective_analytic_settings$customized_sections) == 0) {
      "defaults only"
    } else {
      paste(as.character(effective_analytic_settings$customized_sections), collapse = ", ")
    }
    cat(sprintf("Customized analytic sections: %s\n", section_label))
    if (identical(analytic_settings_mode, "free_text")) {
      cat(sprintf("Analytic settings description: %s\n", analytic_settings_description))
      cat(sprintf("Analytic settings recommendation source: %s\n", analytic_settings_recommendation_source))
      cat(sprintf("Analytic settings recommendation: %s (%s)\n", analytic_settings_recommendation_path, analytic_settings_recommendation_status))
      if (!is.na(analytic_settings_acp_response_path)) {
        cat(sprintf("ACP specifications response: %s\n", analytic_settings_acp_response_path))
      }
    }
    cat("Generated scripts:\n")
    cat("  - 03_generate_cohorts.R\n")
    cat("  - 04_keeper_review.R\n")
    cat("  - 05_diagnostics.R\n")
    cat("  - 06_cm_spec.R\n")
    cat("  - 07_cm_run_analyses.R\n")
    cat("TODO artifacts:\n")
    cat(sprintf("  - %s\n", acp_mcp_todo_path))
    cat(sprintf("  - %s\n", improvements_status_path))
    cat(sprintf("  - %s\n", cm_evaluation_todo_path))
  }

  invisible(list(
    output_dir = output_dir,
    scripts_dir = scripts_dir,
    manual_intent = manual_intent_path,
    manual_inputs = manual_inputs_path,
    cm_comparisons = cm_comparisons_path,
    cm_concept_set_selections = cm_concept_set_selections_path,
    cm_analysis_json = cm_analysis_json_path,
    cohort_csv = cohort_csv,
    state = state_path
  ))
}
