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
            ) AS warranty_months,
            pi.sku,
            pi.main_image_url,
            c.name AS category_name
        FROM product_items pi
        JOIN products p ON pi.product_id = p.product_id
        JOIN categories c ON p.category_id = c.category_id
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
            pi.specifications,
            pi.sku,
            pi.main_image_url,
            c.name
        LIMIT %s
    """

    cursor.execute(query, (limit,))
    data = cursor.fetchall()

    cursor.close()
    conn.close()

    return data


def load_all_active_products():
    conn = get_connection()
    cursor = conn.cursor()

    query = """
        SELECT
            pi.product_item_id,
            pi.description,
            pi.price,
            pi.sale_price,
            pi.stock_quantity,
            p.name,
            pi.specifications,
            COALESCE(
                MAX(((w.end_date - w.start_date)::INT) / 30),
                0
            ) AS warranty_months,
            pi.sku,
            pi.main_image_url,
            c.name AS category_name
        FROM product_items pi
        JOIN products p ON pi.product_id = p.product_id
        JOIN categories c ON p.category_id = c.category_id
        LEFT JOIN serial_numbers sn ON pi.product_item_id = sn.product_item_id
        LEFT JOIN warranties w ON sn.serial_id = w.serial_id
        WHERE pi.status = 'active'
        GROUP BY
            pi.product_item_id,
            p.product_id,
            p.name,
            pi.description,
            pi.price,
            pi.sale_price,
            pi.stock_quantity,
            pi.specifications,
            pi.sku,
            pi.main_image_url,
            c.name
    """

    cursor.execute(query)
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
    skus = [d[10] for d in data]
    main_image_urls = [d[11] for d in data]
    category_names = [d[12] for d in data]

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
        "skus": skus,
        "main_image_urls": main_image_urls,
        "category_names": category_names,
        "vectors": vectors
    }


# ========================
# VIRTUAL PRODUCTS & EMBEDDINGS
# ========================

import json

VIRTUAL_PRODUCTS = [
    {
        "product_item_id": 99901,
        "product_name": "Nguồn MSI MAG A650BN 650W",
        "price": 1450000.0,
        "sale_price": None,
        "stock": 10,
        "warranty_months": 36,
        "sku": "PSU-MSI-A650BN",
        "description": "Nguồn MSI MAG A650BN 650W 80 Plus Bronze",
        "main_image_url": "https://doantrang.online/v1/api/uploads/products/msi_mag_a650bn.webp",
        "category_name": "PSU",
        "specifications": {
            "compatibility": {
                "wattage_w": 650,
                "form_factor": "ATX",
                "efficiency": "80 Plus Bronze",
                "power_connectors": [
                    {"type": "24-pin", "count": 1},
                    {"type": "8-pin CPU", "count": 2},
                    {"type": "6+2-pin PCIe", "count": 2},
                    {"type": "SATA", "count": 5}
                ]
            }
        }
    },
    {
        "product_item_id": 99902,
        "product_name": "Nguồn Corsair RM850e 850W Gold",
        "price": 2990000.0,
        "sale_price": None,
        "stock": 5,
        "warranty_months": 36,
        "sku": "PSU-CORSAIR-RM850E",
        "description": "Nguồn Corsair RM850e 850W Gold Fully Modular",
        "main_image_url": "https://doantrang.online/v1/api/uploads/products/corsair_rm850e.webp",
        "category_name": "PSU",
        "specifications": {
            "compatibility": {
                "wattage_w": 850,
                "form_factor": "ATX",
                "efficiency": "80 Plus Gold",
                "power_connectors": [
                    {"type": "24-pin", "count": 1},
                    {"type": "8-pin CPU", "count": 2},
                    {"type": "6+2-pin PCIe", "count": 4},
                    {"type": "SATA", "count": 7}
                ]
            }
        }
    },
    {
        "product_item_id": 99903,
        "product_name": "SSD Samsung 990 Pro 1TB M.2 NVMe",
        "price": 2490000.0,
        "sale_price": None,
        "stock": 15,
        "warranty_months": 60,
        "sku": "SSD-SAMSUNG-990PRO-1TB",
        "description": "SSD Samsung 990 Pro 1TB M.2 NVMe PCIe Gen 4.0",
        "main_image_url": "https://doantrang.online/v1/api/uploads/products/samsung_990pro.webp",
        "category_name": "SSD/HDD",
        "specifications": {
            "compatibility": {
                "requires_m2_slot": True,
                "form_factor": "M.2 2280",
                "requires_pcie_generation": "Gen 4",
                "capacity_gb": 1000
            }
        }
    },
    {
        "product_item_id": 99904,
        "product_name": "SSD Kingston NV2 500GB M.2",
        "price": 990000.0,
        "sale_price": None,
        "stock": 20,
        "warranty_months": 36,
        "sku": "SSD-KINGSTON-NV2-500GB",
        "description": "SSD Kingston NV2 500GB M.2 NVMe PCIe Gen 4.0",
        "main_image_url": "https://doantrang.online/v1/api/uploads/products/kingston_nv2.webp",
        "category_name": "SSD/HDD",
        "specifications": {
            "compatibility": {
                "requires_m2_slot": True,
                "form_factor": "M.2 2280",
                "requires_pcie_generation": "Gen 4",
                "capacity_gb": 500
            }
        }
    },
    {
        "product_item_id": 99905,
        "product_name": "HDD Seagate BarraCuda 2TB 3.5\"",
        "price": 1590000.0,
        "sale_price": None,
        "stock": 8,
        "warranty_months": 24,
        "sku": "HDD-SEAGATE-2TB",
        "description": "HDD Seagate BarraCuda 2TB 3.5 inch SATA 3",
        "main_image_url": "https://doantrang.online/v1/api/uploads/products/seagate_2tb.webp",
        "category_name": "SSD/HDD",
        "specifications": {
            "compatibility": {
                "requires_sata_port": 1,
                "requires_sata_power": 1,
                "form_factor": "3.5 inch",
                "capacity_gb": 2000
            }
        }
    }
]

_virtual_embeddings = None

def build_rich_embedding_text_local(name: str | None, category: str | None, specifications: str | dict | None, description: str | None) -> str:
    parts = []
    if name:
        parts.append(f"Name: {name}")
    if category:
        parts.append(f"Category: {category}")
    if specifications:
        specs_dict = {}
        if isinstance(specifications, str):
            try:
                specs_dict = json.loads(specifications)
            except:
                pass
        elif isinstance(specifications, dict):
            specs_dict = specifications
        if specs_dict:
            specs_parts = [f"{k}: {v}" for k, v in specs_dict.items()]
            parts.append(f"Specifications: {', '.join(specs_parts)}")
    if description:
        parts.append(f"Description: {description}")
    
    if not parts:
        return "Unknown Product"
    return " | ".join(parts)

def get_virtual_embeddings():
    global _virtual_embeddings
    if _virtual_embeddings is not None:
        return _virtual_embeddings
    
    from app.api_key import get_embeddings_batch
    
    texts = []
    for p in VIRTUAL_PRODUCTS:
        rich_text = build_rich_embedding_text_local(
            p["product_name"],
            p["category_name"],
            p["specifications"],
            p["description"]
        )
        texts.append(rich_text)
        
    try:
        _virtual_embeddings = get_embeddings_batch(texts)
        print("Generated virtual product embeddings successfully.")
    except Exception as e:
        print("Error generating virtual product embeddings:", e)
        _virtual_embeddings = [[0.0]*768 for _ in range(len(VIRTUAL_PRODUCTS))]
        
    return _virtual_embeddings


# ========================
# OPTIONAL: LOAD ALL IN ONE CALL
# ========================
def load_all(limit=1000):
    db_data = list(load_product_data(limit))
    
    # Generate and append virtual products RAG data
    vemb = get_virtual_embeddings()
    for idx, p in enumerate(VIRTUAL_PRODUCTS):
        row = (
            p["product_item_id"],              # 0
            p["product_item_id"],              # 1
            p["description"],                  # 2
            str(vemb[idx]),                    # 3
            p["price"],                        # 4
            p["sale_price"],                   # 5
            p["stock"],                        # 6
            p["product_name"],                 # 7
            json.dumps(p["specifications"]),   # 8
            p["warranty_months"],              # 9
            p["sku"],                          # 10
            p["main_image_url"],               # 11
            p["category_name"]                 # 12
        )
        db_data.append(row)
        
    return build_rag_data(db_data)




















