from app.api_key import client_chat
from google.genai import types

def chat_with_gemini(user_message):
    # Tạo system context mô tả vai trò chatbot
    system_context = """
                    Bạn là một trợ lý chatbot thân thiện và hữu ích trên một trang web mua sắm.
                    - Trả lời trong phạm vi buôn bán của trang web.
                    - Luôn trả lời ngắn gọn, tự nhiên và mang tính trò chuyện.
                    - Sử dụng ngôn ngữ đơn giản và rõ ràng.
                    - Trả lời ngắn gọn (1–2 câu).
                    - Sử dụng giọng điệu lịch sự, thân thiện.
                    """

    # Kết hợp context + tin nhắn người dùng
    full_prompt = f"{system_context}\nUser: {user_message}\nChatbot:"

    try:
        # Gọi Gemini để sinh phản hồi
        response = client_chat.models.generate_content(
            model="gemini-2.5-flash",
            contents=full_prompt,
            config=types.GenerateContentConfig(
                temperature=0.7,
            )
        )
        return response.text
    except Exception as e:
        # Fallback response khi Gemini server bị tải hoặc lỗi khác
        print(f"⚠️ Chat error: {type(e).__name__}")
        return f"Xin lỗi, tôi đang không thể trả lời lúc này. Vui lòng thử lại sau."
