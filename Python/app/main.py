from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from uuid import uuid4
import psycopg2
import os
from dotenv import load_dotenv
from urllib.parse import urlparse

from google.genai import types
from app.decision import router as decision_router
from app.chat import router as chat_router
from app.retriever import router as retriever_router
from app.api_key import client_embed

load_dotenv()

# ============================
# FastAPI App
# ============================

app = FastAPI()

origins = [
    "https://rag.doantrang.online",
    "http://localhost:8000"
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================
# Health Check
# ============================

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.get("/health")
def health():
    return {"status": "ok", "version": "2.0"}

# ============================
# Database Helper (SAFE)
# ============================

def get_connection():
    jdbc_url = os.getenv("SPRING_DATASOURCE_URL")
    db_user = os.getenv("SPRING_DATASOURCE_USERNAME")
    db_password = os.getenv("SPRING_DATASOURCE_PASSWORD")

    if not jdbc_url:
        raise ValueError("Missing SPRING_DATASOURCE_URL")

    db_url = jdbc_url.replace("jdbc:", "")
    parsed = urlparse(db_url)

    return psycopg2.connect(
        host=parsed.hostname,
        database=parsed.path.lstrip("/"),
        user=db_user,
        password=db_password,
        port=parsed.port
    )

# ============================
# Session storage (temporary)
# ============================

session_histories = {}

# ============================
# Request Models
# ============================

class Message(BaseModel):
    text: str
    session_id: str | None = None


class UpdateEmbeddingRequest(BaseModel):
    product_id: int

# ============================
# Chat API
# ============================

@app.post("/chat")
def chat_api(msg: Message):
    session_id = msg.session_id or str(uuid4())

    if session_id not in session_histories:
        session_histories[session_id] = []

    conversation_history = session_histories[session_id]

    decision = decide_chat(msg.text, conversation_history)

    top_products = None
    prompt = msg.text

    if decision["action"] == "rag":
        top_products = retrieve_products(msg.text)

        retrieved_text = ""
        for p in top_products:
            sale_price = f" | Sale: {p['sale_price']}" if p['sale_price'] else ""
            warranty = f" | Bảo hành: {p['warranty_months']} tháng" if p['warranty_months'] > 0 else ""

            specs = ""
            if p.get("specifications"):
                specs_list = []
                if isinstance(p["specifications"], dict):
                    for k, v in p["specifications"].items():
                        specs_list.append(f"{k}: {v}")
                if specs_list:
                    specs = f" | Specs: {', '.join(specs_list[:3])}"

            retrieved_text += (
                f"- ID: {p['product_id']} | {p['product_name']} | Giá: {p['price']}"
                f"{sale_price} | Tồn kho: {p['stock']}{warranty}{specs} "
                f"(Độ liên quan: {p['similarity']:.2%})\n"
            )

        prompt = (
            f"User asked: {msg.text}\n"
            f"Here are relevant products:\n{retrieved_text}\n"
            f"If tồn kho is 0, do not recommend that product.\n"
            f"Answer naturally in Vietnamese."
        )

    answer = chat_with_gemini(prompt)

    conversation_history.append((msg.text, answer))
    session_histories[session_id] = conversation_history

    return {
        "session_id": session_id,
        "answer": answer,
        "conversation_history": conversation_history,
        "decision": decision,
        "retrieved_products": top_products if decision["action"] == "rag" else None
    }

# ============================
# Update Embedding API
# ============================

@app.post("/update-vector-by-product-id")
def update_vector(req: UpdateEmbeddingRequest):
    product_id = req.product_id

    # 1. Get description
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT description FROM products WHERE product_id = %s",
                (product_id,)
            )
            row = cursor.fetchone()

            if not row:
                raise HTTPException(status_code=404, detail="Product not found")

            description = row[0]

    if not description:
        raise HTTPException(status_code=400, detail="Description is empty")

    # 2. Generate embedding
    result = client_embed.models.embed_content(
        model="gemini-embedding-001",
        contents=[description],
        config=types.EmbedContentConfig(task_type="RETRIEVAL_DOCUMENT")
    )

    embedding_vector = result.embeddings[0].values
    embedding_str = str(list(embedding_vector))

    # 3. Update DB
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(
                "UPDATE products SET embedding = %s WHERE product_id = %s",
                (embedding_str, product_id)
            )
            conn.commit()

    return {
        "status": "success",
        "product_id": product_id,
        "embedding_length": len(embedding_vector)
    }