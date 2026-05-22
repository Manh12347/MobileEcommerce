import os
from pathlib import Path

import vertexai
from vertexai.generative_models import GenerativeModel
from vertexai.language_models import TextEmbeddingModel

repo_root = Path(__file__).resolve().parents[2]

# Set Google Application Credentials for Vertex AI
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = str(
    repo_root / "credentials" / "mobileemcommerce-bebb5a6c01b8.json"
)

# Vertex AI Configuration
PROJECT_ID = "mobileemcommerce"
LOCATION = "us-central1"

vertexai.init(project=PROJECT_ID, location=LOCATION)

chat_model = GenerativeModel("gemini-2.5-flash")
decision_model = GenerativeModel("gemini-2.5-flash")
embedding_model = TextEmbeddingModel.from_pretrained("text-embedding-004")


def get_embedding(text: str):
    """
    Generate embedding for a single text using Vertex AI TextEmbeddingModel.

    Args:
        text: Input text to embed

    Returns:
        List of float values representing the embedding vector
    """
    embeddings = embedding_model.get_embeddings([text])
    return embeddings[0].values


def get_embeddings_batch(texts: list[str]):
    """
    Generate embeddings for multiple texts using Vertex AI TextEmbeddingModel.

    Args:
        texts: List of input texts to embed

    Returns:
        List of embedding vectors (each is a list of floats)
    """
    embeddings = embedding_model.get_embeddings(texts)
    return [e.values for e in embeddings]
