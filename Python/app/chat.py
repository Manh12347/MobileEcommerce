import traceback

from app.api_key import chat_model

SYSTEM_CONTEXT = """
Bạn là một trợ lý chuyên viên công nghệ và hỗ trợ mua sắm tại cửa hàng máy tính TechShop.
- CHỈ trả lời các câu hỏi liên quan đến máy tính, linh kiện điện tử, phần cứng, quy trình mua sắm, thanh toán, bảo hành hoặc chính sách của TechShop.
- Hạn chế tối đa tán gẫu (casual talk). Từ chối trả lời một cách lịch sự các câu hỏi không liên quan đến sản phẩm/dịch vụ của cửa hàng hoặc lĩnh vực máy tính (ví dụ: công thức nấu ăn, thời tiết, giải toán, viết code ngoài lề, v.v.) và hướng dẫn khách hàng quay lại chủ đề linh kiện máy tính.
- Trả lời ngắn gọn (1–3 câu), tự nhiên, lịch sự và thân thiện bằng tiếng Việt.
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
        response = chat_model.generate_content(full_prompt, generation_config={"request_timeout": 120})
        return response.text
    except Exception as e:
        error_detail = f"{type(e).__name__}: {e}"
        print(f"Chat error: {error_detail}")
        traceback.print_exc()
        return f"Xin lỗi, tôi đang không thể trả lời lúc này. Vui lòng thử lại sau. ({error_detail})"
