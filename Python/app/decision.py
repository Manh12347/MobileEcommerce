import json
import traceback
from collections import deque

from app.api_key import decision_model

conversation_history = deque(maxlen=5)


def decide_chat(user_message: str, history: list) -> dict:
    """
    Decide whether to use RAG (retrieve data) or CHAT (casual conversation)
    based on the user's message.

    Args:
        user_message: The user's input message
        history: List of (user_message, bot_reply) tuples

    Returns:
        Dict with 'action' ('rag' or 'chat') and 'reason'
    """
    summary = "\n".join(
        [f"{i+1}. User: {u}\n   Bot: {b}" for i, (u, b) in enumerate(history)]
    ) or "No previous conversation."

    prompt = f"""
You are a decision-making assistant for a website chatbot.

Your goal: decide whether the chatbot should use **RAG** (retrieve data) or **CHAT** (casual conversation).

---

### Output format:
{{
  "action": "rag" | "chat",
  "reason": "short explanation in Vietnamese or English"
}}

---

### Decision rules:

Choose **"rag"** if:
- The user asks for information, products, or new data.
- The user applies filters (e.g., "dưới 500k", "màu đen", "size L").
- The user requests details or comparisons from external data.

Choose **"chat"** if:
- The user reacts, agrees, or continues a natural conversation.
- The user comments about shown items (e.g., "ừ, mẫu A đẹp đó").
- The user greets, thanks, or makes casual remarks.
- If unsure, default to "chat".

---

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
        print("Decision raw response:", response.text)
    except Exception as e:
        error_detail = f"{type(e).__name__}: {e}"
        print(f"Decision error: {error_detail}")
        traceback.print_exc()

        rag_keywords = [
            "sản phẩm", "product", "tìm", "find", "search",
            "lọc", "filter", "giá", "price", "mua", "buy", "để"
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
