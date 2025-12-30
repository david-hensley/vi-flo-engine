import os
import sys
import shutil
import csv
import tkinter as tk
from tkinter import filedialog
from datetime import datetime
from pathlib import Path

def main():
    print("Running datamapper...")

    # ---- Determine engine root ----
    engine_root = os.environ.get("VI_FLO_ENGINE_ROOT")
    if not engine_root:
        print("Error: VI_FLO_ENGINE_ROOT environment variable not set.")
        sys.exit(1)
    engine_root = Path(engine_root).resolve()

    # ---- Determine data root ----
    data_root = os.environ.get("VI_FLO_DATA_ROOT")
    if not data_root:
        assumed_data_root = engine_root / "data"
        if assumed_data_root.is_dir():
            data_root = assumed_data_root
            print(f"Defaulting to data root: {data_root}")
        else:
            print(f"Data root not found: {assumed_data_root}")
            sys.exit(1)
    data_root = Path(data_root).resolve()

    # ---- Paths for CSV files ----
    engine_data_dir = engine_root / "data"
    named_paths_csv = engine_data_dir / "named_paths.csv"
    datamap_csv = data_root / "datamap.csv"
    default_datamap_csv = engine_data_dir / "default_datamap.csv"
    sample_datamap_csv  = engine_data_dir / "sample_datamap.csv"

    if not named_paths_csv.is_file():
        print(f"named_paths.csv not found: {named_paths_csv}")
        sys.exit(1)

    # ------------------------------------------------------------------
    # EARLY DEFAULT MAP OPTION
    # ------------------------------------------------------------------
    using_sample_data = data_root.samefile(engine_data_dir.resolve())

    if using_sample_data:
        print("\nYou are using SAMPLE DATA.")
        response = input("Would you like to default to the SAMPLE data map? (Y/N): ").strip().lower()
        if response in ["y", "yes", ""]:
            if not sample_datamap_csv.is_file():
                print(f"ERROR: sample_datamap.csv not found at {sample_datamap_csv}")
                sys.exit(1)
            shutil.copyfile(sample_datamap_csv, datamap_csv)
            print(f"Sample datamap written to: {datamap_csv}")
            return
    else:
        print("\nExternal data root detected.")
        response = input("Would you like to use the DEFAULT data map? (Y/N): ").strip().lower()
        if response in ["y", "yes", ""]:
            if not default_datamap_csv.is_file():
                print(f"ERROR: default_datamap.csv not found at {default_datamap_csv}")
                sys.exit(1)
            shutil.copyfile(default_datamap_csv, datamap_csv)
            print(f"Default datamap written to: {datamap_csv}")
            return

    # ------------------------------------------------------------------
    # FALL THROUGH TO INTERACTIVE MAPPING
    # ------------------------------------------------------------------
    print("\nProceeding with interactive data mapping...")

    # ---- Load named paths ----
    with open(named_paths_csv, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        named_paths_list = [row['named_path'] for row in reader]

    # ---- Load existing datamap if present ----
    if datamap_csv.is_file():
        with open(datamap_csv, newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            datamap_list = [row for row in reader]
    else:
        datamap_list = []

    # ---- GUI setup ----
    root = tk.Tk()
    root.withdraw()

    updated_rows = []

    for np_row in named_paths_list:
        existing_row = next((row for row in datamap_list if row['named_path'] == np_row), None)

        if existing_row:
            existing_path = existing_row['absolute_path']
            print(f"\nNamed path '{np_row}' already exists: {existing_path}")
            response = input("Is this correct? (Y/N): ").strip().lower()
            if response in ['y', 'yes', '']:
                updated_rows.append({
                    'named_path': np_row,
                    'absolute_path': existing_path,
                    'date_set': existing_row['date_set'],
                    'repo_name': 'engine'
                })
                continue

        print(f"Please select folder for '{np_row}'")
        selected_dir = filedialog.askdirectory(
            title=f"Select folder for {np_row}",
            initialdir=str(data_root)
        )

        if not selected_dir:
            print(f"No folder selected for {np_row}, skipping.")
            continue

        updated_rows.append({
            'named_path': np_row,
            'absolute_path': Path(selected_dir).resolve().as_posix(),
            'date_set': datetime.now().isoformat(),
            'repo_name': 'engine'
        })

    # ---- Preserve untouched rows ----
    untouched_rows = [row for row in datamap_list if row['named_path'] not in named_paths_list]
    final_rows = untouched_rows + updated_rows

    # ---- Write CSV ----
    fieldnames = ['named_path', 'absolute_path', 'date_set', 'repo_name']
    with open(datamap_csv, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(final_rows)

    print(f"\nDatamap saved to {datamap_csv}")

if __name__ == "__main__":
    main()
