from google import genai
from openai import OpenAI
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Google GenAI Clients
client_embed = genai.Client(api_key=os.getenv("GENAI_API_EMBED"))
client_decision = genai.Client(api_key=os.getenv("GENAI_API_DECISION"))
client_chat = genai.Client(api_key=os.getenv("GENAI_API_CHAT"))

# OpenAI Client (optional - initialize if API key exists)
openai_api_key = os.getenv("OPENAI_API_KEY")
openai_client = OpenAI(api_key=openai_api_key) if openai_api_key else None