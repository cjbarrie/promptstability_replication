required_packages <- c(
  "reticulate",
  "dplyr",
  "ggplot2",
  "readr",
  "tidyr",
  "cowplot",
  "stringr",
  "tidylog",
  "knitr",
  "kableExtra"
)

installed <- rownames(installed.packages())
missing <- setdiff(required_packages, installed)

if (length(missing) == 0) {
  message("All required R packages are already installed.")
} else {
  message("Installing missing R packages: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cloud.r-project.org")
}

message("R dependency setup complete.")
