#!/usr/bin/env bash
# Rebuild everything (same as: python3 run_all.py). Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")"
python3 -m pip install -r requirements.txt
python3 run_all.py
