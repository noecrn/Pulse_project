# src/models/tune_xgboost.py

import pandas as pd
from xgboost import XGBClassifier
from sklearn.model_selection import train_test_split, RandomizedSearchCV
from sklearn.preprocessing import StandardScaler
from scipy.stats import uniform, randint

def tune_xgboost_hyperparameters():
    """
    Performs a randomized search to find the best hyperparameters for XGBoost.
    """
    # 1. Load and prepare the data (only the training set is needed for tuning)
    print("💾 Loading and preparing data...")
    df = pd.read_csv("data/features/all_users.csv", parse_dates=["timestamp"])
    df.dropna(inplace=True)
    X = df.drop(columns=["is_sleeping", "timestamp", "user_id"])
    y = df["is_sleeping"]
    
    # We only need the training set for cross-validation
    X_train, _, y_train, _ = train_test_split(X, y, stratify=y, test_size=0.2, random_state=42)
    
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    print("✅ Data prepared.")

    # 2. Define the hyperparameter search space (the "grid")
    print("⚙️ Defining hyperparameter search space...")
    param_dist = {
        'n_estimators': randint(100, 1000),
        'max_depth': randint(3, 10),
        'learning_rate': uniform(0.01, 0.3),
        'subsample': uniform(0.6, 0.4),      # Range is [0.6, 1.0]
        'colsample_bytree': uniform(0.6, 0.4) # Range is [0.6, 1.0]
    }

    # 3. Set up the XGBoost model and the Randomized Search
    scale_pos_weight = (y_train == 0).sum() / (y_train == 1).sum()
    xgb = XGBClassifier(
        use_label_encoder=False, 
        eval_metric="logloss", 
        scale_pos_weight=scale_pos_weight, 
        random_state=42
    )
    
    random_search = RandomizedSearchCV(
        estimator=xgb,
        param_distributions=param_dist,
        n_iter=50,          # Number of parameter combinations to try
        scoring='f1',       # The metric to optimize
        cv=5,               # 5-fold cross-validation
        verbose=1,
        random_state=42,
        n_jobs=1            # Use all available CPU cores
    )

    # 4. Run the search
    print("⏳ Starting randomized search... (This may take several minutes)")
    random_search.fit(X_train_scaled, y_train)

    # 5. Print the results
    print("\n--- 🏆 Tuning Complete ---")
    print(f"Best cross-validated F1-Score found: {random_search.best_score_:.4f}")
    print("\nBest parameters found:")
    print(random_search.best_params_)

if __name__ == "__main__":
    tune_xgboost_hyperparameters()