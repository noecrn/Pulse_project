# src/data/load_data.py

import pandas as pd
from pathlib import Path

def parse_time_columns(df, time_col="time", date_col="day"):
    # Log invalid day values before filtering
    invalid = df[~df[date_col].isin([1, 2])]
    if not invalid.empty:
        print(f"⚠️ {len(invalid)} rows dropped due to invalid 'day' values: {invalid[date_col].unique()}")

    # Keep only valid day values (1 or 2)
    df = df[df[date_col].isin([1, 2])].copy()

    # Combine day and time into a datetime timestamp
    df["timestamp"] = pd.to_datetime(
        "2023-01-0" + df[date_col].astype(str), format="%Y-%m-%d"
    ) + pd.to_timedelta(df[time_col])

    return df

def load_rr_data(user_dir: Path) -> pd.DataFrame:
    df = pd.read_csv(user_dir / "RR.csv")
    df = parse_time_columns(df, time_col="time", date_col="day")
    return df

def load_actigraph_data(user_dir: Path) -> pd.DataFrame:
    df = pd.read_csv(user_dir / "Actigraph.csv")
    df = parse_time_columns(df, time_col="time", date_col="day")
    return df

def load_sleep_data(user_dir: Path) -> pd.DataFrame:
    return pd.read_csv(user_dir / "sleep.csv")

def load_user_data(user_dir: Path) -> pd.DataFrame:
    acti = load_actigraph_data(user_dir)
    rr = load_rr_data(user_dir)

    df = pd.merge_asof(
        acti.sort_values("timestamp"),
        rr.sort_values("timestamp"),
        on="timestamp",
        direction="nearest"
    )

    # Fusion des colonnes HR si besoin
    if "HR_y" in df.columns and "HR_x" in df.columns:
        df["HR"] = df["HR_y"].fillna(df["HR_x"])
    elif "HR" not in df.columns and "HR_x" in df.columns:
        df["HR"] = df["HR_x"]
    elif "HR" not in df.columns and "HR_y" in df.columns:
        df["HR"] = df["HR_y"]

    # Nettoyage
    df = df.drop(columns=[
        "HR_x", "HR_y",
        "Unnamed: 0_x", "Unnamed: 0_y",
        "day_x", "day_y", "time_x", "time_y"
    ], errors="ignore")

    return df