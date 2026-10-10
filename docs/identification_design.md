# Identification illustration: design and assumptions

This is a retrospective design note for a conceptual and formal paper. Earlier
results and data were available when the illustration was selected. It is not a
preregistration, an independent replication, or a new format-effect experiment.

## Estimand and claim sequence

The target is the prevalence of confidently held false belief about a specified
proposition immediately before exposure to a format and its cues. The five-state
model distinguishes confident true belief, tentative true belief, no relevant
stored belief, tentative false belief, and confident false belief. It assumes a
substantive confidence threshold and a defensible proposition key. Ambivalence
may require additional states.

1. Responses can arise through more than one premeasurement state.
2. Random assignment identifies format-specific response distributions and gives
   a common premeasurement composition in the respondent population.
3. Unknown response channels leave that composition unrestricted.
4. Calibrated channels identify a composition or functional when the relevant
   rank or row-space condition holds; individual classification need not follow.
5. Bounded channel errors give sharp prevalence intervals; the bounds become
   informative only when the restrictions exclude some response processes.
6. Multiple formats can narrow these intervals or contradict their joint assumptions.

These are applications of established identification methods. The contribution
is their connection to the substantive distinction between stored misinformation,
tentative belief, ignorance, and responses generated during measurement.

## Illustration choice and shared data

Use the March 2017 ACA1 battery and the false proposition
`m_aca_single_payer`: the ACA replaces private health insurance with a single-payer
system. The [CMS marketplace overview](https://www.cms.gov/marketplace/about/overview-exchanges)
describes ACA markets as private health insurance markets. This was selected for its direct literal key and availability in both
formats, not as an item expected to validate an error cap. It superseded the
broader immigration-coverage statement considered during design, before the new
illustration's effect estimates were inspected. No numerical cap is called plausible
on the basis of this comparison.

The MC event is selection of the named single-payer option. The scale event is a
rating of 10 for that proposition. Do not interpret an unselected option as
rejection, a DK as ignorance, or a midpoint as calibrated probability or absence
of stored belief. Retain assigned-arm denominators and missing counts.

The sample is a convenience sample. The same source data support the neighboring
Hidden Knowledge project. Format/scoring effects and partisan-gap comparisons
are already studied in neighboring repositories; this manuscript uses the data
to expose the assumptions needed for a cognitive interpretation.

## Restrictions and inference

For each arm, let `f` be the positive-response probability among people without
stored misinformation, and `s` the positive-response probability among those
with it. Restrict `f <= alpha` and `1-s <= beta`. The error directions can differ
between arms; only their chosen caps are shared in the displayed diagonal.

Evaluate the full Cartesian grid `alpha,beta = 0,.05,...,1`; display equal-cap
scenarios 0, .05, .10, .20, .50, 1 and the diagonal figure. The unrestricted case
must yield [0,1]. Empty intersections are reported explicitly. Widening caps
cannot narrow a feasible identified set. No assumption that alpha + beta < 1 is
needed. No prior, preferred cap, national weight, causal engagement estimate,
learning model, or latent response-class estimate supplies identification here.

Construct two admissible channel models with prevalence `min(q)/2` and
`(1+max(q))/2`. These are witnesses to observational equivalence, not fitted
belief shares. With missing responses the construction uses the midpoint of the
response-probability interval; actual illustration counts have no missing outcomes.

For sampling uncertainty, assume independent within-arm draws from the
respondent population. For two fully observed arms use 97.5% two-sided
Clopper–Pearson intervals, giving at least 95% simultaneous coverage by
Bonferroni. With missing outcomes, use a lower one-sided bound on observed
positives and an upper one-sided bound on positives-or-missing in each arm;
allocate 1.25% tail probability to each of the four limits. Propagate these
probability bounds through the sharp formulas. These are conservative outer
confidence sets under the channel restrictions, not design-exact randomization
intervals or uncertainty about the truth key or error caps.

The joint-rating table cross-classifies endpoint endorsement of the battery's
keyed true statement and any keyed false statement, on complete batteries.
Report exclusions. These observable patterns do not establish person-level
cognitive types. The single-proposition bounds use only the single-payer key.

## Validation and implementation

`R/identification.R` implements the closed-form binary bounds and a finite-state
joint-mass linear program. The latter validates every stochastic channel column,
even for zero-mass states. It supports bounds on state shares or sums of shares;
its response-margin intervals must admit a distribution. Solver infeasibility is
reported separately from unsupported solver failure.

Tests compare the LP with the analytic bounds, check known-channel recovery,
nonidentification, domain boundaries, invalid columns, empty intersections,
restriction widening, missing outcomes, and observational-equivalence witnesses.
Actual event counts are checked against survey records. The manuscript includes
proofs; an independent mathematical review additionally compared binary formulas
with LP solutions in 900 random one-, two-, and three-arm cases, with maximum
endpoint discrepancy zero.

The full `make check` retains all prior analysis and reconstruction tests. Review
also checks prose against generated output and inspects every rendered PDF page.

Primary references: [Molinari's working paper](https://cae.economics.cornell.edu/05-10.pdf),
[Tamer's review](https://www.annualreviews.org/content/journals/10.1146/annurev.economics.050708.143401),
[Allman, Matias, and Rhodes](https://arxiv.org/pdf/0809.5032).
API references: [lpSolve](https://cran.r-project.org/web/packages/lpSolve/lpSolve.pdf),
[R binomial intervals](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/binom.test.html).
