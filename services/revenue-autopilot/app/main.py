from fastapi import FastAPI, Request
import time, os, random

app = FastAPI()

@app.get('/healthz')
def healthz():
    return {'ok': True, 'ts': time.time(), 'service': os.getenv('SERVICE_NAME','app')}

@app.get('/')
def root():
    return {'status':'ok'}

@app.get('/jobs/tick')
def tick():
    return {'status':'ran', 'seed': random.randint(0, 1000000)}
