import psycopg2
import numpy as np
import ast
import os
from dotenv import load_dotenv

load_dotenv()


# ========================
# DATABASE CONNECTION
# ========================
def get_connection():
    return psycopg2.connect(
        host=os.getenv("DATABASE_HOST"),
        dbname=os.getenv("DATABASE_NAME"),
        user=os.getenv("DATABASE_USER"),
        password=os.getenv("DATABASE_PASSWORD"),
        port=int(os.getenv("DATABASE_PORT"))
    )


# ========================
# LOAD PRODUCT DATA (RAG)
# ========================
def load_product_data(limit=1000):
    conn = get_connection()
    cursor = conn.cursor()

    query = """
        SELECT
            p.product_id,
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
        FROM products p
        JOIN product_items pi ON p.product_id = pi.product_id
        LEFT JOIN serial_numbers sn ON pi.product_item_id = sn.product_item_id
        LEFT JOIN warranties w ON sn.serial_id = w.serial_id
        WHERE pi.embedding IS NOT NULL
          AND pi.status = 'active'
        GROUP BY
            p.product_id,
            pi.product_item_id,
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
    product_ids = [d[0] for d in data]
    descriptions = [d[1] for d in data]
    names = [d[6] for d in data]
    prices = [d[3] for d in data]
    sale_prices = [d[4] for d in data]
    stocks = [d[5] for d in data]
    specifications = [d[7] for d in data]
    warranties = [d[8] if d[8] else 0 for d in data]

    vectors = np.array([
        np.array(ast.literal_eval(d[2]), dtype=float) if d[2] else np.zeros(1536)
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




















