# prepare_all.py

from src.data.preprocess import prepare_user_data
from pathlib import Path

def main():
    raw_base = Path("data/raw")
    out_base = Path("data/processed")

    user_dirs = raw_base.glob("user_*")
    for user_dir in user_dirs:
        user_id = user_dir.name
        print(f"📦 Traitement de {user_id}...")
        try:
            prepare_user_data(user_id, raw_base=raw_base, out_base=out_base)
        except Exception as e:
            print(f"❌ Erreur avec {user_id} : {e}")

if __name__ == "__main__":
    main()