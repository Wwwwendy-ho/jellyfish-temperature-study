# Rebuild everything (same as: python run_all.py). Run from the repo root:  .\run_all.ps1
# If PowerShell blocks the script: powershell -ExecutionPolicy Bypass -File .\run_all.ps1
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot
python -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) { throw "pip install failed" }
python run_all.py
if ($LASTEXITCODE -ne 0) { throw "run_all.py failed" }
