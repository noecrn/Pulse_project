# src/models/evaluate_models.py

import pandas as pd
import joblib
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report
from xgboost import XGBClassifier

def evaluate_final_model():
    """
    Loads the dataset, prepares the test set, and evaluates the final,
    tuned XGBoost model.
    """
    print("🚀 Evaluating the champion model (Tuned XGBoost)...")
    
    # 1. Load Data
    df = pd.read_csv("data/features/all_users.csv", parse_dates=["timestamp"])
    df.dropna(inplace=True)
    print("✅ Data loaded successfully.")

    # 2. Define Features (X) and Target (y)
    X = df.drop(columns=["is_sleeping", "timestamp", "user_id"])
    y = df["is_sleeping"]

    # 3. Split Data to get the exact same test set
    _, X_test, _, y_test = train_test_split(
        X, y, stratify=y, test_size=0.2, random_state=42
    )
    print("✅ Test set prepared.")

    # 4. Scale Features using the saved scaler
    scaler = joblib.load("models/scaler.joblib")
    X_test_scaled = scaler.transform(X_test)
    print("✅ Test features scaled.")

    # 5. Initialize the Champion Model with best parameters
    scale_pos_weight = (y.value_counts().iloc[0]) / (y.value_counts().iloc[1])
    
    champion_model = XGBClassifier(
        use_label_encoder=False,
        eval_metric="logloss",
        scale_pos_weight=scale_pos_weight,
        # --- Tuned Parameters from your search ---
        n_estimators=882,
        max_depth=6,
        learning_rate=0.02399969,
        subsample=0.78242799,
        colsample_bytree=0.75994438,
        random_state=42,
        n_jobs=-1
    )

    # 6. Fit the model on the training data (loaded separately for this single run)
    X_train, _, y_train, _ = train_test_split(X, y, stratify=y, test_size=0.2, random_state=42)
    X_train_scaled = scaler.transform(X_train)
    champion_model.fit(X_train_scaled, y_train)
    
    # 7. Evaluate and print the final report
    y_pred = champion_model.predict(X_test_scaled)
    
    print("\n--- 🏆 Final Performance Report (Tuned XGBoost) ---")
    print(classification_report(y_test, y_pred, zero_division=0))