import os
import traceback
from contextlib import asynccontextmanager
from pathlib import Path
from urllib.parse import urlparse
from uuid import uuid4

import psycopg2
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from app.chat import chat_with_gemini
from app.decision import decide_chat
from app.retriever import get_rag_data, generate_product_embedding, retrieve_products

repo_root = Path(__file__).resolve().parents[2]
load_dotenv(dotenv_path=repo_root / "Backend" / ".env")

import logging
logging.basicConfig(level=logging.INFO)


# ============================
# LIFESPAN CONTEXT MANAGER
# ============================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Startup and shutdown events for FastAPI.
    RAG data is loaded lazily, so no heavy initialization here.
    """
    print("Starting RAG Chatbot Service...")
    print("RAG data will be loaded on first request (lazy loading)")
    yield
    print("Shutting down RAG Chatbot Service...")


# ============================
# FastAPI App
# ============================

app = FastAPI(lifespan=lifespan)

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


# ============================
# Database Helper
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
# Session Storage
# ============================

session_histories = {}


# ============================
# Request Models
# ============================

class Message(BaseModel):
    text: str
    session_id: str | None = None


class UpdateEmbeddingRequest(BaseModel):
    product_item_id: int


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
                f"- ID: {p['product_item_id']} | {p['product_name']} | Giá: {p['price']}"
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
    product_item_id = req.product_item_id
    logging.info(f"Update embedding request for product_item_id: {product_item_id}")

    try:
        with get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT description FROM product_items WHERE product_item_id = %s",
                    (product_item_id,)
                )
                row = cursor.fetchone()

                if not row:
                    raise HTTPException(status_code=404, detail="Product Item not found")

                description = row[0]
                logging.info(f"Description length: {len(description) if description else 0}")

        if not description:
            raise HTTPException(status_code=400, detail="Description is empty")

        logging.info("Calling generate_product_embedding...")
        embedding_vector = generate_product_embedding(description)
        logging.info(f"Embedding generated, length: {len(embedding_vector)}")

        embedding_str = "[" + ",".join(map(str, embedding_vector)) + "]"
        logging.info(f"Embedding string format prepared, length: {len(embedding_str)}")

        with get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "UPDATE product_items SET embedding = %s::vector WHERE product_item_id = %s",
                    (embedding_str, product_item_id)
                )
                conn.commit()

        logging.info("Embedding updated successfully")
        return {
            "status": "success",
            "product_item_id": product_item_id,
            "embedding_length": len(embedding_vector)
        }
    except Exception as e:
        logging.error(f"Error updating embedding: {e}")
        logging.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))
