import scanpy as sc
import numpy as np
import pandas as pd
import os
import celltypist
from celltypist import models
import time  
import argparse


parser = argparse.ArgumentParser()
parser.add_argument('--raw', type=str)
parser.add_argument('--harmony_file', type=str)
parser.add_argument('--output_path', type=str)

args = parser.parse_args()

raw = args.raw
harmony=args.harmony_file
output_folder=args.output_path
pseudobulk_folder=output_folder + '/ct_pseudobulk'

# Load the trained model
model_3 = models.Model.load(model="./model/model_from_AIDA_03_v2.pkl")

# Preprocess discovery cohort single-cell data
adata_raw = sc.read(raw)
adata_celltypist = adata_raw.copy()  # Make a copy of the AnnData object
#adata_celltypist.X = adata_raw.layers["counts"]  # Set adata.X to raw counts
sc.pp.normalize_total(adata_celltypist, target_sum=10**4)  # Normalize to 10,000 counts per cell
sc.pp.log1p(adata_celltypist)  # Log-transform the data
adata_celltypist.X = adata_celltypist.X.toarray()  # Convert sparse matrix to dense for compatibility with celltypist

# Load neighbors
adata = sc.read(harmony)
adata_celltypist.uns['neighbors'] = adata.uns['neighbors']
adata_celltypist.obsp['connectivities'] = adata.obsp['connectivities']
adata_celltypist.obsp['distances'] = adata.obsp['distances']

# Predict cell types
print("Performing annotation using the trained model.")
start_time = time.time()  # Start timing
print("Start time: ", time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(start_time)))  
predictions = celltypist.annotate(
    adata_celltypist, model=model_3, majority_voting=False, use_GPU=False
)
predictions_adata = predictions.to_adata()

# Save the annotated data
adata_raw = sc.read(raw)
adata_raw.obs['celltype'] = predictions_adata.obs['predicted_labels']

end_time = time.time()  # End timing
print("End time: ", time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(end_time))) 
print(f"Annotation computation time: {end_time - start_time} seconds") 

# Pseudobulk
if not os.path.exists(pseudobulk_folder):
    # Create the folder if it does not exist
    os.makedirs(pseudobulk_folder)
    print("Folder has been created.")
else:
    print("Folder already exists.")

for ct in adata_raw.obs['celltype'].unique():
    temp = adata_raw[adata_raw.obs['celltype'] == ct].copy()
    temp.obs['sample'] = temp.obs['sample'].astype('category')
    res = pd.DataFrame(columns=temp.var_names, index=temp.obs['sample'].cat.categories)
    for clust in temp.obs['sample'].cat.categories: 
        res.loc[clust] = temp[temp.obs['sample'].isin([clust]),:].X.mean(0)
    res.to_csv(pseudobulk_folder + '/{}.csv'.format(ct))

print("Pseudobulk data has been processed")
