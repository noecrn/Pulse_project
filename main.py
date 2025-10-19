import sys
import pandas as pd
from src.models.train import train_model
from src.data.preprocess import build_dataset

def main():
    if len(sys.argv) < 2:
        print("Usage: python main.py [prepare|train|eval]")
        return

    command = sys.argv[1]

    if command == "prepare":
        print("🔧 Preprocessing data and generating features...")
        build_dataset()

    elif command == "train":
        print("🔨 Building dataset...")
        import os

        csv_path = "data/features/all_users.csv"
        if not os.path.exists(csv_path):
            print("❌ Dataset not found. Please run 'make prepare' first.")
            return

        df = pd.read_csv(csv_path, parse_dates=["timestamp"])
        df.dropna(inplace=True)

        print("🏋️ Training model...")
        train_model(df, eval_during_training=False)

    elif command == "eval":
        import os
        from src.models.evaluate_models import evaluate_all_models

        csv_path = "data/features/all_users.csv"
        model_path = "models/random_forest_model.joblib"

        if not os.path.exists(csv_path):
            print("❌ Dataset not found. Please run 'make prepare' first.")
            return

        if not os.path.exists(model_path):
            print("❌ Model not found. Please run 'make train' first.")
            return

        df = pd.read_csv(csv_path, parse_dates=["timestamp"])
        df.dropna(inplace=True)

        evaluate_all_models()
    else:
        print(f"Unknown command: {command}")

if __name__ == "__main__":
    main()