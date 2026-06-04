import os
import sys
import json
import logging
from pathlib import Path

# Add project root to python path to resolve app.* imports
sys.path.append(str(Path(__file__).resolve().parents[1]))

from app.database import get_connection
from app.api_key import get_embedding
from app.main import build_rich_embedding_text
from app.retriever import clear_rag_cache

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

def populate_missing_embeddings():
    logging.info("Starting missing embeddings population script...")
    
    try:
        conn = get_connection()
    except Exception as e:
        logging.error(f"Failed to connect to database: {e}")
        return

    try:
        with conn:
            with conn.cursor() as cursor:
                # Query all active product items with missing embeddings
                cursor.execute("""
                    SELECT pi.product_item_id, pi.description, p.name, pi.specifications, c.name AS category_name
                    FROM product_items pi
                    JOIN products p ON pi.product_id = p.product_id
                    JOIN categories c ON p.category_id = c.category_id
                    WHERE pi.embedding IS NULL AND pi.status = 'active'
                """)
                rows = cursor.fetchall()
                
                total_to_update = len(rows)
                logging.info(f"Found {total_to_update} active product items with missing embeddings.")
                
                if total_to_update == 0:
                    logging.info("No missing embeddings to update.")
                    return

                success_count = 0
                for idx, row in enumerate(rows, 1):
                    product_item_id, description, name, specifications, category_name = row
                    logging.info(f"[{idx}/{total_to_update}] Processing product_item_id: {product_item_id} ({name})")
                    
                    try:
                        # 1. Build the rich text payload
                        rich_text = build_rich_embedding_text(name, category_name, specifications, description)
                        
                        # 2. Call embedding API
                        logging.info(f"Generating embedding for: {rich_text[:100]}...")
                        embedding_vector = get_embedding(rich_text)
                        
                        # 3. Format as postgres vector string
                        embedding_str = "[" + ",".join(map(str, embedding_vector)) + "]"
                        
                        # 4. Save to database
                        cursor.execute(
                            "UPDATE product_items SET embedding = %s::vector WHERE product_item_id = %s",
                            (embedding_str, product_item_id)
                        )
                        success_count += 1
                        logging.info(f"Successfully saved embedding for ID {product_item_id}.")
                    except Exception as ex:
                        logging.error(f"Failed to process product_item_id {product_item_id}: {ex}")

        # Invalidate cache so they are loaded on the next RAG query
        clear_rag_cache()
        logging.info(f"Finished. Successfully populated {success_count} / {total_to_update} embeddings. Cache cleared.")

    except Exception as e:
        logging.error(f"An error occurred during population: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    populate_missing_embeddings()
