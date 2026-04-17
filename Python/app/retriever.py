import numpy as np
import json
from sklearn.metrics.pairwise import cosine_similarity
from google.genai import types
from app.api_key import client_embed
from app.database import load_all


# Load RAG data ONCE (important)
rag_data = load_all()

product_ids = rag_data["product_ids"]
descriptions = rag_data["descriptions"]
names = rag_data["names"]
prices = rag_data["prices"]
sale_prices = rag_data["sale_prices"]
stocks = rag_data["stocks"]
specifications = rag_data["specifications"]
warranties = rag_data["warranties"]
vectors = rag_data["vectors"]


# =========================
# RETRIEVAL FUNCTION
# =========================
def retrieve_products(user_input, top_k=5):

    # 1. Embed query
    query_embedding = client_embed.models.embed_content(
        model="gemini-embedding-001",
        contents=user_input,
        config=types.EmbedContentConfig(task_type="RETRIEVAL_QUERY")
    ).embeddings[0].values

    # 2. Similarity search
    sims = cosine_similarity([query_embedding], vectors)[0]
    top_indices = np.argsort(sims)[::-1][:top_k]

    results = []

    for idx in top_indices:

        # 3. Safe parse specifications
        specs = specifications[idx]
        if isinstance(specs, str):
            try:
                specs = json.loads(specs)
            except:
                specs = {}
        elif specs is None:
            specs = {}

        # 4. Safe price handling
        price = float(prices[idx]) if prices[idx] is not None else 0.0
        sale_price = float(sale_prices[idx]) if sale_prices[idx] else None

        results.append({
            "product_id": product_ids[idx],
            "product_name": names[idx],
            "price": price,
            "sale_price": sale_price,
            "stock": stocks[idx] if stocks[idx] is not None else 0,
            "specifications": specs,
            "warranty_months": warranties[idx] if warranties[idx] else 0,
            "similarity": float(sims[idx])
        })

    return results
















