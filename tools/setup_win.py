import os
import sys
import subprocess
import tkinter as tk
from tkinter import filedialog, messagebox
from pathlib import Path

def main():
    # ---- Clear previous environment variables in THIS PROCESS ----
    os.environ.pop("VI_FLO_ENGINE_ROOT", None)
    os.environ.pop("VI_FLO_DATA_ROOT", None)
    print("Cleared VI_FLO_ENGINE_ROOT and VI_FLO_DATA_ROOT for new setup.")

    # ---- Detect folder of the running .exe (PyInstaller) or .py (development) ----
    if getattr(sys, 'frozen', False):
        repo_dir = Path(sys.executable).parent
    else:
        repo_dir = Path(__file__).resolve().parent.parent

    repo_dir = repo_dir.as_posix()
    print(f"Detected repo folder: {repo_dir}")

    # ---- Set environment variables in THIS PROCESS ----
    os.environ["VI_FLO_ENGINE_ROOT"] = repo_dir

    # ---- Also persist for future processes ----
    subprocess.run(f'setx VI_FLO_ENGINE_ROOT "{repo_dir}"', shell=True)

    # ---- Prompt for data folder ----
    root = tk.Tk()
    root.withdraw()

    print("\n=== Data Directory Selection ===")
    print("You must select an EXTERNAL data directory for VI-FLO.")
    print("This should NOT be inside the repository folder.")
    print("Example: D:/VI-FLO-Data/ or C:/Users/YourName/Documents/VI-FLO-Data/")
    
    data_dir = filedialog.askdirectory(
        title="Select VI-FLO External Data Directory"
    )

    if not data_dir:
        print("\nERROR: No data directory selected.")
        print("Setup cannot continue without a data directory.")
        print("\nPlease run setup again and select your external data folder.")
        input("\nPress Enter to close...")
        return
    
    data_dir = Path(data_dir).as_posix()
    print(f"\nSelected data folder: {data_dir}")
    print("Please wait...")

    # ---- Set environment variables in THIS PROCESS ----
    os.environ["VI_FLO_DATA_ROOT"] = data_dir
    subprocess.run(f'setx VI_FLO_DATA_ROOT "{data_dir}"', shell=True)

    print("\nEnvironment variables set successfully:")
    print(f"  VI_FLO_ENGINE_ROOT = {os.environ['VI_FLO_ENGINE_ROOT']}")
    print(f"  VI_FLO_DATA_ROOT   = {os.environ['VI_FLO_DATA_ROOT']}")
    print("\nPlease restart any open R sessions to use them.")

    # ---- Run datamapper.py IN-PROCESS ----
    try:
        if str(repo_dir) not in sys.path:
            sys.path.insert(0, str(repo_dir))

        from tools import datamapper
        datamapper.main()
    except Exception as e:
        print(f"\nERROR running datamapper: {e}")

    # ---- Check for API token configuration file ----
    tokens_file = Path(repo_dir) / "tools" / "api_tokens.csv"
    
    if tokens_file.is_file():
        # File exists - ask if they want to configure now
        configure_tokens = messagebox.askyesno(
            "API Token Configuration",
            "FOR AUTOMATIC DATA DOWNLOADS:\n\n"
            "api_tokens.csv file detected.\n\n"
            "Configure API access now?",
            parent=root
        )
        
        if configure_tokens:
            try:
                from tools import set_api_tokens
                set_api_tokens.main()
            except Exception as e:
                print(f"\nERROR running set_api_tokens: {e}")
        else:
            print("\n=== API Token Setup Skipped ===")
            print("To configure API access later, run:")
            print("python tools/set_api_tokens.py")
    else:
        # File not found - give instructions
        print("\n=== API Token Setup ===")
        print("No api_tokens.csv file found.")
        print("To configure API access later:")
        print("1. Obtain api_tokens.csv from the authorized person")
        print(f"2. Place it in: {repo_dir}/tools/api_tokens.csv")
        print("3. Run: python tools/set_api_tokens.py")

    input("\nSetup complete. Press Enter to close this window...")

if __name__ == "__main__":
    main()
