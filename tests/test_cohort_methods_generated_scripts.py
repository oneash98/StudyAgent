from pathlib import Path
import shutil
import subprocess

import pytest

from _repo_paths import repo_path


SOURCE = repo_path("R", "slashOhdsiStrategusAssistant", "R", "strategus_cohort_methods_shell.R")
CODEGEN_SOURCE = repo_path("R", "slashOhdsiStrategusAssistant", "R", "cohort_methods_codegen.R")
EXECUTION_SETTINGS_SOURCE = repo_path("R", "slashOhdsiStrategusAssistant", "R", "execution_settings.R")

def _generated_script_block(source: str, script_name: str, filename: str) -> str:
    start = source.index(f"{script_name} <- c(")
    end = source.index(f'write_lines(file.path(scripts_dir, "{filename}")', start)
    return source[start:end]


def _run_r_or_skip(expression: str) -> subprocess.CompletedProcess[str]:
    if shutil.which("Rscript") is None:
        pytest.skip("Rscript is not available")
    result = subprocess.run(
        ["Rscript", "-e", expression],
        check=False,
        text=True,
        capture_output=True,
    )
    if result.returncode == 42:
        pytest.skip(result.stderr.strip() or result.stdout.strip() or "required R package is not available")
    return result


def test_generated_cm_spec_builds_and_executes_strategus_analysis_specification() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    codegen = CODEGEN_SOURCE.read_text(encoding="utf-8")

    assert "script_06 <- .studyAgentBuildCohortMethodsSpecScript(" in source
    assert "analysisSpecification.json" in codegen
    assert "CharacterizationModule$new()" in codegen
    assert "CohortIncidenceModule$new()" in codegen
    assert "CohortMethodModule$new()" in codegen
    assert "CohortGeneratorModule$new()" in codegen
    assert "CohortDiagnosticsModule$new()" not in codegen
    assert "cohortGeneratorModuleSpecifications" not in codegen
    assert "cohortDiagnosticsModuleSpecifications" not in codegen
    assert "target_id <- as.numeric(" in codegen
    assert "outcome_ids <- vapply(" in codegen
    assert "numeric(1)" in codegen
    assert "outcomeIds = as.numeric(outcome_ids)" in codegen
    assert "outcomeWashoutDays = as.numeric(" in codegen
    assert "call_with_supported_args <- function(" not in codegen
    assert "formals(" not in codegen
    assert ".studyAgentEmitCmAnalysisListBlocks(cmAnalysis)" in codegen
    assert 'blocks <- c("cmAnalysisList <- list()")' in codegen
    assert '"cmAnalysisList[[%s]] <- %s"' in codegen
    assert "CohortMethod::createCreateStudyPopulationArgs(" in codegen
    assert '"    removeSubjectsWithPriorOutcome = %s,"' in codegen
    assert "useRegularization =" not in codegen
    assert ".studyAgentEmitCmPrior(fit_args$prior" in codegen
    assert "createStudyPopArgs" in codegen
    assert '"  createStudyPopulationArgs ="' in codegen
    assert "cmAnalysesSpecifications = cmAnalysesSpecifications$toList()" in codegen
    assert "ParallelLogger::saveSettingsToJson(analysisSpecifications, analysis_spec_path)" in codegen
    assert "result <- Strategus::execute(" in codegen
    assert "connectionDetails <- slashOhdsiStrategusAssistant::createStrategusConnectionDetails(path = db_details_path)" in codegen
    assert "exec <- slashOhdsiStrategusAssistant::createStrategusExecutionSettings(path = execution_settings_path)" in codegen
    assert "CohortMethod::runCmAnalyses(" not in codegen
    assert "CohortMethod::loadCmAnalysisList(" not in codegen
    assert "CohortMethod::loadTargetComparatorOutcomesList(" not in codegen


def test_cm_runner_is_merged_into_script_06() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert "script_07 <- c(" not in source
    assert 'write_lines(file.path(scripts_dir, "07_cm_run_analyses.R")' not in source
    assert 'cat("  - 07_cm_run_analyses.R\\n")' not in source


def test_characterization_spec_accepts_generated_numeric_types() -> None:
    result = _run_r_or_skip(
        """
        if (!requireNamespace('Strategus', quietly = TRUE) ||
            !requireNamespace('Characterization', quietly = TRUE)) quit(status = 42)
        library(Strategus)
        `%||%` <- function(x, y) if (is.null(x)) y else x
        module <- CharacterizationModule$new()
        spec <- module$createModuleSpecifications(
          targetIds = as.numeric(c(1, 2)),
          outcomeIds = as.numeric(c(3)),
          limitToFirstInNDays = as.numeric(c(99999, 99999)),
          minPriorObservation = as.numeric(365),
          outcomeWashoutDays = as.numeric(c(99999)),
          riskWindowStart = as.numeric(0),
          startAnchor = 'cohort start',
          riskWindowEnd = as.numeric(0),
          endAnchor = 'cohort end',
          mode = 'CohortIncidence'
        )
        stopifnot(length(spec) > 0)
        """
    )
    assert result.returncode == 0, result.stderr


def test_execution_settings_falls_back_when_max_cores_is_na() -> None:
    result = _run_r_or_skip(
        f"""
        if (!requireNamespace('Strategus', quietly = TRUE) ||
            !requireNamespace('CohortGenerator', quietly = TRUE)) quit(status = 42)
        library(Strategus)
        library(CohortGenerator)
        source('{EXECUTION_SETTINGS_SOURCE.as_posix()}')
        exec <- createStrategusExecutionSettings(settings = list(
          cdmDatabaseSchema = 'cdm',
          workDatabaseSchema = 'work',
          resultsDatabaseSchema = 'results',
          vocabularyDatabaseSchema = 'vocab',
          cohortTable = 'cohort',
          workFolder = tempdir(),
          resultsFolder = tempdir(),
          maxCores = NA
        ))
        stopifnot(identical(exec$maxCores, 1L))
        stopifnot(exec$executionSettings$maxCores == 1)
        """
    )
    assert result.returncode == 0, result.stderr


def test_cm_analysis_emitter_expands_generated_blocks() -> None:
    result = _run_r_or_skip(
        f"""
        source('{CODEGEN_SOURCE.as_posix()}')
        cmAnalysis <- list(
          getDbCohortMethodDataArgs = list(
            studyPeriods = list(
              list(description = 'Primary', studyStartDate = '', studyEndDate = ''),
              list(description = 'Sensitivity', studyStartDate = '20060101', studyEndDate = '20251231')
            ),
            firstExposureOnly = TRUE,
            removeDuplicateSubjects = 'keep first, truncate to second',
            restrictToCommonPeriod = TRUE,
            washoutPeriod = 365,
            maxCohortSize = 0
          ),
          createStudyPopArgs = list(
            removeSubjectsWithPriorOutcome = TRUE,
            priorOutcomeLookback = 99999,
            timeAtRisks = list(
              list(description = 'Primary TAR', minDaysAtRisk = 1, riskWindowStart = 0, startAnchor = 'cohort start', riskWindowEnd = 0, endAnchor = 'cohort end')
            ),
            censorAtNewRiskWindow = FALSE
          ),
          psSettings = list(
            list(description = 'No PS', trimByPsArgs = NULL, matchOnPsArgs = NULL, stratifyByPsArgs = NULL, inversePtWeighting = FALSE),
            list(description = '1:2 match', trimByPsArgs = NULL, matchOnPsArgs = list(maxRatio = 2, caliper = 0.2, caliperScale = 'standardized logit'), stratifyByPsArgs = NULL, inversePtWeighting = FALSE)
          ),
          createPsArgs = list(
            maxCohortSizeForFitting = 250000,
            errorOnHighCorrelation = FALSE,
            prior = list(priorType = 'laplace', useCrossValidation = TRUE),
            control = list(tolerance = 2e-7, cvType = 'auto', fold = 10, cvRepetitions = 10, noiseLevel = 'silent', resetCoefficients = TRUE, startingVariance = 0.01)
          ),
          fitOutcomeModelArgs = list(
            outcomeModels = list(list(description = 'Cox', modelType = 'cox', useCovariates = FALSE)),
            stratified = FALSE,
            prior = list(priorType = 'laplace', useCrossValidation = TRUE),
            control = list(tolerance = 2e-7, cvType = 'auto', fold = 10, cvRepetitions = 10, noiseLevel = 'quiet', resetCoefficients = TRUE, startingVariance = 0.01)
          )
        )
        blocks <- .studyAgentEmitCmAnalysisListBlocks(cmAnalysis)
        text <- paste(blocks, collapse = '\\n')
        stopifnot(grepl('cmAnalysisList <- list()', text, fixed = TRUE))
        stopifnot(length(grep('cmAnalysisList[[', strsplit(text, '\\n')[[1]], fixed = TRUE)) == 4)
        stopifnot(grepl('analysisId = 1', text, fixed = TRUE))
        stopifnot(grepl('analysisId = 4', text, fixed = TRUE))
        stopifnot(grepl('stratified = TRUE', text, fixed = TRUE))
        stopifnot(grepl('createStudyPopulationArgs =\\n  CohortMethod::createCreateStudyPopulationArgs', text, fixed = TRUE))
        stopifnot(grepl('cmAnalysisList <- createCohortMethodCmAnalysisList', text, fixed = TRUE) == FALSE)
        """
    )
    assert result.returncode == 0, result.stderr
