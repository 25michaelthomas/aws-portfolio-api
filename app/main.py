from fastapi import FastAPI, UploadFile
import boto3, os
from functools import lru_cache
from .db import get_conn

app = FastAPI(title="Portfolio API")

@lru_cache
def get_s3():
    return boto3.client("s3")

def bucket():
    return os.environ.get("UPLOAD_BUCKET", "")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/items")
def list_items():
    with get_conn() as c, c.cursor() as cur:
        cur.execute("CREATE TABLE IF NOT EXISTS items (id SERIAL PRIMARY KEY, name TEXT);")
        cur.execute("SELECT id, name FROM items ORDER BY id;")
        return [{"id": r[0], "name": r[1]} for r in cur.fetchall()]

@app.post("/upload")
def upload(file: UploadFile):
    get_s3().upload_fileobj(file.file, bucket(), file.filename)
    return {"uploaded": file.filename}