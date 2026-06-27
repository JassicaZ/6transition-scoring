#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<-USAGE
Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
  --annotate                   Run celltype annotation + pseudobulk step
  --prep                       Run preprocessing step
  --score                      Run scoring step to obtain 6-transition scores
  --run-all                    Run annotate -> prep -> score sequentially
  --qc-h5ad PATH               Path to QC-filtered raw AnnData (.h5ad) for annotation
  --neighbors-h5ad PATH        Path to Harmony/neighbor-graph AnnData (.h5ad) for annotation
  --output-path PATH           Base output folder for all steps
  --out PATH                   Alias for --output-path
  --clinical-csv PATH          Clinical CSV for preprocessing and scoring
  --batch-col NAME             Optional batch column name for preprocessing
  --ct NAME                    Optional cell type name for preprocessing
  --annotate-script PATH       Path to script for celltype annotation (default: scripts/celltypist_pseubulk.py)
  --prep-script PATH           Path to script for preprocessing (default: scripts/preprocess.r)
  --score-script PATH          Path to scoring script (default: scripts/score_calculation.py)
  -h, --help                   Show this help message and exit

Examples:
  ${SCRIPT_NAME} --run-all --qc-h5ad data/raw.h5ad --neighbors-h5ad data/harmony.h5ad --output-path /results/sample1 --clinical-csv clinical.csv
  ${SCRIPT_NAME} --annotate --qc-h5ad data/raw.h5ad --neighbors-h5ad data/harmony.h5ad --output-path /results/sample1
  ${SCRIPT_NAME} --prep --output-path /results/sample1 --clinical-csv clinical.csv
  ${SCRIPT_NAME} --score --output-path /results/sample1 --clinical-csv clinical.csv
USAGE
}

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
ANNOTATE_SCRIPT_DEFAULT="${SCRIPT_DIR}/scripts/celltypist_pseubulk.py"
PREP_SCRIPT_DEFAULT="${SCRIPT_DIR}/scripts/preprocess.r"
SCORE_SCRIPT_DEFAULT="${SCRIPT_DIR}/scripts/score_calculation.py"

# Parse args
RUN_ANNOTATE=false
RUN_PREP=false
RUN_SCORE=false
RUN_ALL=false
RAW=""
HARMONY=""
OUTPUT_PATH=""
CLINICAL_CSV=""
BATCH_COL=""
CT=""
ANNOTATE_SCRIPT="$ANNOTATE_SCRIPT_DEFAULT"
PREP_SCRIPT="$PREP_SCRIPT_DEFAULT"
SCORE_SCRIPT="$SCORE_SCRIPT_DEFAULT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --annotate) RUN_ANNOTATE=true; shift;;
    --prep) RUN_PREP=true; shift;;
    --score) RUN_SCORE=true; shift;;
    --run-all|--all) RUN_ALL=true; shift;;
    --qc-h5ad) RAW="$2"; shift 2;;
    --neighbors-h5ad) HARMONY="$2"; shift 2;;
    --output-path|--out) OUTPUT_PATH="$2"; shift 2;;
    --clinical-csv) CLINICAL_CSV="$2"; shift 2;;
    --batch-col) BATCH_COL="$2"; shift 2;;
    --ct) CT="$2"; shift 2;;
    --annotate-script) ANNOTATE_SCRIPT="$2"; shift 2;;
    --prep-script) PREP_SCRIPT="$2"; shift 2;;
    --score-script) SCORE_SCRIPT="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "[ERROR] Unknown argument: $1"; usage; exit 2;;
  esac
done

if $RUN_ALL; then
  RUN_ANNOTATE=true
  RUN_PREP=true
  RUN_SCORE=true
fi

if ! $RUN_ANNOTATE && ! $RUN_PREP && ! $RUN_SCORE && ! $RUN_ALL; then
  echo "[ERROR] No action specified. Use --annotate, --prep, --score or --run-all." >&2
  usage
  exit 2
fi

# Helper: check executable
check_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $1" >&2
    exit 3
  fi
}

if $RUN_ANNOTATE; then
  echo "[INFO] Preparing annotation step..."
  if [[ -z "$RAW" || -z "$HARMONY" || -z "$OUTPUT_PATH" ]]; then
    echo "[ERROR] --qc-h5ad, --neighbors-h5ad and --output-path are required for annotation." >&2
    usage
    exit 2
  fi
  check_cmd python3 || true
  # ensure base output path exists
  mkdir -p "${OUTPUT_PATH}"
  echo "[INFO] Running annotation: ${ANNOTATE_SCRIPT}"
  echo "[INFO] Command: python3 \"${ANNOTATE_SCRIPT}\" --raw \"${RAW}\" --harmony_file \"${HARMONY}\" --output_path \"${OUTPUT_PATH}\""
  python3 "${ANNOTATE_SCRIPT}" --raw "${RAW}" --harmony_file "${HARMONY}" --output_path "${OUTPUT_PATH}"
  echo "[INFO] Annotation finished. Pseudobulk files should be in: ${OUTPUT_PATH}/ct_pseudobulk"
fi

if $RUN_PREP; then
  echo "[INFO] Preparing preprocessing (R) step..."
  if [[ -z "$OUTPUT_PATH" || -z "$CLINICAL_CSV" ]]; then
    echo "[ERROR] --output-path and --clinical-csv are required for preprocessing." >&2
    usage
    exit 2
  fi
  check_cmd Rscript
  mkdir -p "${OUTPUT_PATH}"

  echo "[INFO] Running R preprocess: ${PREP_SCRIPT}"
  # preprocess.r in this repo accepts --output_path and --cli_path; it will read pseudobulk from output_path/ct_pseudobulk
  Rscript "${PREP_SCRIPT}" --cli_path "${CLINICAL_CSV}" --output_path "${OUTPUT_PATH}" --batch_col "${BATCH_COL}"$( [[ -n "$CT" ]] && printf ' --ct %s' "$CT" )
  echo "[INFO] R preprocessing finished. Results in: ${OUTPUT_PATH}/preprocess"
fi

if $RUN_SCORE; then
  echo "[INFO] Preparing scoring step..."
  if [[ -z "$OUTPUT_PATH" || -z "$CLINICAL_CSV" ]]; then
    echo "[ERROR] --output-path and --clinical-csv are required for scoring." >&2
    usage
    exit 2
  fi
  check_cmd python3 || true
  SCORE_SCRIPT="${SCORE_SCRIPT:-$SCORE_SCRIPT_DEFAULT}"
  echo "[INFO] Running scoring: ${SCORE_SCRIPT}"
  echo "[INFO] Command: python3 \"${SCORE_SCRIPT}\" --output_path \"${OUTPUT_PATH}\" --cli_path \"${CLINICAL_CSV}\""
  python3 "${SCORE_SCRIPT}" --output_path "${OUTPUT_PATH}" --cli_path "${CLINICAL_CSV}"
  echo "[INFO] Scoring finished. Results in: ${OUTPUT_PATH}/transition_score"
fi

echo "[INFO] Pipeline completed successfully."
