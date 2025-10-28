#!/bin/bash
source "$HOME/infinity-x-one-swarm/.venv/bin/activate"
cd "$(dirname "$0")"
uvicorn main:app --host 0.0.0.0 --port 8080
