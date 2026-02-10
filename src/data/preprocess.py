# src/data/preprocess.py

import pandas as pd
from pathlib import Path
from src.data.load_data import load_rr_data, load_actigraph_data, load_user_data

def prepare_user_data(user_id: str, raw_base="../data/raw", out_base="../data/processed"):
    """
    Preprocesses and merges RR and Actigraph data for a given user.
    
    Args:
    	user_id (str): Identifier for the user (e.g. "user_1").
		raw_base (str): Base directory for raw data.
		out_base (str): Base directory for processed data.
	"""									
    user_dir = Path(raw_base) / user_id
    out_path = Path(out_base) / f"{user_id}.csv"
    out_path.parent.mkdir(parents=True, exist_ok=True)

    # Charger les données
    rr_df = load_rr_data(user_dir)
    act_df = load_actigraph_data(user_dir)

    # Convertir RR → bpm
    rr_df["bpm"] = 60 / rr_df["ibi_s"]
    rr_df = rr_df.set_index("timestamp")
    rr_df = rr_df[~rr_df.index.duplicated(keep="first")]
    rr_interp = rr_df["bpm"].resample("1s").mean().interpolate().reset_index()

    # Fusion
    merged = pd.merge(act_df, rr_interp, on="timestamp", how="left")

    # Sauvegarde
    merged.to_csv(out_path, index=False)
    print(f"✅ Données fusionnées sauvegardées : {out_path}")
    
def window_features(df: pd.DataFrame, user_id: str, freq: str = "60s") -> pd.DataFrame:
    """
    Extracts window features from processed user data, including rolling statistics
    calculated on the high-frequency signal.
    """
    # Verify necessary columns are present
    expected_cols = ["HR", "Vector Magnitude", "Steps"]
    if not all(col in df.columns for col in expected_cols):
        print(f"⚠️  Skipping {user_id} due to missing columns: {set(expected_cols) - set(df.columns)}")
        return pd.DataFrame()

    df["timestamp"] = pd.to_datetime(df["timestamp"])
    df = df.set_index("timestamp").sort_index()

    # --- FEATURE ENGINEERING: ROLLING STATISTICS ---
    # Calculate rolling stats on the high-frequency data before aggregation.
    # Window sizes are in seconds (e.g., 300s = 5 minutes, 900s = 15 minutes).
    windows = ['300s', '900s']
    for window in windows:
        # Rolling mean and standard deviation for Heart Rate and Activity
        df[f'hr_roll_mean_{window}'] = df['HR'].rolling(window=window, min_periods=1).mean()
        df[f'hr_roll_std_{window}'] = df['HR'].rolling(window=window, min_periods=1).std()
        df[f'vm_roll_mean_{window}'] = df['Vector Magnitude'].rolling(window=window, min_periods=1).mean()

    # Fill NaNs created by rolling windows. Forward-fill then back-fill.
    df.ffill(inplace=True)
    df.bfill(inplace=True)
    
    # --- AGGREGATION ---
    # Define how to aggregate each column into the final time windows (e.g., 60s).
    agg_dict = {
        "HR": ["mean", "std"],
        "Vector Magnitude": ["mean", "std"],
        "Steps": "sum"
    }
    # Add the new rolling feature columns to the aggregation dictionary.
    # We take the mean of the rolling features over the final window.
    for col in df.columns:
        if 'roll_mean' in col or 'roll_std' in col:
            agg_dict[col] = 'mean'

    features = df.resample(freq).agg(agg_dict)

    # Flatten the column names (e.g., ('HR', 'mean') -> 'hr_mean')
    features.columns = ["_".join(col).lower() for col in features.columns]
    features = features.reset_index()
    features["user_id"] = user_id

    return features

def build_dataset(processed_dir: str = "data/processed", raw_dir: str = "data/raw", out_path: str = "data/features/all_users.csv") -> None:
    """
    Builds the full dataset by extracting features per user and adding the sleep label.

    Args:
        processed_dir (str): path to the processed user data
        raw_dir (str): path to the raw user folders (to load sleep.csv)
        out_path (str): path to save the final dataset
    """
    processed_dir = Path(processed_dir)
    raw_dir = Path(raw_dir)
    all_users = []
    
    # Add counter for debugging
    user_count = 0
    
    for user_path in raw_dir.glob("user_*"):
        user_count += 1
        user_id = user_path.stem
        print(f"\nProcessing {user_id}...")
        
        df = load_user_data(raw_dir / user_id)
        if df is None or df.empty:
            print(f"❌ Skipping {user_id} - No data")
            continue
            
        feats = window_features(df, user_id=user_id)
        if feats.empty:
            print(f"❌ Skipping {user_id} - No features generated")
            continue

        # Load sleep.csv and add is_sleeping label
        sleep_path = raw_dir / user_id / "sleep.csv"
        if sleep_path.exists():
            sleep_df = pd.read_csv(sleep_path)

            # Convertir en datetime
            sleep_df["start"] = pd.to_datetime("2023-01-0" + sleep_df["In Bed Date"].astype(str) + " " + sleep_df["In Bed Time"])
            sleep_df["end"] = pd.to_datetime("2023-01-0" + sleep_df["Out Bed Date"].astype(str) + " " + sleep_df["Out Bed Time"])

            # Marquer les timestamps comme "sleeping" si dans un intervalle
            feats["is_sleeping"] = feats["timestamp"].apply(
                lambda ts: any((ts >= start) & (ts <= end) for start, end in zip(sleep_df["start"], sleep_df["end"]))
            )
        else:
            print(f"⚠️ sleep.csv manquant pour {user_id}")
            feats["is_sleeping"] = False
            
        all_users.append(feats)
        print(f"✅ Added features for {user_id}")
    
    if user_count == 0:
        raise ValueError(f"No user directories found in {raw_dir}")
        
    if len(all_users) == 0:
        raise ValueError(f"No valid user data processed. Checked {user_count} users")
        
    # Concat and save
    full_df = pd.concat(all_users, ignore_index=True)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    full_df.to_csv(out_path, index=False)
    print(f"✅ Full dataset saved to {out_path}")
    return full_df
