import os
import sys
import subprocess
import csv
from pathlib import Path

def main():
    print("=== API Token Configuration ===\n")
    
    # Get repo root from environment variable
    repo_root = os.environ.get("VI_FLO_ENGINE_ROOT")
    
    if not repo_root:
        print("ERROR: VI_FLO_ENGINE_ROOT environment variable not set")
        print("Please run setup_win.exe first to configure your environment")
        input("\nPress Enter to close...")
        return
    
    repo_root = Path(repo_root)
    tokens_file = repo_root / "tools" / "api_tokens.csv"
    
    print(f"Looking for: {tokens_file}")
    
    # Check if file exists
    if not tokens_file.is_file():
        print("\n⊘ api_tokens.csv not found")
        print("\nTo configure API access:")
        print("1. Obtain api_tokens.csv from the authorized person")
        print(f"2. Place it at: {tokens_file}")
        print("3. Run this script again")
        print("\nNote: This file contains sensitive credentials and should never be committed to Git.")
        input("\nPress Enter to close...")
        return
    
    # Read the CSV file
    try:
        with open(tokens_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            # Validate required columns
            if 'token_name' not in reader.fieldnames or 'token_value' not in reader.fieldnames:
                print("ERROR: api_tokens.csv must have columns 'token_name' and 'token_value'")
                input("\nPress Enter to close...")
                return
            
            tokens_set = 0
            for row in reader:
                token_name = row.get('token_name', '').strip()
                token_value = row.get('token_value', '').strip()
                
                if not token_name or not token_value:
                    print(f"⊘ Skipping empty row")
                    continue
                
                # Set environment variable
                try:
                    os.environ[token_name] = token_value
                    subprocess.run(f'setx {token_name} "{token_value}"', shell=True, check=True)
                    print(f"✓ Set: {token_name}")
                    tokens_set += 1
                except subprocess.CalledProcessError as e:
                    print(f"✗ Failed to set {token_name}: {e}")
            
            print(f"\n{tokens_set} API token(s) configured successfully")
            print("\nPlease restart any open R sessions to use them.")
            
    except Exception as e:
        print(f"\nERROR reading api_tokens.csv: {e}")
        input("\nPress Enter to close...")
        return
    
    input("\nConfiguration complete. Press Enter to close...")

if __name__ == "__main__":
    main()
