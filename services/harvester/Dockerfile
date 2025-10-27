FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
# If your harvester doesn't expose HTTP, that's fine; keep /health minimal in the code if you want checks.
CMD ["python","-u","ingest_calc.py"]
