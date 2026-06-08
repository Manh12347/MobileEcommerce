import json
import os
import time
from functools import lru_cache

import numpy as np
from sklearn.metrics.pairwise import cosine_similarity

from app.api_key import get_embedding
from app.database import load_all


RAG_CACHE_TTL_SECONDS = int(os.getenv("RAG_CACHE_TTL_SECONDS", "300"))


@lru_cache(maxsize=2)
def _get_rag_data_cached(cache_bucket: int):
    """
    Lazy loading of RAG data - cached by time bucket.
    This avoids loading DB at import time while still picking up image/url edits.
    """
    return load_all()


def get_rag_data():
    """
    Get RAG data with lazy loading and a short TTL.
    Set RAG_CACHE_TTL_SECONDS=0 to disable caching in development.
    """
    if RAG_CACHE_TTL_SECONDS <= 0:
        return load_all()

    cache_bucket = int(time.time() // RAG_CACHE_TTL_SECONDS)
    return _get_rag_data_cached(cache_bucket)


def clear_rag_cache():
    """Clear cached product data after known catalog/vector changes."""
    _get_rag_data_cached.cache_clear()


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
    skus = data["skus"]
    main_image_urls = data["main_image_urls"]
    category_names = data["category_names"]
    descriptions = data["descriptions"]
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
            "similarity": float(sims[idx]),
            "sku": skus[idx],
            "description": descriptions[idx],
            "main_image_url": main_image_urls[idx],
            "category_name": category_names[idx]
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
