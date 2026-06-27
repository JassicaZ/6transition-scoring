# 6-Transition Score Calculation and Reference Curve Visualization

## About 6-transition score

In our study (under submission), we identified a 6-year transcriptional transition that is highly prominent and broadly distributed across multiple peripheral immune cell types during childhood.

Anchoring this transcriptional transition, we developed an age-referenced immune transition score and a set of reference curves for standardized benchmarking of individual immune states in pediatric cohorts.

## Project Overview

This repository implements a workflow for deriving an individual immune transition score from single-cell RNA-seq data (`.h5ad` files) and visualizing the results on reference curves.

## Repository Structure

1. `1_calculate_6transition_score/` — A Docker-based pipeline for calculating individual transition scores from single-cell RNA-seq data.
2. `2_visualize_reference_curves/` — A Jupyter notebook demonstrating reference curve visualization.

## Data source

For testing and demonstration, this repository uses single-cell RNA-seq data from:

_Keever-Keigher, M. R., et al. Front Immunol. 2024_ (PMID: 39192974).

The dataset includes seven Crohn's disease (CD) patients.






