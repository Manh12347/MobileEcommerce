import json
from collections import deque
from google.genai import types
from app.api_key import client_decision

# Lưu 5 lượt chat gần nhất (tuple: (user_message, bot_reply))
conversation_history = deque(maxlen=5)

def decide_chat(user_message, history):


    # Tạo tóm tắt hội thoại gần nhất
    summary = "\n".join(
        [f"{i+1}. User: {u}\n   Bot: {b}" for i, (u, b) in enumerate(history)]
    ) or "No previous conversation."

    # Prompt gọn hơn và rõ ràng hơn
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
- The user applies filters (e.g., “dưới 500k”, “màu đen”, “size L”).
- The user requests details or comparisons from external data.

Choose **"chat"** if:
- The user reacts, agrees, or continues a natural conversation.
- The user comments about shown items (e.g., “ừ, mẫu A đẹp đó”).
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
        # Gọi Gemini
        response = client_decision.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0,
                response_mime_type="application/json"
            )
        )
        print("Decision raw response:", response.text)
    except Exception as e:
        # Fallback: Gemini server error - use simple keyword detection
        print(f"⚠️ Decision error: {type(e).__name__} - Using fallback logic")
        rag_keywords = ["sản phẩm", "product", "tìm", "find", "search", "lọc", "filter", "giá", "price", "mua", "buy", "để"]
        is_rag = any(keyword.lower() in user_message.lower() for keyword in rag_keywords)
        return {"action": "rag" if is_rag else "chat", "reason": "Fallback: Gemini server unavailable"}

    # Parse JSON an toàn
    try:
        return json.loads(response.text)
    except Exception as e:
        print("⚠️ JSON parsing failed:", e)
        return {"action": "chat", "reason": "fallback: cannot parse JSON"}