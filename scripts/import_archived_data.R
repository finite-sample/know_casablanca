source("scripts/00_config.R")
archive <- project_file("legacy", "casablanca", "misinfo_more", "misinfo_casablanca_nes_gss_etc_edition", "data")
destination <- project_file("data", "historical")
dir.create(destination, recursive = TRUE, showWarnings = FALSE)
sources <- c(
  "nes/nes88.csv", "nes/nes00.csv", "nes/nes04.csv", "nes/nes08.csv",
  "nes/nes92.rdata", "gss06.rdata", "nic2.rdata", "btp04.rdata"
)
anes_1992_path <- project_file("..", "partisan_gap", "data", "anes", "anes_1992", "NES1992.dta")
records <- lapply(sources, function(file) {
  path <- file.path(archive, file)
  name <- sub("\\..*$", "", basename(file))
  if (endsWith(file, ".csv")) {
    data <- read.csv(path)
  } else {
    env <- new.env(parent = emptyenv())
    load(path, envir = env)
    data <- env[[name]]
  }
  keep <- if (startsWith(name, "nes")) {
    grep("^m\\.|^know$|^pid3$|^r.min.d.therm$", names(data), value = TRUE)
  } else {
    switch(name,
      gss06 = c("sciagrgw", "inf", "rid"),
      nic2 = c("warm", "kn_ind2c", "rid"),
      btp04 = c("w4b62", "t1know", "pid3", paste0("w4b", c(60, 68, 61, 62, 63, 64, 65, 66, 69), "r"))
    )
  }
  if (name == "nes92") {
    original <- foreign::read.dta(anes_1992_path, convert.factors = FALSE)
    stopifnot(!anyDuplicated(original$V923004), !anyDuplicated(data$v923004))
    original <- original[match(data$v923004, original$V923004), ]
    stopifnot(identical(as.integer(data$v923004), as.integer(original$V923004)))
    fields <- c(unemp = "V923527", infl = "V923529", econ1 = "V923531", econ4j = "V923533", econ = "V923535")
    for (item in names(fields)) {
      code <- original[[fields[[item]]]]
      raw <- dplyr::case_when(code == 1 ~ "btr", code == 3 ~ "same", code == 5 ~ "wrse", code == 8 ~ "dk")
      data[[paste0("m.", item)]] <- raw
      data[[paste0("m.", item, "r")]][is.na(raw)] <- NA
      if (paste0("m.", item, "s") %in% names(data)) data[[paste0("m.", item, "s")]][is.na(raw)] <- NA
      data[[paste0("original_", item)]] <- code
    }
    data$original_id <- original$V923004
    data$party_current <- dplyr::case_when(
      original$V923634 %in% 0:2 ~ "dem", original$V923634 == 3 ~ "ind", original$V923634 %in% 4:6 ~ "rep"
    )
    keep <- c(keep, "original_id", "party_current", paste0("original_", names(fields)))
  }
  output <- file.path(destination, paste0(name, ".csv"))
  readr::write_csv(data[keep], output, na = "")
  data.frame(
    source = file.path("legacy/casablanca/misinfo_more/misinfo_casablanca_nes_gss_etc_edition/data", file),
    source_sha256 = digest::digest(file = path, algo = "sha256"),
    supplemental_source = if (name == "nes92") "../partisan_gap/data/anes/anes_1992/NES1992.dta" else NA_character_,
    supplemental_sha256 = if (name == "nes92") {
      digest::digest(file = anes_1992_path, algo = "sha256")
    } else {
      NA_character_
    },
    extract = file.path("data/historical", basename(output)),
    extract_sha256 = digest::digest(file = output, algo = "sha256"), rows = nrow(data),
    columns = paste(keep, collapse = ";")
  )
})
source <- project_file("..", "know_hidden", "data", "raw", "alumni_2010_demographics.csv")
demo <- readr::read_csv(source, col_types = readr::cols(.default = "c")) |>
  dplyr::select(arep.id, year, gender, ethnic, educ)
readr::write_csv(demo, file.path(raw_dir, "alumni_2010_demographics.csv"), na = "")

records[[length(records) + 1]] <- data.frame(
  source = "../know_hidden/data/raw/alumni_2010_demographics.csv",
  source_sha256 = digest::digest(file = source, algo = "sha256"),
  extract = "data/raw/alumni_2010_demographics.csv",
  extract_sha256 = digest::digest(file = file.path(raw_dir, "alumni_2010_demographics.csv"), algo = "sha256"),
  rows = nrow(demo), columns = paste(names(demo), collapse = ";")
)
reference <- file.path(archive, "..", "res", "tab1.csv")
output <- file.path(destination, "reference_tab1.csv")
file.copy(reference, output, overwrite = TRUE)
records[[length(records) + 1]] <- data.frame(
  source = "legacy/casablanca/misinfo_more/misinfo_casablanca_nes_gss_etc_edition/res/tab1.csv",
  source_sha256 = digest::digest(file = reference, algo = "sha256"),
  extract = "data/historical/reference_tab1.csv",
  extract_sha256 = digest::digest(file = output, algo = "sha256"),
  rows = nrow(read.csv(reference)), columns = "original saved table"
)
readr::write_csv(dplyr::bind_rows(records), project_file("docs", "historical_sources.csv"))
