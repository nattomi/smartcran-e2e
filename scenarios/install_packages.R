# Tag this run so we can correlate proxy logs
run_id <- Sys.getenv("RUN_ID")
if (!nzchar(run_id)) {
  run_id <- paste0(as.integer(Sys.time()), "-", sample(1e6, 1))
}
cran_base <- Sys.getenv("CRAN_BASE", unset = "http://smartcran-logger:8080")

message("RUN_ID: ", run_id)
message("CRAN base: ", cran_base)

# Tag the User-Agent (proxy logs 'ua')
ua0 <- getOption("HTTPUserAgent")
ua  <- paste(na.omit(c(ua0, sprintf("scl-run=%s", run_id))), collapse = " ")
options(HTTPUserAgent = ua)

# Point CRAN to the proxy
options(repos = c(CRAN = cran_base))

# Marker requests (ID goes into PATH so it's visible in proxy logs)
safe_get <- function(path) {
  url <- paste0(cran_base, path)
  try(suppressWarnings(readLines(url, warn = FALSE)), silent = TRUE)
}
safe_get(paste0("/__marker/", run_id, "/begin"))

# Basic flow: available.packages + a few pure-R installs
ap <- available.packages()
message("available.packages(): rows = ", nrow(ap))

pkgs <- c("assertthat", "pkgconfig", "prettyunits")

install_one <- function(p) {
  message("--- Installing: ", p)
  install.packages(p, dependencies = FALSE, quiet = TRUE, Ncpus = 1)
  suppressPackageStartupMessages(library(p, character.only = TRUE))
  as.character(utils::packageVersion(p))
}

versions <- vapply(pkgs, install_one, character(1))
print(versions)

# Closing marker
safe_get(paste0("/__marker/", run_id, "/end"))
message("OK: ", run_id)
