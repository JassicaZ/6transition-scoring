import pickle
import numpy as np
import pandas as pd
import imbens
import argparse
import os

parser = argparse.ArgumentParser()
parser.add_argument('--output_path', type=str)
parser.add_argument('--cli_path', type=str)


args = parser.parse_args()

output_folder=args.output_path
preprocess_folder=output_folder + '/preprocess'
cli_path=args.cli_path
score_folder=output_folder + '/transition_score'


df= pd.read_csv(f"{preprocess_folder}/preprocessed_matrix.csv",index_col=0)
cli = pd.read_csv(cli_path, index_col=0)

with open("./model/6TS_model.pkl", "rb") as f:
    scoring_model = pickle.load(f)

df_98_feature = pd.read_csv('./model/selected_features.csv', index_col=0)
selected_features= df_98_feature.index

df=df.loc[selected_features,]
df.dropna(axis=1, inplace=True)
cli.index = cli.index.astype(str)
cli = cli.loc[df.columns]
cli["age_group"] = (cli["age"] > 6).astype(int)

#计算评分
y = cli["age_group"]
X = df.T
y_pre =scoring_model.predict(X)
y_prob = scoring_model.predict_proba(X)[:, 1]
#整理结果
result=pd.DataFrame({'sample':cli.index,
                     'age':cli['age'],
                  '6_transition_score': y_prob,
                  })

os.makedirs(score_folder, exist_ok=True)
result.to_csv(f"{score_folder}/transition_scores.csv", index=False)

