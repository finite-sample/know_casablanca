# Data

Four survey files, each the full export of a survey that randomly assigned
respondents to multiple-choice items or to 0-10 ratings of the same statements.

| File | Survey | Fielded | Source |
|---|---|---|---|
| `raw/alumni_2010.csv` | Alumni panel of a private university in the western U.S. | September 2010 | `finite-sample/know_hidden`, `data/arep/arep.csv` |
| `raw/staff_2010.csv` | Staff panel of the same university | September-October 2010 | `finite-sample/know_hidden`, `data/srep/srep.csv` |
| `raw/mturk_march_2017.csv` | Amazon Mechanical Turk, U.S. workers | 27-28 March 2017 | `finite-sample/know_hidden`, `data/mturk/` (Qualtrics export of 28 March) |
| `raw/mturk_july_2017.csv` | Amazon Mechanical Turk, U.S. workers | 9 July 2017 | `finite-sample/know_pgap_format`, `data/turk/mam_mturk_070917.csv` |

`R/sources.R` checks each file against a SHA-256 hash before any analysis.

## Anonymization

The files were anonymized before release. In every file, IP addresses,
latitude and longitude, city, and ZIP or postal codes are blank. In the 2010
files, the panel IDs (`userid` and the ID echoed in `url`/`url4`) are replaced
with random pseudonyms that keep the `FY` (alumni) and `srep` (staff) prefixes
the survey software used, and the staff file's free-text race answers are
blank; the mapping to the original IDs was not kept. No other cell was changed.
Country and state (from the IP address) are kept because the analysis restricts
the MTurk samples to U.S. respondents. The panels' contact lists are not part of this repository. The minimal alumni
intake extract described below uses the same pseudonymous identifiers.

## Questionnaires and keys

`docs/propositions.csv` lists every statement, whether it is true or false, the
source for that key, and the statements dropped because they are not plainly
true or false. `docs/mc_options.csv` maps each multiple-choice answer to
correct, incorrect, or don't know. `docs/recode_ledger.csv` records every
decision that differs from earlier analyses of these data.

## Reconstructed analyses

`raw/alumni_2010_demographics.csv` contains only the pseudonymous panel ID,
birth year, gender, education, and race/ethnicity from the companion repository's
anonymized intake extract. Repeated IDs are reconciled field by field; conflicting
values become missing. [Measure notes](../docs/recovered_measures.md) document
coverage, conflicts, coding, and the questionnaire evidence.

`historical/` contains the minimal columns used from the archived ANES, GSS,
NIC, and BTP analyses, plus the saved core table used for comparison. The 1992
extract also contains original ANES response codes and contemporary party
identification to distinguish nonresponse from DK and party timing.
[The source ledger](../docs/historical_sources.csv) records source and extract
SHA-256 hashes; stage 07 verifies every extract before fitting the models.
These extracts let `make check` run independently of local archives and sibling
repositories. `scripts/import_archived_data.R` regenerates them only when the
original sources listed in the ledger are available.
