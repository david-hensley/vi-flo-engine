import os
import sys
import subprocess
import tkinter as tk
from tkinter import filedialog

def main():
    # Detect folder of the running .exe (PyInstaller) or .py (development)
    if getattr(sys, 'frozen', False):
        # Running as compiled .exe
        repo_dir = os.path.dirname(sys.executable)
    else:
        # Running as Python script in /tools
        repo_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

    # Normalize to forward slashes
    repo_dir = repo_dir.replace("\\", "/")
    print(f"Detected repo folder: {repo_dir}")

    # Set engine root env variable
    subprocess.run(f'setx VI_FLO_ENGINE_ROOT "{repo_dir}"', shell=True)

    # ---- Prompt for data folder ----
    root = tk.Tk()
    root.withdraw()

    print("Please select the VI-FLO data directory (Cancel to use default)...")
    data_dir = filedialog.askdirectory(title="Select VI-FLO Data Directory")

    if not data_dir:
        assumed_data_dir = os.path.join(repo_dir, "data").replace("\\", "/")
        if os.path.isdir(assumed_data_dir):
            data_dir = assumed_data_dir
            print(f"No selection made. Defaulting to: {data_dir}")
        else:
            print("\nWARNING:")
            print(f"Expected data directory not found: {assumed_data_dir}")
            print("The core VI-FLO repo structure appears to be altered.")
            print("Please restore the original repository structure with the /data folder,")
            print("or rerun setup and select a valid data directory.")
            print("Repository root path was NOT set, core data repository was NOT set.")
            input("\nPress Enter to close this window...")
            return
    else:
        data_dir = data_dir.replace("\\", "/")
        print(f"Selected data folder: {data_dir}")

    subprocess.run(f'setx VI_FLO_DATA_ROOT "{data_dir}"', shell=True)

    print("\nEnvironment variables set successfully:")
    print(f"  VI_FLO_ENGINE_ROOT = {repo_dir}")
    print(f"  VI_FLO_DATA_ROOT   = {data_dir}")
    print("\nPlease restart any open R sessions to use them.")

    input("\nSetup complete. Press Enter to close this window...")

if __name__ == "__main__":
    main()

