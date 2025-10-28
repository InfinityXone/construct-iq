FROM python:3.11-slim
WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt || true

COPY . /app

# If FastAPI detected in main.py, uvicorn; else run main.py
CMD bash -lc 'python - <<PY
import os, re
p="main.py"
if os.path.exists(p):
    t=open(p,"r",encoding="utf-8",errors="ignore").read()
    if re.search(r"FastAPI\\s*\\(", t):
        print("uvicorn main:app --host 0.0.0.0 --port 8080")
    else:
        print("python main.py")
else:
    print("python -c \\"print(\\'No main.py; customize CMD\\')\\"")
PY' | xargs -r sh -c
