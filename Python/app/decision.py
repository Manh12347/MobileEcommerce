import json
import traceback
from collections import deque

from app.api_key import decision_model

conversation_history = deque(maxlen=5)


def decide_chat(user_message: str, history: list, active_screen: str | None = None) -> dict:
    """
    Decide whether to use RAG (retrieve data), CHAT (casual conversation), or PC_BUILD
    based on the user's message and the active screen.

    Args:
        user_message: The user's input message
        history: List of (user_message, bot_reply) tuples
        active_screen: The current screen name ('Checkout', 'ProductDetail', 'PCBuild', etc.)

    Returns:
        Dict with 'action' ('rag', 'chat', or 'pc_build') and 'reason'
    """
    summary = "\n".join(
        [f"{i+1}. User: {u}\n   Bot: {b}" for i, (u, b) in enumerate(history)]
    ) or "No previous conversation."

    prompt = f"""
You are a decision-making assistant for a website chatbot.

Your goal: decide whether the chatbot should use **RAG** (retrieve data), **CHAT** (casual conversation), or **PC_BUILD** (recommend a compatible set of PC components/build specification).

---

### Output format:
{{
  "action": "rag" | "chat" | "pc_build",
  "reason": "short explanation in Vietnamese or English"
}}

---

### Decision rules:

Choose **"pc_build"** if:
- The user is asking for a custom PC recommendation or build advice under a budget or for specific uses (e.g. "build pc", "tư vấn cấu hình máy tính", "pc chơi game", "pc 20tr", "dựng cấu hình").
- The message implies recommending a set of compatible components (CPU, GPU, RAM, Motherboard, etc.) rather than a single prebuilt system or individual product list.
- The user is on the "ProductDetail" or "PCBuild" screen and types a budget limit (e.g., "20 tr", "20 triệu", "15tr").

Choose **"rag"** if:
- The user asks for general information, individual products, or new data (but not a full PC build specification).
- The user applies filters for a specific search (e.g., "dưới 500k", "màu đen", "size L").
- The user requests details or comparisons between individual products.
- The user is asking to compare the active product they are viewing with cheaper alternatives (e.g. "Có sản phẩm nào cùng thông số hay tốt hơn nhưng giá rẻ hơn không").

Choose **"chat"** if:
- The user is on the "Checkout" screen and asking about payment methods, QR payment, transfer verification, etc. (e.g., "Thanh toán QR là ntn").
- The user reacts, agrees, or continues a natural conversation.
- The user comments about shown items (e.g., "ừ, mẫu A đẹp đó").
- The user greets, thanks, or makes casual remarks.
- If unsure, default to "chat".

---

### Active Screen Context:
Active Screen: {active_screen or 'Unknown'}

### Conversation Summary:
{summary}

### User Message:
{user_message}

Return only a valid JSON object as specified above.
"""

    try:
        response = decision_model.generate_content(
            prompt,
            generation_config={
                "temperature": 0,
                "response_mime_type": "application/json"
            }
        )
    except Exception as e:
        error_detail = f"{type(e).__name__}: {e}"
        print(f"Decision error: {error_detail}")
        traceback.print_exc()

        pc_build_keywords = ["build pc", "cấu hình", "dựng pc", "lắp pc", "spec pc", "chơi game", "gta 5", "gta5"]
        is_build = any(kw.lower() in user_message.lower() for kw in pc_build_keywords)
        if not is_build and active_screen in ("ProductDetail", "PCBuild"):
            import re
            if re.search(r'\d+\s*(tr|triệu|million|m)', user_message.lower()):
                is_build = True

        if is_build:
            return {
                "action": "pc_build",
                "reason": f"Fallback: PC build requested - {error_detail}"
            }

        rag_keywords = [
            "sản phẩm", "product", "tìm", "find", "search",
            "lọc", "filter", "giá", "price", "mua", "buy", "để",
            "rẻ hơn", "tốt hơn", "cùng thông số"
        ]
        is_rag = any(keyword.lower() in user_message.lower() for keyword in rag_keywords)
        return {
            "action": "rag" if is_rag else "chat",
            "reason": f"Fallback: Vertex AI error - {error_detail}"
        }

    try:
        return json.loads(response.text)
    except Exception as e:
        error_detail = f"{type(e).__name__}: {e}"
        print("JSON parsing failed:", error_detail)
        traceback.print_exc()
        return {"action": "chat", "reason": f"fallback: cannot parse JSON - {error_detail}"}
