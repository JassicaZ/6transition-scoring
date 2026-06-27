#!/usr/bin/env Rscript
# Install required CRAN and Bioconductor packages using Tsinghua CRAN mirror

CRAN_MIRROR <- "https://mirrors.tuna.tsinghua.edu.cn/CRAN/"
CRAN_PKGS <- c("data.table","nloptr","lme4", "optparse")
BIOC_PKGS <- c("edgeR")

installed <- rownames(installed.packages())
to_install_cran <- setdiff(CRAN_PKGS, installed)
to_install_bioc <- setdiff(BIOC_PKGS, installed)

if (length(to_install_cran) > 0) {
  message("Installing CRAN packages via Tsinghua mirror: ", paste(to_install_cran, collapse = ", "))
  install.packages(to_install_cran, repos = CRAN_MIRROR)
} else {
  message("All CRAN packages already installed.")
}

if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", repos = CRAN_MIRROR)
}

if (length(to_install_bioc) > 0) {
  message("Installing Bioconductor packages: ", paste(to_install_bioc, collapse = ", "))
  BiocManager::install(to_install_bioc, ask = FALSE)
} else {
  message("All Bioconductor packages already installed.")
}

message("R dependency installation complete.")
