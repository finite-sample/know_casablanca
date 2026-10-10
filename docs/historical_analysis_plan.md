# Reconstructing the unfinished Casablanca analyses

This retrospective plan extends the 2018 analysis requests. Earlier manuscript
results, archived scripts, variable distributions, and historical tables were
available when it was written. All additions are exploratory. The original
files remain unchanged; repairs belong in the maintained pipeline.

## Four-survey correlates

Recover the available demographics, ideological identification, party strength,
and voting measures from the questionnaires and exports. Join supplementary
2010 demographics by respondent identifier only after resolving identical
records and identifying conflicting values. Preserve missingness; report linkage
coverage. Do not infer candidate choice from voting intention, or an individual's
"correct" vote from party identification.

For each study, scoring scheme, true/false/all proposition set, and
complete/available-item rule, describe the five respondent indices against the
verified covariates. Use Pearson correlations for numeric scales, with paired
sample sizes, and category-specific means for nominal variables. Education
categories are ordered labels, not years of schooling. These summaries describe
respondents in each sample, with equal respondent weights. They do not estimate
national distributions or causal effects. Use the existing HC3 engagement model
for any newly verified 0–10 voting measure; keep the original engagement family
unchanged and adjust new comparisons separately, clearly labeled.

## Historical response models

Reconstruct correct/incorrect/DK distributions, knowledge means by response,
and Republican-minus-Democratic response gaps from the archived cross-survey
sources. Keep "same" separate where the original four-category variables exist;
combine it with incorrect only in the historical three-category specification.
Retain explicit DK answers, exclude genuinely missing responses, and report both
counts. Historical answer keys are inherited and documented, not independently
validated confidence measures.

Rebuild the eleven three-category multinomial models with named data columns,
knowledge, three-category party identification, and their interaction; set party
to Independent for the neutral scenario. Also rebuild the eight four-category
ANES models with knowledge, partisan affect, and their interaction. Evaluate observed-covariate predictions
and predictions setting partisan affect to neutrality or knowledge to zero.
Average predicted probabilities, retain modal-class proportions for comparison
with the historical approach, and test that new data actually change predictions.
Report extrapolation beyond observed predictor support. These are conditional
model scenarios, not causal interventions or identified cognitive states.
Use unweighted descriptive reconstructions where archived survey design fields
are absent or not harmonized; do not describe them as population estimates.

## Latent response classes

The archived single-item mixture cannot separately identify informed,
misinformed, and guessing respondents. Check this explicitly by comparing
observable dimensions with model parameters, and preserve this limitation.
As a separate exploratory extension, fit locally independent response-class
models to the three historical four-category items in ANES 1988 and 2008.
Fit one, two, and three classes on the same complete-item respondents, with no
covariates; initially use 20 random starts, a fixed seed, a 10,000-iteration limit, and
log-likelihood tolerance 1e-8. Compare BIC and AIC, report repeated-start
agreement, boundary probabilities, sample loss, and discrepancies between fitted
and observed joint distributions. Label classes by their response profiles,
not as knowledge, misinformation, or guessing. A class model fitting response
patterns does not validate those cognitive interpretations. No confirmatory
significance tests or class-share causal claims are planned.

## Validation and reporting

Keep generated numbers, sample accounting, diagnostics, and comparisons with
saved outputs together. Test the known missing-response and counterfactual
failures with synthetic data, verify real-data counts independently, and run the
full local checks. Incorporate supported findings and their limitations in the
manuscript and generated appendices. Record unavailable measures and unresolved
historical inputs explicitly rather than substituting another construct.

Implementation references: [multinomial models](https://stat.ethz.ch/R-manual/R-devel/library/nnet/html/multinom.html),
[latent classes](https://search.r-project.org/CRAN/refmans/poLCA/html/poLCA.html).

## Refinements after source review

The panel voting measure is verified and analyzed in a separate multiplicity
family. BTP includes a leave-target-out knowledge sensitivity; NIC uses post-wave
knowledge and a baseline response. The two 2004 economic keys have an explicit
annual-indicator benchmark sensitivity. Model intervals are conditional,
model-based delta-method normal intervals. Details and source limitations are
recorded in [recovered measures](recovered_measures.md).

The initial 1988 three-class fit reached its best likelihood in only two of
twenty starts. Final models use 100 starts to check optimization stability;
the one-class independence model has a single analytical solution.

Review of the original 1992 ANES file revealed that archived derived responses
collapsed some unasked/missing cases into DK, and that archived party
identification came from 1990. The final reconstruction restores original
response missingness and reports both the archived party grouping and a
contemporary 1992 grouping, with explicit specification identifiers.
