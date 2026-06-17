<Instruction>
From the provided <Text>, extract the key information to configure a population-level estimation study using the OMOP-CDM.
Leave any settings at their default values if they are not specified in the <Text>.
Refer to the fields and value types provided in the <Analysis Specifications Template> and do not add any additional fields.
For each field, refer to <JSON Fields Descriptions> to ensure accurate mapping of the relevant information from <Text> to the corresponding JSON structure.
Additional sensitivity analyses beyond the primary analysis may have also been conducted.
If the text describes multiple settings for a field (e.g., more than one timeAtRisk window), produce a separate entry for each setting within its corresponding array.
For each analytic settings section used by the R shell (study_population, time_at_risk, propensity_score_adjustment, outcome_model), provide a brief rationale and a confidence rating (high | medium | low).
Follow the <Output Style> exactly.
</Instruction>
