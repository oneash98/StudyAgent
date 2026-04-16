#' Interactive shell to generate Strategus CohortMethod scripts
#' @param outputDir directory where scripts and artifacts will be written
#' @param acpUrl ACP base URL for placeholder cohort-method recommendation calls
#' @param studyIntent study intent text
#' @param targetCohortId target cohort definition ID
#' @param comparatorCohortId comparator cohort definition ID
#' @param outcomeCohortIds outcome cohort definition IDs
#' @param comparisonLabel optional label for the target-comparator comparison
#' @param indexDir phenotype index directory (contains definitions/ and catalog.jsonl)
#' @param negativeControlConceptSetId optional negative control concept set ID
#' @param includeCovariateConceptSetId optional covariate include concept set ID
#' @param excludeCovariateConceptSetId optional covariate exclude concept set ID
#' @param analyticSettingsDescription optional free-text analytic settings description
#' @param analyticSettingsDescriptionPath optional path to a text file containing the free-text analytic settings description
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
runStrategusCohortMethodsShell <- function(outputDir = "demo-strategus-cohort-methods",
                                           acpUrl = "http://127.0.0.1:8765",
                                           studyIntent = NULL,
                                           targetCohortId = NULL,
                                           comparatorCohortId = NULL,
                                           outcomeCohortIds = NULL,
                                           comparisonLabel = NULL,
                                           indexDir = Sys.getenv("PHENOTYPE_INDEX_DIR", "data/phenotype_index"),
                                           negativeControlConceptSetId = NULL,
                                           includeCovariateConceptSetId = NULL,
                                           excludeCovariateConceptSetId = NULL,
                                           analyticSettingsDescription = NULL,
                                           analyticSettingsDescriptionPath = NULL,
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
      entered <- tolower(trimws(readline(sprintf("%s %s ", prompt, suffix))))
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
      entered <- trimws(readline(sprintf("%s%s: ", prompt, prompt_suffix)))
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
      entered <- trimws(readline(sprintf("%s%s: ", prompt, prompt_suffix)))
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
      entered <- trimws(readline(sprintf("%s [%s]: ", prompt, default)))
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
      c("keep all", "keep first", "remove all"),
      "analytic_settings.get_db_cohort_method_data.removeDuplicateSubjects"
    )
    settings$create_study_population$removeDuplicateSubjects <- validate_choice(
      settings$create_study_population$removeDuplicateSubjects,
      c("keep all", "keep first", "remove all"),
      "analytic_settings.create_study_population.removeDuplicateSubjects"
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
    settings$match_on_ps$caliper <- validate_numeric_value(
      settings$match_on_ps$caliper,
      "analytic_settings.match_on_ps.caliper",
      min_value = .Machine$double.eps
    )
    settings$match_on_ps$caliperScale <- validate_choice(
      settings$match_on_ps$caliperScale,
      c("propensity score", "standardized", "standardized logit"),
      "analytic_settings.match_on_ps.caliperScale"
    )
    settings$match_on_ps$maxRatio <- validate_integer_value(
      settings$match_on_ps$maxRatio,
      "analytic_settings.match_on_ps.maxRatio",
      min_value = 1L
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
  index_dir <- resolve_path(indexDir, study_base_dir)
  index_dir <- normalizePath(index_dir, winslash = "/", mustWork = FALSE)
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
  cm_comparisons_path <- file.path(output_dir, "cm_comparisons.json")
  improvements_status_path <- file.path(output_dir, "improvements_status.json")
  cm_evaluation_todo_path <- file.path(output_dir, "cm_evaluation_todo.json")
  acp_mcp_todo_path <- file.path(output_dir, "acp_mcp_todo.json")
  cm_defaults_path <- file.path(output_dir, "cm_analysis_defaults.json")
  cm_acp_specifications_recommendation_path <- file.path(output_dir, "cm_acp_specifications_recommendation.json")
  cm_analytic_settings_recommendation_path <- file.path(output_dir, "cm_analytic_settings_recommendation.json")
  cm_concept_set_selections_path <- file.path(output_dir, "cm_concept_set_selections.json")
  state_path <- file.path(output_dir, "study_agent_state.json")

  cached_inputs <- NULL
  if (maybe_use_cache(manual_inputs_path, "manual cohort-method inputs")) {
    cached_inputs <- jsonlite::fromJSON(manual_inputs_path, simplifyVector = TRUE)
  }

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

  targetCohortId <- collect_single_id(targetCohortId %||% cached_inputs$target_cohort_id, "Target")
  comparatorCohortId <- collect_single_id(comparatorCohortId %||% cached_inputs$comparator_cohort_id, "Comparator")
  outcomeCohortIds <- collect_outcome_ids(outcomeCohortIds %||% cached_inputs$outcome_cohort_ids)

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

  catalog_df <- load_catalog(index_dir)
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

  cached_sections <- cached_inputs$analytic_settings_customized_sections %||%
    cached_inputs$customized_sections %||%
    cached_analytics$customized_sections %||% character(0)
  cached_sections <- as.character(unlist(cached_sections, use.names = FALSE))
  cached_sections <- cached_sections[nzchar(cached_sections)]

  default_analytic_settings <- list(
    profile_name = "Propensity score matching",
    source = "manual_shell",
    customized_sections = character(0),
    get_db_cohort_method_data = list(
      firstExposureOnly = TRUE,
      washoutPeriod = 365L,
      restrictToCommonPeriod = TRUE,
      removeDuplicateSubjects = "keep all"
    ),
    create_study_population = list(
      removeDuplicateSubjects = "remove all",
      removeSubjectsWithPriorOutcome = TRUE,
      priorOutcomeLookback = 99999L,
      riskWindowStart = 1L,
      startAnchor = "cohort start",
      riskWindowEnd = 0L,
      endAnchor = "cohort end",
      censorAtNewRiskWindow = TRUE
    ),
    create_ps = list(
      estimator = "att",
      maxCohortSizeForFitting = 250000L
    ),
    match_on_ps = list(
      caliper = 0.2,
      caliperScale = "standardized logit",
      maxRatio = 100L
    ),
    fit_outcome_model = list(
      modelType = "cox",
      stratified = TRUE
    ),
    covariate_concept_sets = list(
      enabled = isTRUE(covariate_enabled),
      include_all_concepts = TRUE,
      include_concept_set_id = NA_integer_,
      exclude_concept_set_id = NA_integer_
    )
  )

  cached_get_db <- cached_analytics$get_db_cohort_method_data %||% list()
  cached_study_pop <- cached_analytics$create_study_population %||% list()
  cached_ps <- cached_analytics$create_ps %||% list()
  cached_match <- cached_analytics$match_on_ps %||% list()
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
    customized_sections = as.character(cached_sections),
    get_db_cohort_method_data = list(
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
    fit_outcome_model = list(
      modelType = merge_or_default(
        default_analytic_settings$fit_outcome_model$modelType,
        cached_outcome_model$modelType
      ),
      stratified = isTRUE(cached_outcome_model$stratified %||% default_analytic_settings$fit_outcome_model$stratified)
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
    cat("     In the current stage, the shell shows the section flow and keeps the current defaults.\n")
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
    effective_analytic_settings$profile_name <- if (isTRUE(interactive)) {
      prompt_non_null_text(
        "Analytic settings profile name",
        default = effective_analytic_settings$profile_name
      )
    } else {
      effective_analytic_settings$profile_name
    }

    if (isTRUE(interactive)) {
      cat("\nAnalytic settings mode: step-by-step\n")
      cat("The shell will walk through the required sections. Detailed prompts inside each section are TODO for now, so the current defaults will be kept.\n")
      for (section_name in analytic_settings_section_flow) {
        section_label <- switch(
          section_name,
          study_population = "Study population settings",
          time_at_risk = "Time-at-risk settings",
          propensity_score_adjustment = "Propensity score adjustment settings",
          outcome_model = "Outcome model settings",
          section_name
        )
        cat(sprintf("\n[%s]\n", section_label))
        cat("TODO: Detailed section-specific prompts will be implemented in a later step. Keeping the current defaults for this section.\n")
      }
    }

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
    source = "manual_input",
    study_intent = studyIntent,
    target_statement = sprintf("TODO via ACP phenotype_intent_split. Manual target cohort: %s (%s).", target_name, targetCohortId),
    comparator_statement = sprintf("TODO via ACP comparator recommendation. Manual comparator cohort: %s (%s).", comparator_name, comparatorCohortId),
    outcome_statement = sprintf(
      "TODO via ACP phenotype recommendation. Manual outcomes: %s.",
      paste(sprintf("%s (%s)", outcome_names, outcomeCohortIds), collapse = "; ")
    )
  )
  write_json(manual_intent, manual_intent_path)

  manual_inputs <- list(
    study_intent = studyIntent,
    comparison_label = comparisonLabel,
    target_cohort_id = as.integer(targetCohortId),
    comparator_cohort_id = as.integer(comparatorCohortId),
    outcome_cohort_ids = as.integer(outcomeCohortIds),
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
    status = "todo",
    acp = list(
      phenotype_intent_split = "TODO",
      phenotype_recommendation = "TODO",
      phenotype_recommendation_advice = "TODO",
      phenotype_improvements = "TODO",
      cohort_methods_specifications_recommendation = "STUB_CALLED_FROM_R_SHELL"
    ),
    mcp = list(
      comparator_setting_reuse = "TODO",
      phenotype_index_search = "TODO"
    ),
    note = "This shell currently uses manual cohort IDs and local phenotype index artifacts only."
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
    match_on_ps = effective_analytic_settings$match_on_ps,
    fit_outcome_model = effective_analytic_settings$fit_outcome_model,
    covariate_concept_sets = effective_analytic_settings$covariate_concept_sets
  )
  cm_defaults$covariate_concept_sets$enabled <- isTRUE(effective_analytic_settings$covariate_concept_sets$enabled)
  cm_defaults$covariate_concept_sets$note <- "Placeholder only. Dummy concept set IDs are captured for future concept set materialization."
  cm_defaults$get_db_cohort_method_data$removeDuplicateSubjects <- as.character(cm_defaults$get_db_cohort_method_data$removeDuplicateSubjects)
  cm_defaults$create_study_population$removeDuplicateSubjects <- as.character(cm_defaults$create_study_population$removeDuplicateSubjects)
  write_json(cm_defaults, cm_defaults_path)

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
    "matchDefaults <- defaults$match_on_ps",
    "outcomeModelDefaults <- defaults$fit_outcome_model",
    "covariateConceptDefaults <- defaults$covariate_concept_sets %||% list()",
    "comparison_payload <- jsonlite::fromJSON(file.path(output_dir, 'cm_comparisons.json'), simplifyVector = FALSE)",
    "comparisons <- comparison_payload$comparisons %||% list()",
    "if (length(comparisons) == 0) stop('No comparisons found in cm_comparisons.json')",
    "comparison <- comparisons[[1]]",
    "analyticSettingsProfile <- defaults$profile_name %||% 'Propensity score matching'",
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
    "riskWindowStart <- studyPopulationDefaults$riskWindowStart %||% 1L",
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
    "  covariateSettings = covariateSettings",
    ")",
    "createStudyPopulationArgs <- CohortMethod::createCreateStudyPopulationArgs(",
    "  removeDuplicateSubjects = studyPopulationDefaults$removeDuplicateSubjects,",
    "  removeSubjectsWithPriorOutcome = studyPopulationDefaults$removeSubjectsWithPriorOutcome,",
    "  priorOutcomeLookback = studyPopulationDefaults$priorOutcomeLookback,",
    "  riskWindowStart = studyPopulationDefaults$riskWindowStart,",
    "  startAnchor = studyPopulationDefaults$startAnchor,",
    "  riskWindowEnd = studyPopulationDefaults$riskWindowEnd,",
    "  endAnchor = studyPopulationDefaults$endAnchor,",
    "  censorAtNewRiskWindow = studyPopulationDefaults$censorAtNewRiskWindow",
    ")",
    "createPsArgs <- CohortMethod::createCreatePsArgs(",
    "  estimator = psDefaults$estimator,",
    "  maxCohortSizeForFitting = psDefaults$maxCohortSizeForFitting",
    ")",
    "matchOnPsArgs <- CohortMethod::createMatchOnPsArgs(",
    "  caliper = matchDefaults$caliper,",
    "  caliperScale = matchDefaults$caliperScale,",
    "  maxRatio = matchDefaults$maxRatio",
    ")",
    "fitOutcomeModelArgs <- CohortMethod::createFitOutcomeModelArgs(",
    "  modelType = outcomeModelDefaults$modelType,",
    "  stratified = outcomeModelDefaults$stratified",
    ")",
    "",
    "cmAnalysisList <- list(",
    "  CohortMethod::createCmAnalysis(",
    "    analysisId = as.integer(defaults$analysis_id %||% 1L),",
    "    description = analyticSettingsProfile %||% comparison$label %||% 'Default cohort method analysis',",
    "    getDbCohortMethodDataArgs = getDbCohortMethodDataArgs,",
    "    createStudyPopulationArgs = createStudyPopulationArgs,",
    "    createPsArgs = createPsArgs,",
    "    matchOnPsArgs = matchOnPsArgs,",
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
    "    concept_set_selections_path = file.path(output_dir, 'cm_concept_set_selections.json'),",
    "    negative_control_concept_set_id = negativeControlConceptSet$concept_set_id %||% NULL,",
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
    cohort_csv = cohort_csv,
    state = state_path
  ))
}
