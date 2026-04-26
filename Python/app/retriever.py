import json
from functools import lru_cache

import numpy as np
from sklearn.metrics.pairwise import cosine_similarity

from app.api_key import get_embedding
from app.database import load_all


@lru_cache(maxsize=1)
def _get_rag_data_cached():
    """
    Lazy loading of RAG data - cached after first call.
    This avoids loading DB at import time.
    """
    return load_all()


def get_rag_data():
    """
    Get RAG data with lazy loading.
    Caches the result to avoid repeated DB queries.
    """
    return _get_rag_data_cached()


def retrieve_products(user_input: str, top_k: int = 5) -> list[dict]:
    """
    Retrieve the most relevant products based on user input using
    vector similarity search (RAG pattern).

    Args:
        user_input: The user's search query
        top_k: Number of top results to return

    Returns:
        List of product dictionaries with similarity scores
    """
    data = get_rag_data()

    product_ids = data["product_ids"]
    names = data["names"]
    prices = data["prices"]
    sale_prices = data["sale_prices"]
    stocks = data["stocks"]
    specifications = data["specifications"]
    warranties = data["warranties"]
    vectors = data["vectors"]

    try:
        query_embedding = get_embedding(user_input)
    except Exception as e:
        raise RuntimeError(f"Failed to generate embedding: {e}")

    sims = cosine_similarity([query_embedding], vectors)[0]
    top_indices = np.argsort(sims)[::-1][:top_k]

    results = []

    for idx in top_indices:
        specs = specifications[idx]
        if isinstance(specs, str):
            try:
                specs = json.loads(specs)
            except (json.JSONDecodeError, ValueError):
                specs = {}
        elif specs is None:
            specs = {}

        price = float(prices[idx]) if prices[idx] is not None else 0.0
        sale_price = float(sale_prices[idx]) if sale_prices[idx] else None

        results.append({
            "product_item_id": product_ids[idx],
            "product_name": names[idx],
            "price": price,
            "sale_price": sale_price,
            "stock": stocks[idx] if stocks[idx] is not None else 0,
            "specifications": specs,
            "warranty_months": warranties[idx] if warranties[idx] else 0,
            "similarity": float(sims[idx])
        })

    return results


def generate_product_embedding(description: str) -> list[float]:
    """
    Generate embedding for a product description.

    Args:
        description: Product description text

    Returns:
        List of float values representing the embedding vector
    """
    return get_embedding(description)
