import traceback

from app.api_key import chat_model

SYSTEM_CONTEXT = """
Bạn là một trợ lý chatbot thân thiện và hữu ích trên một trang web mua sắm.
- Trả lời trong phạm vi buôn bán của trang web.
- Luôn trả lời ngắn gọn, tự nhiên và mang tính trò chuyện.
- Sử dụng ngôn ngữ đơn giản và rõ ràng.
- Trả lời ngắn gọn (1–2 câu).
- Sử dụng giọng điệu lịch sự, thân thiện.
"""


def chat_with_gemini(user_message: str) -> str:
    """
    Generate a chat response using Vertex AI Gemini.

    Args:
        user_message: The user's input message

    Returns:
        The chatbot's response text
    """
    full_prompt = f"{SYSTEM_CONTEXT}\nUser: {user_message}\nChatbot:"

    try:
        response = chat_model.generate_content(full_prompt)
        return response.text
    except Exception as e:
        error_detail = f"{type(e).__name__}: {e}"
        print(f"Chat error: {error_detail}")
        traceback.print_exc()
        return f"Xin lỗi, tôi đang không thể trả lời lúc này. Vui lòng thử lại sau. ({error_detail})"
