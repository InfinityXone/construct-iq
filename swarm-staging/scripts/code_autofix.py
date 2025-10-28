#!/usr/bin/env python3
import os, subprocess, sys

print("🧠 Running Code Auto-Fix...")

def run(cmd):
    print(f"→ {cmd}")
    subprocess.run(cmd, shell=True, check=False)

# Lint / format all Python files
run("find . -name '*.py' -not -path './venv/*' -exec autopep8 --in-place --aggressive --aggressive {} +")
run("black . || true")
run("isort . || true")

# Dependency repair
run("pip install --upgrade -r requirements.txt --break-system-packages || true")

print("✅ Code Auto-Fix complete.")
