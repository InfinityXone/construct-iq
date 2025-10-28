#!/usr/bin/env python3
import os, requests
from dotenv import load_dotenv

# Load credentials
load_dotenv(os.path.expanduser("~/.infinity-agent/.env"))
USER = os.getenv("BASIC_AUTH_USER")
PASS = os.getenv("BASIC_AUTH_PASS")

BASE = "https://unaiming-marhta-darkly.ngrok-free.dev"

def check(endpoint):
    r = requests.get(f"{BASE}{endpoint}", auth=(USER, PASS))
    print(endpoint, r.status_code, r.text)

print("🔍 Checking Infinity Agent...")
check("/health")
# Uncomment more tests as you add routes
# check("/memory/hydrate")
# check("/orchestrator/plan")
