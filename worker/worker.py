import os, time
import redis
from dotenv import load_dotenv
load_dotenv()
r = redis.from_url(os.getenv("REDIS_URL","redis://redis:6379/0"))
def main():
    print("[worker] started; polling every 10s")
    while True:
        r.set("ciq:last_heartbeat", int(time.time()))
        time.sleep(10)
if __name__ == "__main__":
    main()
