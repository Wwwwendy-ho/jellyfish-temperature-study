"""Cross-platform rebuild: python run_all.py   (Windows, macOS, Linux). Stops at the first failing step."""
import subprocess, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parent
STEPS = ["scripts/01_download_noaa.py", "scripts/02_download_gbif.py", "scripts/build_db.py", "scripts/03_charts.py"]
for step in STEPS:
    print(f"\n=== {step} ===", flush=True)
    subprocess.run([sys.executable, str(ROOT / step)], cwd=ROOT, check=True)
print("\nDone. Results are in outputs/ (CSVs) and outputs/charts/ (PNGs).")
