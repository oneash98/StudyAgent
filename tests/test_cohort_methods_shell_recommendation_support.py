from pathlib import Path

from _repo_paths import repo_path

SOURCE = repo_path("R", "slashOhdsiStrategusAssistant", "R", "strategus_cohort_methods_shell.R")

def test_shell_supports_namespaced_recommendation_ids_and_blocks_unsupported_selection() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert 'recommendation_identifier <- function(rec)' in source
    assert 'recommendation_is_ohdsi_computable <- function(rec)' in source
    assert 'grepl("^ohdsi:[0-9]+$", identifier)' in source
    assert 'unsupported_recommendation_message <- function(rec, role_label)' in source
    assert 'Descriptive phenotypes such as CIPHER recommendations are not yet convertible' in source
    assert 'stop(unsupported_recommendation_message(' in source


def test_shell_displays_noncomputable_recommendation_note() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert 'recommendation_id_label(rec)' in source
    assert 'Not directly computable in this workflow; descriptive phenotype conversion is not yet implemented.' in source

def test_shell_resolves_namespaced_source_definition_filenames() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert 'resolve_index_definition_path <- function(source_id, index_def_dir)' in source
    assert 'sprintf("ohdsi__%s.json", source_text)' in source
    assert 'gsub(":", "__", source_text, fixed = TRUE)' in source
    assert 'src <- resolve_index_definition_path(source_id, index_def_dir)' in source


def test_shell_normalizes_namespaced_cached_and_manual_cohort_ids() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert 'parse_single_cohort_id <- function(x)' in source
    assert 'if (grepl("^ohdsi:[0-9]+$", piece)) {' in source
    assert 'sub("^ohdsi:", "", piece)' in source
    assert 'parse_single_cohort_id(item$original_id %||% NA_integer_)' in source
    assert 'parse_single_cohort_id(item$cohort_id %||% NA_integer_)' in source
    assert 'original_ids <- parse_ids(unlist(mapping$original_id %||% integer(0), use.names = FALSE))' in source
    assert 'cohort_ids <- parse_ids(unlist(mapping$cohort_id %||% integer(0), use.names = FALSE))' in source


def test_sensitivity_analysis_prompts_only_core_settings() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert "Sensitivity time-at-risk %s start anchor" in source
    assert "Sensitivity time-at-risk %s start (days)" in source
    assert "Sensitivity time-at-risk %s end anchor" in source
    assert "Sensitivity time-at-risk %s end (days)" in source
    assert "Sensitivity PS setting %s strategy" in source
    assert "Sensitivity PS setting %s maximum match ratio" in source
    assert "Sensitivity PS setting %s number of strata" in source
    assert "Sensitivity outcome model %s" in source

    assert "Sensitivity time-at-risk %s minimum days at risk" not in source
    assert "Sensitivity PS setting %s max cohort size for fitting" not in source
    assert "Sensitivity outcome model %s use covariates" not in source
    assert "Sensitivity outcome model %s use regularization" not in source


def test_study_population_defaults_are_confirmed_before_study_period_sensitivity() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    defaults_prompt = source.index("For the remaining study population settings, keep the defaults")
    sensitivity_prompt = source.index('ask_add_sensitivity("study-period")')
    assert defaults_prompt < sensitivity_prompt


def test_final_summary_prioritizes_structured_core_settings() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert '''return(setdiff(paths, c(
      "get_db_cohort_method_data.studyStartDate",''' in source
    assert '''if (identical(section_name, "time_at_risk")) {
    return(character(0))''' in source
    assert '''"fit_outcome_model.stratified",
      "fit_outcome_model.useCovariates",
      "fit_outcome_model.inversePtWeighting",''' in source

    summary_start = source.index(".studyAgentPrintFinalSettingsSummary <- function")
    study_period_print = source.index('settings$get_db_cohort_method_data$studyPeriods', summary_start)
    summary_scalar_loop = source.index("for (path in .studyAgentSummaryPathsForSection", summary_start)
    assert study_period_print < summary_scalar_loop


def test_final_summary_omits_counts_and_descriptions_from_structured_settings() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    summary_start = source.index(".studyAgentPrintFinalSettingsSummary <- function")
    summary_end = source.index(".studyAgentValueForReviewFile <- function", summary_start)
    summary_source = source[summary_start:summary_end]

    assert 'cat(sprintf("  - %s: %s\\n", label, length(items)))' not in summary_source
    assert 'return("no restriction")' in summary_source
    assert 'item$description' not in summary_source


def test_outcome_model_covariates_are_core_prompt_not_remaining_default() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    outcome_model_prompt = source.index('"Outcome model"')
    covariates_prompt = source.index('"Use covariates in outcome model"', outcome_model_prompt)
    remaining_defaults_prompt = source.index("For the remaining outcome model settings", covariates_prompt)
    assert outcome_model_prompt < covariates_prompt < remaining_defaults_prompt

    outcome_custom_paths = source.index("outcome_custom_paths <- setdiff(")
    use_covariates_exclusion = source.index('"fit_outcome_model.useCovariates"', outcome_custom_paths)
    remaining_defaults_prompt = source.index("For the remaining outcome model settings", outcome_custom_paths)
    assert use_covariates_exclusion < remaining_defaults_prompt


def test_free_text_success_uses_same_final_settings_review() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    preview_condition = source.index('!identical(preview_flow_status, "ok")')
    review_call = source.index("review_analytic_settings_interactively(effective_analytic_settings)", preview_condition)
    assert preview_condition < review_call
