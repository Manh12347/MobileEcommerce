import os
import json
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

import time
from app.api_key import chat_model
from app.chat import chat_with_gemini
from app.database import load_all_active_products
from app.retriever import get_rag_data, generate_product_embedding, retrieve_products, clear_rag_cache
from app.decision import decide_chat

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
    "http://localhost:8000",
    "http://localhost:55863",
    "http://127.0.0.1:55863",
]

app.add_middleware(
    CORSMiddleware,
    # Allow the production origin plus any localhost origin with any port.
    allow_origins=["https://rag.doantrang.online"],
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
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


def get_product_by_id(product_item_id: int):
    try:
        with get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT
                        pi.product_item_id,
                        pi.description,
                        pi.price,
                        pi.sale_price,
                        pi.stock_quantity,
                        p.name,
                        pi.specifications,
                        c.name AS category_name,
                        pi.sku,
                        pi.main_image_url
                    FROM product_items pi
                    JOIN products p ON pi.product_id = p.product_id
                    JOIN categories c ON p.category_id = c.category_id
                    WHERE pi.product_item_id = %s
                """, (product_item_id,))
                row = cursor.fetchone()
                if row:
                    specs = row[6]
                    if isinstance(specs, str):
                        try:
                            specs = json.loads(specs)
                        except:
                            specs = {}
                    elif specs is None:
                        specs = {}
                    return {
                        "product_item_id": row[0],
                        "description": row[1] or "",
                        "price": float(row[2]) if row[2] is not None else 0.0,
                        "sale_price": float(row[3]) if row[3] is not None else None,
                        "stock": row[4] or 0,
                        "product_name": row[5],
                        "specifications": specs,
                        "category_name": row[7],
                        "sku": row[8],
                        "main_image_url": row[9]
                    }
    except Exception as e:
        print(f"Error getting product by id {product_item_id}: {e}")
    return None


# ============================
# Session Storage
# ============================

# Format: {session_id: {"last_activity": float, "history": list}}
session_histories = {}


# ============================
# Request Models
# ============================

class Message(BaseModel):
    text: str
    session_id: str | None = None
    active_screen: str | None = None
    active_product_id: int | None = None
    active_product_details: str | None = None


class UpdateEmbeddingRequest(BaseModel):
    product_item_id: int


# ============================
# PC Builder Constants & Helpers
# ============================

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


def get_all_components_inventory():
    try:
        raw_products = load_all_active_products()
        inventory = []
        for p in raw_products:
            # p: (product_item_id, description, price, sale_price, stock_quantity, name, specifications, warranty_months, sku, main_image_url, category_name)
            specs = p[6]
            if isinstance(specs, str):
                try:
                    specs = json.loads(specs)
                except:
                    specs = {}
            elif specs is None:
                specs = {}
            
            price = float(p[2]) if p[2] is not None else 0.0
            sale_price = float(p[3]) if p[3] is not None else None
            
            prod = {
                "product_item_id": p[0],
                "product_name": p[5],
                "price": price,
                "sale_price": sale_price,
                "stock": p[4] if p[4] is not None else 0,
                "warranty_months": p[7] if p[7] is not None else 0,
                "sku": p[8] or "",
                "description": p[1] or "",
                "main_image_url": p[9] or "",
                "category_name": p[10] or "",
                "specifications": specs
            }
            inventory.append(prod)
            
        inventory.extend(VIRTUAL_PRODUCTS)
        return inventory
    except Exception as e:
        print("Error getting components inventory:", e)
        return VIRTUAL_PRODUCTS


# ============================
# Chat API
# ============================

@app.post("/chat")
def chat_api(msg: Message):
    session_id = msg.session_id or str(uuid4())
    current_time = time.time()

    # Clean up expired sessions (> 1 hour) to avoid memory leak
    expired_ids = [
        sid for sid, data in session_histories.items()
        if current_time - data["last_activity"] > 3600
    ]
    for sid in expired_ids:
        try:
            del session_histories[sid]
        except KeyError:
            pass

    if session_id in session_histories:
        session_data = session_histories[session_id]
        if current_time - session_data["last_activity"] > 3600:
            session_data["history"] = []
        session_data["last_activity"] = current_time
    else:
        session_histories[session_id] = {
            "last_activity": current_time,
            "history": []
        }

    conversation_history = session_histories[session_id]["history"]

    decision = decide_chat(msg.text, conversation_history, msg.active_screen)

    top_products = None
    answer = None

    active_product = None
    if msg.active_product_id:
        active_product = get_product_by_id(msg.active_product_id)

    # 1. Checkout Screen - automatic QR payment verification query
    if msg.active_screen == "Checkout" and any(kw in msg.text.lower() for kw in ["qr", "thanh toán", "chuyển khoản", "ntn"]):
        prompt = (
            f"Bối cảnh: Người dùng đang ở màn hình Thanh toán (Checkout).\n"
            f"Thông tin quan trọng về Thanh toán QR: Cửa hàng sử dụng hệ thống chuyển khoản QR tự động. "
            f"Sau khi khách hàng chuyển khoản thành công, hệ thống sẽ tự động đối soát và xác thực giao dịch trong 1-3 phút. "
            f"Nếu gặp sự cố hoặc quá thời gian trên, khách hàng cần liên hệ hotline/bộ phận hỗ trợ để xử lý nhanh.\n"
            f"Câu hỏi của khách hàng: {msg.text}\n"
            f"Hãy trả lời khách hàng một cách thân thiện, rõ ràng bằng tiếng Việt dựa trên thông tin trên."
        )
        answer = chat_with_gemini(prompt)

    # 2. Product Detail Screen - Cheaper/Better Alternative Comparison
    elif msg.active_screen == "ProductDetail" and active_product and any(kw in msg.text.lower() for kw in ["rẻ hơn", "tốt hơn", "cùng thông số"]):
        category = active_product["category_name"]
        inventory = get_all_components_inventory()
        same_category_products = [
            p for p in inventory
            if p["category_name"].lower() == category.lower()
            and p["product_item_id"] != active_product["product_item_id"]
        ]

        alternatives_desc = []
        for p in same_category_products:
            price_str = f"Price: {p['price']}"
            if p['sale_price']:
                price_str += f" (Sale: {p['sale_price']})"
            spec_str = str(p['specifications'])
            alternatives_desc.append(
                f"- ID: {p['product_item_id']} | {p['product_name']} | {price_str} | Specs: {spec_str}"
            )
        alternatives_text = "\n".join(alternatives_desc) if alternatives_desc else "No other products in this category."

        active_price = active_product['sale_price'] if active_product['sale_price'] else active_product['price']
        compare_prompt = f"""
You are an expert tech consultant.
The user is viewing the active product:
Name: {active_product['product_name']}
Price: {active_price} (Original: {active_product['price']}, Sale: {active_product['sale_price']})
Category: {category}
Specs: {active_product['specifications']}
Description: {active_product['description']}

They asked: "{msg.text}"

Analyze these other products in the same category:
{alternatives_text}

Find and suggest 1-3 products that have similar or better specifications but are CHEAPER (using sale_price if available, otherwise price) than the active product.
If none exist, explain that the current product they are viewing is already the best value.

Your response MUST be in this JSON format:
{{
  "answer": "A friendly and clear explanation in Vietnamese highlighting the specs, prices, and why they are cheaper/better.",
  "suggested_ids": [id1, id2, ...]
}}
"""
        try:
            response = chat_model.generate_content(
                compare_prompt,
                generation_config={
                    "temperature": 0.2,
                    "response_mime_type": "application/json"
                }
            )
            compare_result = json.loads(response.text)
            answer = compare_result["answer"]
            suggested_ids = compare_result["suggested_ids"]
        except Exception as e:
            print("Gemini comparison error:", e)
            answer = "Tôi đã tìm kiếm nhưng hiện tại chưa thấy sản phẩm nào cùng phân khúc giá rẻ hơn có sẵn hàng."
            suggested_ids = []

        top_products = []
        for item_id in suggested_ids:
            found = next((p for p in same_category_products if p["product_item_id"] == item_id), None)
            if found:
                top_products.append({
                    "product_item_id": found["product_item_id"],
                    "product_name": found["product_name"],
                    "price": found["price"],
                    "sale_price": found["sale_price"],
                    "stock": found["stock"],
                    "warranty_months": found["warranty_months"],
                    "similarity": 1.0,
                    "sku": found["sku"],
                    "description": found["description"],
                    "main_image_url": found["main_image_url"],
                    "category_name": found["category_name"]
                })
        decision["action"] = "rag"

    # 3. Product Detail Screen - B760 DDR5 Compatibility Query
    elif msg.active_screen == "ProductDetail" and active_product and any(kw in msg.text.lower() for kw in ["b760", "ddr5"]):
        prompt = f"""
You are an expert PC hardware compatibility specialist.
The user is viewing the active product:
Name: {active_product['product_name']}
Category: {active_product['category_name']}
Specs: {active_product['specifications']}
Description: {active_product['description']}

They asked: "{msg.text}"

Please answer if this active product is compatible with a 'B760 DDR5' motherboard.
Context to keep in mind:
- Motherboard: B760 DDR5 (socket LGA1700, supports Intel Core 12th, 13th, 14th Gen CPUs).
- RAM compatibility: ONLY supports DDR5 RAM (DDR4 RAM will NOT fit).
- GPU compatibility: PCIe x16 slot, fully compatible with all modern PCIe graphics cards (NVIDIA RTX, AMD Radeon).
- Storage compatibility: Supports M.2 NVMe PCIe (Gen 4/Gen 3) and standard SATA III SSDs/HDDs.
- PSU compatibility: ATX standard, compatible with ATX cases. PSU wattage must be matched with CPU+GPU power draw, but the PSU itself physically connects.
- Case compatibility: Usually ATX or Micro-ATX cases, B760 motherboards are typically Micro-ATX or ATX.

Evaluate compatibility of the active product based on its category and specific specifications. Explain clearly and accurately in Vietnamese.
"""
        answer = chat_with_gemini(prompt)

    # 4. PC Build Recommendation flow
    elif decision["action"] == "pc_build":
        inventory = get_all_components_inventory()

        # Build inventory description text for the LLM
        inventory_items_desc = []
        for p in inventory:
            price_str = f"Price: {p['price']}"
            if p['sale_price']:
                price_str += f" (Sale: {p['sale_price']})"
            spec_str = str(p['specifications'])
            inventory_items_desc.append(
                f"- ID: {p['product_item_id']} | {p['product_name']} | {price_str} | Category: {p['category_name']} | Specs: {spec_str}"
            )
        inventory_text = "\n".join(inventory_items_desc)

        # In PC build recommendation flow, check if there is an active product we should force/incorporate
        active_product_instruction = ""
        if msg.active_screen == "ProductDetail" and active_product:
            active_product_instruction = f"""
---
### CRITICAL REQUIREMENT:
The user is currently viewing the following active product:
- ID: {active_product['product_item_id']} | {active_product['product_name']} | Price: {active_product['sale_price'] or active_product['price']} | Category: {active_product['category_name']}
If the active product category belongs to any of the standard build components (CPU, Mainboard, RAM, GPU, PSU, SSD/HDD, Case), you MUST include this EXACT product item in the recommended PC build, unless its price alone exceeds the budget or it is technically impossible to build a compatible PC around it. If it doesn't fit the budget or is incompatible, explain why in your answer.
"""

        build_prompt = f"""
You are an expert PC Builder chatbot on TechShop.
The user requested a PC build with the following query:
"{msg.text}"

Select a set of fully compatible components from the available inventory below that fits their budget and needs.
{active_product_instruction}

---
### RULES & SITUATIONS:
1. A valid build MUST include exactly ONE of each required category:
   - CPU
   - Mainboard (must support CPU socket and RAM memory_type)
   - RAM (must match Mainboard ram type, e.g., DDR4 vs DDR5)
   - PSU (Power supply)
   - SSD/HDD (Storage)
   - Case
2. GPU/VGA is optional but highly recommended if the query is about gaming (like GTA 5, Valorant, PUBG, etc.) or rendering.
3. Cooler (Tản nhiệt) is optional but recommended if the CPU runs hot.
4. Total price of the components (using `sale_price` if available, otherwise `price`) MUST NOT exceed the user's budget.
5. All components must be selected from the available inventory. Do not invent products.
6. Check compatibility:
   - CPU socket (e.g. LGA1700) must match Motherboard socket.
   - RAM type (DDR4 vs DDR5) must match Motherboard memory_type.
   - PSU wattage must be sufficient for CPU and GPU estimated power.

7. SITUATION - Low Budget Fallback:
   - If the user's budget is too low (e.g., under 10-12 million VND) to fit a discrete GPU, DO NOT select a discrete GPU/VGA. Instead, select a CPU with integrated graphics, and explain in your answer that they can run on integrated graphics now and easily plug in a dedicated GPU later when they have more budget.

8. SITUATION - Upgrade / Migration:
   - If the user lists some existing parts they already own and want to keep/upgrade (e.g., "Tôi đang có main H610, build tiếp trong 10tr"), you must select ONLY the other components to complete the build. Do not charge or include the price of the components they already own in your budget calculations (you can mark them in your text description as owned). Reinvest the remaining budget into better upgrades for the other components.

9. SITUATION - Use-Case Profiling:
   - Tailor the build to their specific use-case (Gaming, Office, Editing, AI). In your text explanation, explicitly highlight the strong points of the build and target performance tier using phrases like: "Bộ PC của bạn đang rất tốt cho việc...", "Chơi game AAA ở thiết lập FHD...", "Cấu hình chuyên đồ họa...", etc.

10. SITUATION - Stock & Equivalent Swap:
    - If a product is out of stock (stock is 0), do not include it. Select an alternative in-stock product of equivalent specs and pricing. If a user asks to swap/change a component to a cheaper/premium alternative, select the appropriate alternative from the inventory.

11. SITUATION - Assembly & Custom Services:
    - Explain that TechShop offers free assembly & installation services for builds over 15 million VND, or a 200,000 VND standard fee for builds under 15 million VND.

---
### AVAILABLE INVENTORY (ID, Name, Price, Category, Specs):
{inventory_text}

---
### OUTPUT FORMAT:
You MUST respond with a valid JSON object in this format:
{{
  "answer": "A short, engaging explanation in Vietnamese (1-3 sentences) detailing the build, total price, and its suitability.",
  "build_item_ids": [id1, id2, id3, ...]
}}
"""
        try:
            response = chat_model.generate_content(
                build_prompt,
                generation_config={
                    "temperature": 0.2,
                    "response_mime_type": "application/json"
                }
            )
            build_result = json.loads(response.text)
            answer = build_result["answer"]
            build_item_ids = build_result["build_item_ids"]
        except Exception as e:
            print("Gemini PC Builder error:", e)
            answer = "Rất tiếc, tôi gặp sự cố khi thiết lập cấu hình. Bạn có thể tự chọn linh kiện trong mục 'Xây dựng cấu hình' nhé!"
            build_item_ids = []

        top_products = []
        for item_id in build_item_ids:
            found = next((p for p in inventory if p["product_item_id"] == item_id), None)
            if found:
                top_products.append({
                    "product_item_id": found["product_item_id"],
                    "product_name": found["product_name"],
                    "price": found["price"],
                    "sale_price": found["sale_price"],
                    "stock": found["stock"],
                    "warranty_months": found["warranty_months"],
                    "similarity": 1.0,
                    "sku": found["sku"],
                    "description": found["description"],
                    "main_image_url": found["main_image_url"],
                    "category_name": found["category_name"]
                })

    elif decision["action"] == "rag":
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

    else:
        answer = chat_with_gemini(msg.text)

    conversation_history.append((msg.text, answer))
    if session_id in session_histories:
        session_histories[session_id]["history"] = conversation_history
        session_histories[session_id]["last_activity"] = time.time()

    return {
        "session_id": session_id,
        "answer": answer,
        "conversation_history": conversation_history,
        "decision": decision,
        "retrieved_products": top_products if decision["action"] in ("rag", "pc_build") else None
    }


# ============================
# Update Embedding API
# ============================

def build_rich_embedding_text(name: str | None, category: str | None, specifications: str | dict | None, description: str | None) -> str:
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


@app.post("/update-vector-by-product-id")
def update_vector(req: UpdateEmbeddingRequest):
    product_item_id = req.product_item_id
    logging.info(f"Update embedding request for product_item_id: {product_item_id}")

    try:
        with get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT pi.description, p.name, pi.specifications, c.name AS category_name
                    FROM product_items pi
                    JOIN products p ON pi.product_id = p.product_id
                    JOIN categories c ON p.category_id = c.category_id
                    WHERE pi.product_item_id = %s
                """, (product_item_id,))
                row = cursor.fetchone()

                if not row:
                    raise HTTPException(status_code=404, detail="Product Item not found")

                description, name, specifications, category_name = row
                logging.info(f"Found product: {name}, category: {category_name}")

        rich_text = build_rich_embedding_text(name, category_name, specifications, description)
        logging.info(f"Rich embedding text: {rich_text}")

        logging.info("Calling generate_product_embedding...")
        embedding_vector = generate_product_embedding(rich_text)
        logging.info(f"Embedding generated, length: {len(embedding_vector)}")

        embedding_str = "[" + ",".join(map(str, embedding_vector)) + "]"

        with get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "UPDATE product_items SET embedding = %s::vector WHERE product_item_id = %s",
                    (embedding_str, product_item_id)
                )
                conn.commit()

        # Invalidate RAG cache so updates take effect immediately
        clear_rag_cache()
        logging.info("Embedding updated and cache cleared successfully")

        return {
            "status": "success",
            "product_item_id": product_item_id,
            "embedding_length": len(embedding_vector)
        }
    except Exception as e:
        logging.error(f"Error updating embedding: {e}")
        logging.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))
