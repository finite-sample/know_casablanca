# The Waters of Casablanca: On Political Misinformation

Robert C. Luskin and Gaurav Sood

[Paper](ms/main.pdf) · [Data](data/README.md)

## Question and motivation

How can a survey distinguish a confidently held false belief from a guess?
Multiple-choice answers often count both as misinformation. The distinction
matters when estimating its prevalence and the partisan differences in it.
This paper separates misinformation from knowledge, mere belief, and ignorance,
and asks how definitely true or false each statement is on a 0–10 scale.

The companion study, [Misinformation about Misinformation?](https://github.com/finite-sample/know_misinfo_misinfo),
examines how the wording and response options in media polls affect these estimates.

## Data and research design

Four surveys of university alumni, university staff, and Mechanical Turk workers
randomly assigned respondents to multiple-choice items or a probability scale.
The analysis compares response formats within each survey and documents the
wording, answer keys, and excluded propositions. The convenience samples support
these within-sample comparisons; their prevalence estimates do not describe the
public as a whole.

## Key findings

The scale finds much less misinformation about prominent falsehoods than
multiple-choice answers suggest. Most ratings fall between the scale's ends.
Partisan differences remain in the expected direction, but they are smaller
when misinformation requires confidence in the false answer.

![Misinformation estimates by response format](figs/format.png)

Points show the share choosing an incorrect multiple-choice answer or the
false end of the scale, with 95% intervals. Panels separate the four surveys.
The lenient scale threshold is shown alongside the strict endpoint rule.

## Reproduce

```
make restore
make check
```

`make restore` installs the versions in `renv.lock`. `make check` runs the
analysis, builds the manuscript, lints the R code, and runs the tests.
`make analysis` runs stages 01–08 without compiling the manuscript.

The manuscript needs XeLaTeX and latexmk. Empirical estimates quoted in the text
come from generated macros in `tabs/macros.tex`, `tabs/extension_macros.tex`,
and `tabs/reconstruction_macros.tex`.

With Docker installed, `make ci-docker` runs the same checks in `rocker/verse:4.6.0`.

## Files and pipeline

| Path | Contents |
|---|---|
| `data/raw/` | The four survey files, anonymized; see [data/README.md](data/README.md) |
| `docs/propositions.csv` | Every statement, its key (true, false, or dropped), and the basis for the key |
| `docs/mc_options.csv` | How each multiple-choice answer is scored |
| `docs/recode_ledger.csv` | Decisions that differ from earlier analyses of these data |
| `docs/citations.csv` | How each cited work was checked |
| `R/` | Functions: reading and checking the data (`sources.R`), scoring (`beliefs.R`), estimates (`analysis.R`), figure and table output (`paper.R`) |
| `scripts/` | Numbered execution stages, shared configuration, and the runner listed below |
| `ms/` | `main.tex`, `references.bib`, and the compiled `main.pdf` |
| `tests/testthat/` | Reproductions of earlier published numbers, scoring unit tests, and a check that the data carry no direct identifiers |

`R/` contains reusable functions; `scripts/` calls them in execution order.

| Script | Purpose |
|---|---|
| `00_config.R` | Paths, source checksums, labels, colours, `theme_paper()`, figure sizes, and table styles |
| `01_prepare_data.R` | Verify sources, read and score responses, and save `data/derived/prepared_data.rds` |
| `02_estimate.R` | Read the prepared data and write estimates to `tabs/*.csv` |
| `03_figures.R` | Read estimates and write PDF and PNG figures to `figs/` |
| `04_tables.R` | Write LaTeX tables, number macros, and table styles to `tabs/` |
| `05_extensions.R` | Compare the three planned belief-state scorings and estimate descriptive engagement associations |
| `06_correlates.R` | Recover demographics, ideology, party attachment, and 2010 voting intention |
| `07_historical.R` | Reconstruct historical response models, partisan gaps, and latent response classes |
| `08_reconstruction_tables.R` | Generate reconstruction tables and manuscript values |
| `99_run_all.R` | Load configuration and helpers, then run stages 01–08 in order |

Prepared data in `data/derived/` are generated and ignored by Git. Table settings
in `00_config.R` cover standard tables and the denser appendix tables; the
manuscript applies them through generated commands in `tabs/style.tex`.

The first extension implements the 2018 scoring schemes and relates respondent
belief-state indices to political interest, voting intention, and partisan
intensity. See the [analysis plan](docs/belief_state_extensions.md) and
[generated results](docs/belief_extension_results.md). The manuscript includes
these comparisons in its results, discussion, and three generated appendix
tables; quoted estimates come from generated LaTeX macros. These associations
are descriptive; voting intention is not observed turnout or candidate choice.

The subsequent [reconstruction](docs/reconstructed_results.md) adds the verified
2010 voting measures and demographic correlates, eleven historical party-based
response models, eight ANES affect models, partisan-gap sensitivity to answer
keys, and exploratory latent response classes. The [source notes](docs/recovered_measures.md)
document questionnaire evidence, data joins, repaired historical code, and
interpretation limits. The [retrospective plan](docs/historical_analysis_plan.md)
records specifications and changes following source review. `data/historical/`
contains minimal, hash-verified extracts, so the normal build does not depend on
the local historical archive or sibling repositories. `scripts/import_archived_data.R`
recreates those extracts when the documented original sources are available.
