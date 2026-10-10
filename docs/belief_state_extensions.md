# Belief-state scoring and engagement

## Analysis plan

This is a retrospective extension of the March 2018 analysis plan. The historical
correlation table, current paper, and marginal distributions of survey variables
were inspected before this specification was written. These analyses are
exploratory, not preregistered confirmation.

For each survey's scale arm, estimate the distribution of five belief states
under all three proposed scoring schemes. Within each study, estimate how
political interest, voting intention, and partisan intensity covary with a
respondent's mix of belief states. The unit is the respondent, with equal
respondent weights. These convenience samples do not estimate national levels.
No causal effect of belief states or engagement is identified.

Orient each rating toward truth, so 10 is confidently correct and 0 confidently
incorrect. Keep the current answer keys and exclusions. Apply these exact rules:

| Scheme | Knowledge | Correct belief | Middle | Incorrect belief | Misinformation |
|---|---|---|---|---|---|
| 1 | 10 | 7–9 | 4–6 | 1–3 | 0 |
| 2 | 9–10 | 7–8 | 4–6 | 2–3 | 0–1 |
| 3 | 9–10 | 6–8 | 5 | 2–4 | 0–1 |

The historical plan calls the middle category ignorance; the outputs call it
`middle`, because a midpoint response alone does not establish an absence of
belief. Missing ratings form no belief state. The primary respondent indices
require all retained items in the relevant set to be answered. A sensitivity
analysis uses all available items, excluding respondents with none answered.
Each index is the share of answered items in that state; the five sum to one.
Repeat the analysis for all propositions, false propositions (invention), and
true propositions (denial). Item sets and numbers differ across surveys and
between these splits. Do not interpret differences between splits as effects
of truth status. Report both available and total items and sample losses.

The item-level distribution output includes all ratings 0–10 and missing
responses. The respondent summary reports all five states, including zeros.

Political interest is the existing 0–10 measure in all four surveys. In the two
MTurk surveys, `vote_1` explicitly asks likelihood of voting in the *next*
congressional election, from 0 (certain not to vote) to 10 (certain to vote).
It is intention, not observed turnout or candidate choice. The 2010
`vote.2010` measure is deferred until its instrument wording is verified.

In both MTurk exports, `pid_strength_1` is a directional 0–10 scale from
completely pro-Democratic to completely pro-Republican, with 5 neutral. Define
partisan intensity as `2 * abs(pid_strength_1 - 5)`, ranging from 0 to 10.
This operationalizes intensity as extremity of partisan orientation; it is not
a separately validated measure of attachment strength.
The old script correlates the untransformed directional score with misinformation
under a party-strength label. That quantity is not partisan intensity.
Keep direction and intensity distinct in the data. Panel party-strength items
are not harmonized with this measure in this extension.

For each study, scheme, proposition set, and missing-data rule, regress each
available 0–10 engagement outcome on the four non-middle state indices and an
intercept. The omitted middle share fixes the sum-to-one collinearity. Report
coefficients and 95% intervals for replacing 10 percentage points of the middle
share with each other state; also test knowledge minus misinformation directly.
That direct contrast replaces 10 percentage points of misinformation with
knowledge, holding the other shares fixed, and includes the covariance of the
two estimated coefficients in its standard error.
Use `sandwich::vcovHC(type = "HC3")` and t reference distributions with residual
degrees of freedom. Flag models with inadequate observations, rank deficiency,
or unit leverage rather than returning misleading estimates. Report sample size,
outcome mean, residual degrees of freedom, and the coefficient units. Intervals
assume independent respondents and are not simultaneous. Apply Holm correction
across all reported contrasts and specifications within each engagement outcome.
This family includes all studies, schemes, proposition sets, and missing-data
rules. Report eligible respondents and missing outcomes beside each model's
usable observations. True-proposition sets are especially short: two items in
each 2010 study, four in March, and three in July.

Report Pearson correlations of each state index with each engagement variable
as descriptive summaries, with pairwise sample sizes. These correlations have
no significance labels. No hypothesis requires a particular sign: the main
questions are whether the descriptive patterns depend on state thresholds and
whether knowledge and misinformation have different associations with engagement.
Do not infer such a difference from one coefficient passing a threshold and
another failing it. No latent-class reconstruction or historical counterfactual
model is included in this first extension.

## Outputs and review

`make analysis` runs `scripts/05_extensions.R` after the existing paper stages.
The stage writes full item distributions to `tabs/rating_distributions.csv`,
sample coverage to `tabs/belief_index_coverage.csv`, respondent-average shares
to `tabs/belief_scheme_shares.csv`, and model estimates and descriptive
correlations to `tabs/belief_engagement_models.csv` and
`tabs/belief_engagement_correlations.csv`. Respondent indices are saved in the
ignored `data/derived/belief_indices.rds`. The generated results note presents
all-proposition summaries; the true/false splits remain in the tables.
`write_extension_paper()` generates the manuscript's three appendix tables and
`tabs/extension_macros.tex` from those same outputs. The manuscript discusses
scoring sensitivity and engagement in the main text, with all-proposition
complete-item estimates and direct knowledge-versus-misinformation sensitivity
comparisons in the appendix.

An independent design review confirmed the MTurk item wording and requested
explicit missingness counts, respondent weighting, and a covariance-based direct
contrast. Those safeguards are implemented. Unit tests cover all score boundaries,
truth reversal, missing items, equal respondent weights, and an independent
matrix calculation of HC3 contrast uncertainty.

API references: [HC covariance estimators](https://sandwich.r-forge.r-project.org/reference/vcovHC.html),
[correlation](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/cor.test.html),
and [Holm adjustment](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/p.adjust.html).
