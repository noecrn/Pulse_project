# src/models/train_final.py

import pandas as pd
import joblib
from sklearn.preprocessing import StandardScaler
from xgboost import XGBClassifier

def train_final_model():
    """
    Trains the champion XGBoost model on the entire dataset and saves it.
    """
    print("🚀 Training final model on 100% of the data...")

    # 1. Load all data
    df = pd.read_csv("data/features/all_users.csv", parse_dates=["timestamp"])
    df.dropna(inplace=True)
    X = df.drop(columns=["is_sleeping", "timestamp", "user_id"])
    y = df["is_sleeping"]

    # 2. Scale all features
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    print("✅ All features scaled.")

    # 3. Initialize and train the champion model
    scale_pos_weight = (y.value_counts().iloc[0]) / (y.value_counts().iloc[1])
    champion_model = XGBClassifier(
        use_label_encoder=False,
        eval_metric="logloss",
        scale_pos_weight=scale_pos_weight,
        n_estimators=882, max_depth=6, learning_rate=0.02399969,
        subsample=0.78242799, colsample_bytree=0.75994438,
        random_state=42, n_jobs=-1
    )
    
    champion_model.fit(X_scaled, y)
    print("✅ Model trained on all data.")

    # 4. Save the final production-ready model and scaler
    joblib.dump(champion_model, "models/production_model.joblib")
    joblib.dump(scaler, "models/production_scaler.joblib")
    print("✅ Final model and scaler saved to 'production_model.joblib' and 'production_scaler.joblib'.")