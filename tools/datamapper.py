import os
import sys
import pandas as pd
import tkinter as tk
from tkinter import filedialog
from datetime import datetime

def main():
    # ---- Determine engine root ----
    engine_root = os.environ.get("VI_FLO_ENGINE_ROOT")
    if not engine_root:
        print("Error: VI_FLO_ENGINE_ROOT environment variable not set.")
        sys.exit(1)

    # ---- Determine data root ----
    data_root = os.environ.get("VI_FLO_DATA_ROOT")
    if not data_root:
        assumed_data_root = os.path.join(engine_root, "data")
        if os.path.isdir(assumed_data_root):
            data_root = assumed_data_root
            print(f"Defaulting to data root: {data_root}")
        else:
            print(f"Data root not found: {assumed_data_root}")
            sys.exit(1)

    # ---- Paths for CSV files ----
    named_paths_csv = os.path.join(engine_root, "data", "named_paths.csv")
    datamap_csv = os.path.join(data_root, "datamap.csv")

    if not os.path.isfile(named_paths_csv):
        print(f"named_paths.csv not found: {named_paths_csv}")
        sys.exit(1)

    # ---- Load named paths ----
    named_paths_df = pd.read_csv(named_paths_csv)
    if 'named_path' not in named_paths_df.columns:
        print("Error: named_paths.csv must have a 'named_path' column")
        sys.exit(1)

    # ---- Load existing datamap if present ----
    if os.path.isfile(datamap_csv):
        datamap_df = pd.read_csv(datamap_csv)
    else:
        datamap_df = pd.DataFrame(columns=['named_path','absolute_path','date_set','repo_name'])

    # ---- GUI setup ----
    root = tk.Tk()
    root.withdraw()

    updated_rows = []

    for np_row in named_paths_df['named_path']:
        # Check if named_path exists in datamap
        existing_row = datamap_df.loc[datamap_df['named_path'] == np_row]

        if not existing_row.empty:
            existing_path = existing_row.iloc[0]['absolute_path']
            print(f"\nNamed path '{np_row}' already exists in datamap: {existing_path}")
            response = input("Is this correct? (Y/n): ").strip().lower()
            if response in ['y', 'yes', '']:
                updated_rows.append({
                    'named_path': np_row,
                    'absolute_path': existing_path,
                    'date_set': existing_row.iloc[0]['date_set'],
                    'repo_name': 'engine'
                })
                continue
            # else: fall through to ask GUI

        print(f"Please select folder for '{np_row}'")
        # always start browse in data_root
        selected_dir = filedialog.askdirectory(title=f"Select folder for {np_row}", initialdir=data_root)
        if not selected_dir:
            print(f"No folder selected for {np_row}, skipping this path.")
            continue
        selected_dir = selected_dir.rstrip("\\/")
        updated_rows.append({
            'named_path': np_row,
            'absolute_path': selected_dir,
            'date_set': datetime.now().isoformat(),
            'repo_name': 'engine'
        })

    # ---- Combine with untouched rows ----
    untouched_rows = datamap_df.loc[~datamap_df['named_path'].isin(named_paths_df['named_path'])]
    final_df = pd.concat([untouched_rows, pd.DataFrame(updated_rows)], ignore_index=True)

    # ---- Save datamap ----
    final_df.to_csv(datamap_csv, index=False)
    print(f"\nDatamap saved to {datamap_csv}")

if __name__ == "__main__":
    main()
