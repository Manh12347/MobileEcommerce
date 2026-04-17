from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from uuid import uuid4
import psycopg2
from fastapi import FastAPI, HTTPException
import os
from dotenv import load_dotenv

from google import genai
from google.genai import types

from app.decision import decide_chat
from app.retriever import retrieve_products
from app.chat import chat_with_gemini
from app.api_key import client_embed

load_dotenv()

# ============================
# FastAPI App
# ============================

app = FastAPI()

origins = [
    "http://siudev.icu",
    "https://siudev.icu",
    "*",
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
def health():
    return {"status": "ok", "version": "1.0"}

# Database connection
conn = psycopg2.connect(
    host=os.getenv("DATABASE_HOST", "34.63.76.213"),
    dbname=os.getenv("DATABASE_NAME", "MobileEcommerce"),
    user=os.getenv("DATABASE_USER", "postgres"),
    password=os.getenv("DATABASE_PASSWORD", "123456789"),
    port=int(os.getenv("DATABASE_PORT", 5432))
)
cursor = conn.cursor()

# ============================
# Session histories
# ============================

session_histories = {}


# ============================
# Request Model
# ============================

class Message(BaseModel):
    text: str
    session_id: str | None = None


# ============================
# Chat API
# ============================

@app.post("/chat")
def chat_api(msg: Message):
    # Create session_id if not exist
    session_id = msg.session_id or str(uuid4())

    # Initialize history for new session
    if session_id not in session_histories:
        session_histories[session_id] = []

    conversation_history = session_histories[session_id]

    # Decide intent / action
    decision = decide_chat(msg.text, conversation_history)
    
    top_products = None
    prompt = msg.text

    # If RAG mode => retrieve products
    if decision["action"] == "rag":
        top_products = retrieve_products(msg.text)
        
        # Format product details for Gemini
        retrieved_text = ""
        for p in top_products:
            sale_price_text = f" | Sale: {p['sale_price']}" if p['sale_price'] else ""
            warranty_text = f" | Bảo hành: {p['warranty_months']} tháng" if p['warranty_months'] > 0 else ""
            specs_text = ""
            
            # Include specifications if available
            if p['specifications']:
                specs_list = []
                if isinstance(p['specifications'], dict):
                    for key, value in p['specifications'].items():
                        specs_list.append(f"{key}: {value}")
                if specs_list:
                    specs_text = f" | Specs: {', '.join(specs_list[:3])}"  # Show max 3 specs
            
            retrieved_text += f"- ID: {p['product_id']} | {p['product_name']} | Giá: {p['price']}{sale_price_text} | Tồn kho: {p['stock']}{warranty_text}{specs_text} (Độ liên quan: {p['similarity']:.2%})\n"
        
        prompt = (
            f"User asked: {msg.text}\n"
            f"Here are relevant products:\n{retrieved_text}\n"
            f"If tồn kho is 0, do not recommend that product.\n"
            f"Answer naturally in Vietnamese."
        )
    else:
        prompt = msg.text

    # Gemini answer
    answer = chat_with_gemini(prompt)

    # Save conversation
    conversation_history.append((msg.text, answer))
    session_histories[session_id] = conversation_history

    return {
        "session_id": session_id,
        "answer": answer,
        "conversation_history": conversation_history,
        "decision": decision,
        "retrieved_products": top_products if decision["action"] == "rag" else None
    }


class UpdateEmbeddingRequest(BaseModel):
    product_id: int


@app.post("/update-vector-by-product-id")
def update_vector(req: UpdateEmbeddingRequest):
    """Generate and update embedding vector for a product"""
    product_id = req.product_id

    # 1. Get product description
    cursor.execute("SELECT description FROM products WHERE product_id = %s", (product_id,))
    row = cursor.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Product not found")

    description = row[0]

    if not description:
        raise HTTPException(status_code=400, detail="Description is empty, cannot generate embedding")

    # 2. Generate embedding vector
    result = client_embed.models.embed_content(
        model="gemini-embedding-001",
        contents=[description],
        config=types.EmbedContentConfig(task_type="RETRIEVAL_DOCUMENT")
    )

    embedding_vector = result.embeddings[0].values
    # Convert to string format for postgres storage
    embedding_str = str(list(embedding_vector))

    # 3. Update database
    cursor.execute(
        "UPDATE products SET embedding = %s WHERE product_id = %s",
        (embedding_str, product_id)
    )
    conn.commit()

    return {
        "status": "success",
        "product_id": product_id,
        "embedding_length": len(embedding_vector),
        "message": "Embedding updated successfully"
    }