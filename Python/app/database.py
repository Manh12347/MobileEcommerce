import ast
import os
from pathlib import Path
from urllib.parse import urlparse

import numpy as np
import psycopg2
from dotenv import load_dotenv

repo_root = Path(__file__).resolve().parents[2]
load_dotenv(dotenv_path=repo_root / "Backend" / ".env")


# ========================
# DATABASE CONNECTION
# ========================
def get_connection():
    jdbc_url = os.getenv("SPRING_DATASOURCE_URL")
    db_user = os.getenv("SPRING_DATASOURCE_USERNAME")
    db_password = os.getenv("SPRING_DATASOURCE_PASSWORD")

    if not jdbc_url:
        raise ValueError("Missing SPRING_DATASOURCE_URL")

    if jdbc_url.startswith("jdbc:"):
        jdbc_url = jdbc_url.replace("jdbc:", "", 1)

    parsed = urlparse(jdbc_url)

    return psycopg2.connect(
        host=parsed.hostname,
        dbname=parsed.path.lstrip("/"),
        user=db_user,
        password=db_password,
        port=parsed.port
    )


# ========================
# LOAD PRODUCT DATA (RAG)
# ========================
def load_product_data(limit=1000):
    conn = get_connection()
    cursor = conn.cursor()

    query = """
        SELECT
            pi.product_item_id AS id,
            pi.product_item_id,
            pi.description,
            pi.embedding,
            pi.price,
            pi.sale_price,
            pi.stock_quantity,
            p.name,
            pi.specifications,
            COALESCE(
                MAX(((w.end_date - w.start_date)::INT) / 30),
                0
            ) AS warranty_months
        FROM product_items pi
        JOIN products p ON pi.product_id = p.product_id
        LEFT JOIN serial_numbers sn ON pi.product_item_id = sn.product_item_id
        LEFT JOIN warranties w ON sn.serial_id = w.serial_id
        WHERE pi.embedding IS NOT NULL
          AND pi.status = 'active'
        GROUP BY
            pi.product_item_id,
            p.product_id,
            p.name,
            pi.description,
            pi.embedding,
            pi.price,
            pi.sale_price,
            pi.stock_quantity,
            pi.specifications
        LIMIT %s
    """

    cursor.execute(query, (limit,))
    data = cursor.fetchall()

    cursor.close()
    conn.close()

    return data


# ========================
# PARSE DATA FOR RAG
# ========================
def build_rag_data(data):
    product_ids = [d[1] for d in data]
    descriptions = [d[2] for d in data]
    names = [d[7] for d in data]
    prices = [d[4] for d in data]
    sale_prices = [d[5] for d in data]
    stocks = [d[6] for d in data]
    specifications = [d[8] for d in data]
    warranties = [d[9] if d[9] else 0 for d in data]

    vectors = np.array([
        np.array(ast.literal_eval(d[3]), dtype=float) if d[3] else np.zeros(768)
        for d in data
    ])

    return {
        "product_ids": product_ids,
        "descriptions": descriptions,
        "names": names,
        "prices": prices,
        "sale_prices": sale_prices,
        "stocks": stocks,
        "specifications": specifications,
        "warranties": warranties,
        "vectors": vectors
    }


# ========================
# OPTIONAL: LOAD ALL IN ONE CALL
# ========================
def load_all(limit=1000):
    data = load_product_data(limit)
    return build_rag_data(data)




















