#' Suggest cohort method study specifications from a free-text description.
#'
#' Calls the ACP flow `/flows/cohort_methods_specifications_recommendation`
#' and returns the cohort-methods recommendation, full analysis spec for
#' traceability, and per-section rationales. Falls back to a local stub
#' when `acp_state$url` is NULL.
#'
#' @param analyticSettingsDescription free-text description of the study design
#' @param targetCohortId optional integer cohort ID for the target arm
#' @param comparatorCohortId optional integer cohort ID for the comparator arm
#' @param outcomeCohortIds optional integer vector of outcome cohort IDs
#' @param comparisonLabel optional comparison label string
#' @param defaultsSnapshot optional list mirroring `effective_analytic_settings`
#' @param studyIntent optional protocol context string
#' @param interactive when TRUE, prints a section summary (default: TRUE)
#' @return list response from ACP flow or local stub
#' @export
suggestCohortMethodSpecs <- function(analyticSettingsDescription,
                                     targetCohortId = NULL,
                                     comparatorCohortId = NULL,
                                     outcomeCohortIds = NULL,
                                     comparisonLabel = NULL,
                                     defaultsSnapshot = NULL,
                                     studyIntent = NULL,
                                     interactive = TRUE) {
  if (is.null(analyticSettingsDescription) || !nzchar(trimws(analyticSettingsDescription))) {
    stop("Provide a non-empty analyticSettingsDescription.")
  }

  body <- list(
    analytic_settings_description = analyticSettingsDescription,
    study_description             = analyticSettingsDescription,
    study_intent                  = studyIntent %||% "",
    target_cohort_id              = if (is.null(targetCohortId)) NULL else as.integer(targetCohortId),
    comparator_cohort_id          = if (is.null(comparatorCohortId)) NULL else as.integer(comparatorCohortId),
    outcome_cohort_ids            = if (is.null(outcomeCohortIds)) list() else as.list(as.integer(outcomeCohortIds)),
    comparison_label              = comparisonLabel,
    defaults_snapshot             = defaultsSnapshot %||% list()
  )

  res <- if (!is.null(acp_state$url)) {
    .acp_post("/flows/cohort_methods_specifications_recommendation", body)
  } else {
    local_cohort_method_specs(body)
  }

  if (isTRUE(interactive)) {
    cat("\n== Cohort Method Specifications ==\n")
    cat("Status:", res$status %||% "(missing)", "\n")
    rec <- res$recommendation %||% list()
    if (length(rec) > 0) {
      cat("Profile:", rec$profile_name %||% "(none)", "\n")
      cat("Recommendation status:", rec$status %||% "(none)", "\n")
    }
    rats <- res$section_rationales %||% list()
    if (length(rats) > 0) {
      for (section in names(rats)) {
        entry <- rats[[section]]
        cat(sprintf("  - %s: confidence=%s  %s\n",
                    section,
                    entry$confidence %||% "?",
                    entry$rationale %||% ""))
      }
    }
    failed <- res$diagnostics$failed_sections %||% list()
    if (length(failed) > 0) {
      cat("Backfilled sections:", paste(unlist(failed), collapse = ", "), "\n")
    }
  }
  invisible(res)
}

local_cohort_method_specs <- function(body) {
  list(
    status = "stub",
    recommendation = list(
      mode = "free_text",
      input_method = "typed_text",
      source = "local_stub_no_acp",
      status = "stub",
      profile_name = "Recommended from free-text description (stub)",
      raw_description = body$analytic_settings_description %||% "",
      study_population = list(),
      time_at_risk = list(),
      propensity_score_adjustment = list(),
      outcome_model = list(),
      deferred_inputs = list(
        function_argument_description = "implemented",
        description_file_path = "implemented",
        interactive_typed_description = "implemented"
      ),
      defaults_snapshot = body$defaults_snapshot %||% list()
    ),
    theseus_specifications = list(),
    section_rationales = list(),
    diagnostics = list(
      source = "local_stub_no_acp",
      reason = "acp_state$url is NULL; call acp_connect(url) first."
    ),
    request = body
  )
}
