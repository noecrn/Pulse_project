# src/models/tune_random_forest.py

import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split, RandomizedSearchCV
from sklearn.preprocessing import StandardScaler
from scipy.stats import randint

def tune_random_forest_hyperparameters():
    """
    Performs a randomized search to find the best hyperparameters for RandomForest.
    """
    # 1. Load and prepare the data
    print("💾 Loading and preparing data...")
    df = pd.read_csv("data/features/all_users.csv", parse_dates=["timestamp"])
    df.dropna(inplace=True)
    X = df.drop(columns=["is_sleeping", "timestamp", "user_id"])
    y = df["is_sleeping"]
    
    X_train, _, y_train, _ = train_test_split(X, y, stratify=y, test_size=0.2, random_state=42)
    
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    print("✅ Data prepared.")

    # 2. Define the hyperparameter search space for Random Forest
    print("⚙️ Defining hyperparameter search space...")
    param_dist = {
        'n_estimators': randint(100, 600),
        'max_depth': randint(10, 30),
        'min_samples_split': randint(2, 20),
        'min_samples_leaf': randint(1, 10),
        'max_features': ['sqrt', 'log2'] # Common choices for Random Forest
    }

    # 3. Set up the RandomForest model and the Randomized Search
    rf = RandomForestClassifier(
        class_weight="balanced", 
        random_state=42
    )
    
    random_search = RandomizedSearchCV(
        estimator=rf,
        param_distributions=param_dist,
        n_iter=5,
        scoring='f1',
        cv=3,
        verbose=1,
        random_state=42,
        n_jobs=1 # Keeping this at 1 to avoid potential macOS issues
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
    tune_random_forest_hyperparameters()