# Recovered measures and historical sources

## Four-survey measures

The 2010 questionnaire asks the likelihood of voting in the upcoming
congressional election on a 0–10 scale (physical page 16), and ideological
identification from liberal to conservative (page 8). It was recovered from
`finite-sample/know_hidden`, commit `f765098^`, path
`data/arep/survey_330455.pdf`, and is preserved in
[instruments/panel_2010.pdf](instruments/panel_2010.pdf).

Panel voting uses valid integers 0–10. Two out-of-range alumni entries, 50 and
90, occur outside the scale sample. Treating them as missing or applying the
older division-by-ten convention yields identical scale-sample analyses.
The new panel-voting models use a separate Holm family across all panel studies,
scoring schemes, proposition sets, missing-item rules, and five contrasts.
The earlier MTurk engagement family remains unchanged.

| Construct | Variables | Interpretation and missingness |
|---|---|---|
| Ideology | Panel `ideology` | Seven ordered liberal–conservative categories; unconsidered ideology and nonresponse are missing, not moderate |
| Party attachment | Panel `pid1`, `pid2.d`, `pid2.r` | Strong versus not very strong, only within the matching Democratic/Republican self-identification branch; others missing |
| Approximate age | Alumni intake `year`; staff `year.born`; MTurk `age` | Birth year subtracted from survey year; restrict resulting age to 18–110; not exact birthday-based age |
| Gender | Alumni intake `gender`; staff `sex`; MTurk `gender` | Preserve reported categories |
| Education | Alumni intake `educ`; staff `educ.s`; MTurk `educ` | Preserve study-specific categories; not years of education |
| Race/ethnicity | Alumni intake `ethnic`; staff checkbox fields; MTurk `race`, `hisla` | Multiple selections stay multiracial; all unchecked means missing. Alumni race and Hispanic ethnicity are combined, so categories are not harmonized across studies |
| Candidate choice | Not present in these four instruments | Neither `vote_1` nor Trump's perceived truthfulness (`djt_2`) is candidate choice; no measure establishes a "correct" vote |

Alumni demographics come from `know_hidden/data/raw/alumni_2010_demographics.csv`.
The importer retains only the identifier and fields used here. The original
intake report is preserved in [instruments/alumni_intake_2010.pdf](instruments/alumni_intake_2010.pdf),
recovered from the same Git commit at `data/arep/A-REP Demo Survey report (as of 8.2.10).pdf`.
Repeated IDs are collapsed field by field: retain a sole nonblank value; set
conflicting values to missing and record them in `tabs/demographic_conflicts.csv`.
Unknown race and the unresolved `#NAME?` export value are missing. Staff uses its
contemporaneous questionnaire rather than silently mixing intake and survey
responses. Every join asserts cardinality; coverage is generated in
`tabs/covariate_coverage.csv`.

## Historical response analyses

`scripts/import_archived_data.R` extracts only the fields needed for reconstruction.
`docs/historical_sources.csv` records original and extract hashes. The maintained
pipeline reads these extracts, so execution does not depend on another repository
or an untracked archive. Original files remain unchanged.

The core table contains GSS 2006 scientific consensus, NIC warming cause, BTP 2004
Iraq/9-11, and eight ANES items: 1988 inflation, unemployment, environment; 2000
deficit and crime; 2008 inflation, unemployment, inequality. Additional ANES 1988,
1992, 2000 and 2004 items reproduce the twenty-item partisan-retrospection scope.
ANES CSV and RData versions differ; final-script CSVs are used for 1988, 2000,
2004 and 2008, and RData for 1992. They must not be substituted interchangeably.

Historical `cor` means agreement with the archived answer key. It is not a
measure of confidence or proof of stored knowledge. Explicit DK responses remain
separate from missing/not-asked items. The archived 1992 recodes collapsed
some missing or unasked responses into DK. We recover the original ANES codes
V923527, V923529, V923531, V923533, and V923535 by matching the unique V923004
respondent ID. Codes 0 and 9 remain missing; only code 8 is explicit DK. Missing
counts are respectively 2, 1, 3, 178, and 178; explicit DK counts are 30, 40,
27, 48, and 39. The source DTA and extracted columns are hash-recorded.

The archived 1992 party variable comes from 1990 (V900320), with 500 Republicans,
710 Democrats, and 126 Independents. Alongside that historical specification,
we report contemporary 1992 identification (V923634: 0–2 Democrat, 3 Independent,
4–6 Republican; other codes missing), with 929 Republicans, 1,229 Democrats,
and 287 Independents. `party_basis` distinguishes the two specifications;
they are repeated analyses of the same respondents, not independent samples.
NIC's historical DK code specifically means "haven't thought much about this".
The 1988 inflation and unemployment items compare with 1980, not with the prior
year; similarly named items in other projects use different windows.

GSS knowledge averages twelve science items excluding the target. NIC knowledge
uses six post-wave items whereas the warming response is from baseline; its
association is not a contemporaneous knowledge gradient. BTP's archived knowledge
index includes the target Iraq/9-11 item. The new output reports both that index
and an eight-item index excluding the target, on explicit complete model samples.

All estimates are unweighted sample descriptions. Partisan-gap intervals use
independent-binomial standard errors. Multinomial scenario intervals use the
maximum-likelihood coefficient covariance and the delta method, conditional on
the observed sample covariates, with normal pointwise intervals. They do not
account for complex survey sampling, are not multiplicity-adjusted, and do not
identify effects of changing party or knowledge. Marginal-support flags do not
establish joint or conditional overlap. Mean predicted probabilities and modal
predicted-class proportions are reported separately.

## Answer-key sensitivity

The archived 2004 key calls worse unemployment and better inflation correct.
Official ANES variables V043101 and V043104 ask about the past year, with 125
respondents not asked because of a programming error. A separate benchmark
branch defines better unemployment and worse inflation as correct: unemployment
fell from 6.1% in September 2003 to 5.4% in September 2004, while twelve-month
CPI inflation increased from 2.3% to 2.5%. See the BLS releases for
[unemployment 2003](https://www.bls.gov/news.release/archives/empsit_10032003.pdf),
[unemployment 2004](https://www.bls.gov/news.release/archives/empsit_10082004.pdf),
[CPI 2003](https://www.bls.gov/news.release/archives/cpi_10162003.pdf), and
[CPI 2004](https://www.bls.gov/news.release/archives/cpi_10192004.pdf).
These are specified national-indicator benchmarks for the evaluation questions.
The outputs preserve the historical key alongside this sensitivity.

The 1992 inflation key remains labeled historical: the direction of the
change in twelve-month inflation depends on the interview month. A broad
"economy better/worse" item likewise needs an explicit economic benchmark;
this reconstruction does not silently equate it with GDP growth.

## Reconstruction differences

The old counterfactual formula referred to training-frame expressions, so new
covariate values were ignored. Named-column models repair this, and regression
tests require changed probabilities. Another historical routine wrote Democratic
incorrect-response counts into a Republican accumulator. Its residual category
therefore cannot be interpreted as observed ignorance. The maintained output
reports observed response categories and model probabilities directly rather
than assigning cognitive states from that heuristic.

The partisan-retrospection export swapped the 1992 "since July" (`m.econ4j`)
and "past year" (`m.econ1`) labels. Explicit item IDs prevent that swap. Five
ANES 2000 Independent-group cells disagree with the saved core table; Republican,
Democratic, and overall cells reproduce it. The available archive does not resolve
whether those five cells reflect a different subgroup version or transcription.
They are reported as discrepancies, not forced to match.

## Latent classes

A two-class model for one four-category item has seven free parameters but only
three observable response probabilities. It cannot identify separate cognitive
processes. The new multi-item models instead explore response patterns in the
three four-category ANES items in 1988 and 2008. One-, two-, and three-class
fits share the same complete-item respondents. BIC, repeated-start agreement,
boundary probabilities, and joint-distribution discrepancies are reported.
Classes are ordered by their mean probability of the archived correct response;
that ordering does not establish knowledge, misinformation, or guessing.
