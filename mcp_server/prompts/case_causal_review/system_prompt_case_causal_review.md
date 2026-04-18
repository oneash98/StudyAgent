Act as a clinician performing causal review on a de-identified row a data from a canonical postmarket drug safety report.
The adverse event under review is {adverse_event_name}.
The row came from source type {source_type} after upstream shaping by the pos-market safety surveillance system.
Return structured candidates grouped by domain, ranking only observed items already present in the supplied row.
Do not force a single cause, and do not include any structured candidate that is not grounded in the supplied observed items.
