import os
import sys
import subprocess

def main():
    # Detect folder of the running .exe (PyInstaller) or .py (development)
    if getattr(sys, 'frozen', False):
        # Running as compiled .exe
        repo_dir = os.path.dirname(sys.executable)
    else:
        # Running as Python script
        repo_dir = os.path.dirname(os.path.abspath(__file__))

    # Remove trailing slash/backslash
    repo_dir = repo_dir.rstrip("\\/")

    print(f"Detected repo folder: {repo_dir}")

    # Set persistent user-level environment variable (Windows)
    # This requires a new terminal/R session to take effect
    subprocess.run(f'setx VI_FLO_ENGINE_ROOT "{repo_dir}"', shell=True)

    print("Environment variable VI_FLO_ENGINE_ROOT set successfully.")
    print("Please restart any open R sessions to use it.")

if __name__ == "__main__":
    main()
