import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report, f1_score
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from xgboost import XGBClassifier

def compare_models(X_train, X_test, y_train, y_test):
    """
    Trains multiple models and returns a DataFrame with their F1-scores.
    """
    # Calculate the scale_pos_weight for XGBoost to handle class imbalance
    scale_pos_weight = (y_train == 0).sum() / (y_train == 1).sum()

    models = {
        "LogisticRegression": LogisticRegression(max_iter=1000, class_weight='balanced'),
        "RandomForest": RandomForestClassifier(random_state=42, class_weight='balanced', n_jobs=-1),
        # New, tuned XGBoost model
        "XGBoost": XGBClassifier(
            use_label_encoder=False,
            eval_metric="logloss",
            scale_pos_weight=scale_pos_weight,
            # --- Tuned Parameters ---
            n_estimators=882,
            max_depth=6,
            learning_rate=0.02399969,
            subsample=0.78242799,
            colsample_bytree=0.75994438,
            random_state=42 # Add for reproducibility
        )
    }
    
    results = []

    for name, model in models.items():
        print(f"⏳ Training {name}...")
        model.fit(X_train, y_train)
        y_pred = model.predict(X_test)
        
        f1 = f1_score(y_test, y_pred, zero_division=0)
        results.append({"Model": name, "F1-Score": f1})
        
        print(f"--- {name} Classification Report ---")
        print(classification_report(y_test, y_pred, zero_division=0))

    return pd.DataFrame(results)

def evaluate_all_models():
    """
    Main evaluation function that prepares data and runs model comparison.
    """
    print("🚀 Starting model evaluation process...")
    
    # 1. Load Data
    df = pd.read_csv("data/features/all_users.csv", parse_dates=["timestamp"])
    df.dropna(inplace=True)
    print("✅ Data loaded successfully.")

    # 2. Define Features (X) and Target (y)
    X = df.drop(columns=["is_sleeping", "timestamp", "user_id"])
    y = df["is_sleeping"]

    # 3. Split Data (using the same parameters as in training for consistency)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, stratify=y, test_size=0.2, random_state=42
    )
    print("✅ Data split into training and testing sets.")

    # 4. Scale Features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    print("✅ Features scaled.")

    # 5. Run Comparison
    results_df = compare_models(X_train_scaled, X_test_scaled, y_train, y_test)
    
    print("\n--- 🏆 Final Model Comparison ---")
    print(results_df.sort_values(by="F1-Score", ascending=False))