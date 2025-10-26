import asyncio
import httpx
from pydantic import BaseModel
from dotenv import load_dotenv
load_dotenv()

class Notice(BaseModel):
    id: str
    title: str

async def fetch_example():
    async with httpx.AsyncClient(timeout=20) as client:
        r = await client.get("https://example.com")
        return Notice(id="demo", title=f"Example {r.status_code}")

def run():
    notice = asyncio.run(fetch_example())
    print({"ingested": notice.model_dump()})

if __name__ == "__main__":
    run()
