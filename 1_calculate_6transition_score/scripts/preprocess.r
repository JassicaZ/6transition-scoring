library(data.table)
library(edgeR)
options(warn =-1)
library(lme4)
library(optparse)

  # Define command line options
option_list <- list(
  make_option(c("--cli_path"), type = "character", help = "Path to clinical csv", metavar = "character"),
  make_option(c("--output_path"), type = "character", help = "Output folder", metavar = "character"),
  make_option(c("--batch_col"), type = "character", default = "", help = "Batch column name (optional)", metavar = "character")
)
opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)


cli_path <- opt$cli_path
batch_col <- opt$batch_col
pseudobulk_path <- paste0(opt$output_path, '/ct_pseudobulk')
output_path <- paste0(opt$output_path, '/preprocess')



read_fread_with_rownames <- function(file, rowname_col = 1) {
  dt <- fread(file, header = TRUE)
  df <- as.data.frame(dt)
  rn <- df[[rowname_col]]
  df <- df[, -rowname_col, drop = FALSE]
  rownames(df) <- rn
  return(df)
}


cli <- read.csv(cli_path, row.names = 1, stringsAsFactors = FALSE)
cli$sex <- factor(cli$sex)
if (!is.null(batch_col) && batch_col != '' && batch_col %in% colnames(cli)) {
  cli$batch <- factor(cli[[batch_col]])
} else {
  cli$batch <- NULL
}


 df_feature <- read.csv('./model/selected_features.csv', row.names = 1)
split_list <- split(df_feature$DEG, df_feature$celltype)
celltypes <- names(split_list)

result_list <- lapply(celltypes, function(celltype_name) {
  file <- file.path(pseudobulk_path, paste0(celltype_name, '.csv'))
  if (!file.exists(file)) {
    stop(paste0('Pseudobulk file not found for cell type: ', celltype_name, ' -> ', file))
  }

  dt <- read_fread_with_rownames(file)
  if (nrow(dt) == 0 || ncol(dt) == 0) {
    stop(paste0('Empty pseudobulk file for cell type: ', celltype_name))
  }

  # Convert to gene × sample matrix
  mat <- as.matrix(t(dt))
  sample_names <- colnames(mat)
  missing_samples <- setdiff(sample_names, rownames(cli))
  if (length(missing_samples) > 0) {
    stop(paste0('Samples found in cell type ', celltype_name, ' but missing in clinical csv: ', paste(missing_samples, collapse = ', ')))
  }
  cli_sub <- cli[sample_names, , drop = FALSE]

  # TMM normalization
  mat <- mat[rowSums(mat != 0) > 1, , drop = FALSE]
  if (nrow(mat) == 0) {
    stop(paste0('No features remain after filtering zero-expression rows for cell type: ', celltype_name))
  }
  d <- DGEList(counts = mat)
  TMM <- calcNormFactors(d, method = 'TMM')
  mat <- cpm(TMM, log = TRUE, prior.count = 1)

  # Select the model's selected features from the normalized pseudobulk matrix
  vars <- split_list[[celltype_name]]
  selected_genes <- intersect(vars, rownames(mat))
  if (length(selected_genes) == 0) {
    stop(paste0('No selected features found in normalized pseudobulk data for cell type: ', celltype_name))
  }
  sub_mat <- mat[selected_genes, , drop = FALSE]
  rownames(sub_mat) <- paste0(celltype_name, '_', selected_genes)

  # Compute residuals for each selected feature
  n_genes <- nrow(sub_mat)
  residuals_mat <- matrix(NA, nrow = n_genes, ncol = nrow(cli_sub))
  rownames(residuals_mat) <- rownames(sub_mat)
  colnames(residuals_mat) <- rownames(cli_sub)

  for (i in seq_len(n_genes)) {
    y <- as.numeric(sub_mat[i, ])
    cli_sub$expr <- y
    if (!is.null(cli_sub$batch)) {
      fit <- tryCatch(lmer(expr ~ age + sex + (1 | batch), data = cli_sub),
                      error = function(e) {
                        cat('ERROR at feature', rownames(sub_mat)[i], ':\n')
                        print(e)
                        return(NULL)
                      })
      if (is.null(fit)) {
        residuals_mat[i, ] <- rep(NA, nrow(cli_sub))
        next
      }
      residuals_mat[i, ] <- resid(fit) + fixef(fit)['(Intercept)'] + fixef(fit)['age'] * cli_sub$age
    } else {
      fit <- tryCatch(lm(expr ~ age + sex, data = cli_sub),
                      error = function(e) {
                        cat('ERROR at feature', rownames(sub_mat)[i], ':\n')
                        print(e)
                        return(NULL)
                      })
      if (is.null(fit)) {
        residuals_mat[i, ] <- rep(NA, nrow(cli_sub))
        next
      }
      residuals_mat[i, ] <- resid(fit) + coef(fit)['(Intercept)'] + coef(fit)['age'] * cli_sub$age
    }
    cat('Feature', rownames(sub_mat)[i], 'processed for cell type', celltype_name, '\n')
  }

  return(residuals_mat)
})

final_mat <- do.call(rbind, result_list)

dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
write.csv(final_mat, paste0(output_path, '/preprocessed_matrix.csv'))
