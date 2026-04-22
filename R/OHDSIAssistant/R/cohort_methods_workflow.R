#' Suggest cohort method study specifications from a free-text description.
#'
#' Calls the ACP flow `/flows/cohort_methods_specifications_recommendation`
#' and returns a Theseus-shaped specification plus per-section rationales.
#' Falls back to a local stub when `acp_state$url` is NULL.
#'
#' @param analyticSettingsDescription free-text description of the study design
#' @param cohortDefinitions list with `targetCohort`, `comparatorCohort`, `outcomeCohort`
#' @param negativeControlConceptSet list with `id`, `name`
#' @param covariateSelection list with `conceptsToInclude`, `conceptsToExclude`
#' @param studyIntent optional protocol context string
#' @param currentSpecifications optional existing Theseus spec for iterative refinement
#' @param interactive when TRUE, prints a section summary (default: TRUE)
#' @return list response from ACP flow or local stub
#' @export
suggestCohortMethodSpecs <- function(analyticSettingsDescription,
                                     cohortDefinitions = NULL,
                                     negativeControlConceptSet = NULL,
                                     covariateSelection = NULL,
                                     studyIntent = NULL,
                                     currentSpecifications = NULL,
                                     interactive = TRUE) {
  if (is.null(analyticSettingsDescription) || !nzchar(trimws(analyticSettingsDescription))) {
    stop("Provide a non-empty analyticSettingsDescription.")
  }

  body <- list(
    analytic_settings_description = analyticSettingsDescription,
    study_intent = studyIntent %||% "",
    current_specifications = currentSpecifications,
    cohort_definitions = cohortDefinitions %||% list(),
    negative_control_concept_set = negativeControlConceptSet %||% list(),
    covariate_selection = covariateSelection %||% list()
  )

  res <- if (!is.null(acp_state$url)) {
    .acp_post("/flows/cohort_methods_specifications_recommendation", body)
  } else {
    local_cohort_method_specs(body)
  }

  if (isTRUE(interactive)) {
    cat("\n== Cohort Method Specifications ==\n")
    cat("Status:", res$status %||% "(missing)", "\n")
    rats <- res$sectionRationales %||% list()
    if (length(rats) == 0) {
      cat("  (no section rationales — likely a stub response)\n")
    } else {
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
    specifications = list(),
    sectionRationales = list(),
    diagnostics = list(
      source = "local_stub_no_acp",
      reason = "acp_state$url is NULL; call acp_connect(url) first."
    ),
    request = body
  )
}
