import os
import logging
from google.adk.tools import ToolContext
from google.genai import types

logger = logging.getLogger(__name__)

def list_generated_comics() -> str:
    """
    Lists the files in the 'output' directory to see what's been generated.
    Returns:
        A string listing all files in the output folder.
    """
    output_dir = "output"
    if not os.path.exists(output_dir):
        return "The 'output' directory does not exist yet. Run Agent3 first."
    
    files = os.listdir(output_dir)
    if not files:
        return "The 'output' directory is empty."
    
    # Also list images if they exist
    images_dir = os.path.join(output_dir, "images")
    image_list = ""
    if os.path.exists(images_dir):
        images = [f for f in os.listdir(images_dir) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
        if images:
            image_list = "\n\nImages in 'output/images/':\n- " + "\n- ".join(images)
    
    return "Files in the 'output' directory:\n- " + "\n- ".join(files) + image_list

def read_comic_html() -> str:
    """
    Reads the content of 'output/comic.html' and returns it.
    Returns:
        The text content of the comic HTML file, or an error if not found.
    """
    html_path = os.path.join("output", "comic.html")
    if not os.path.exists(html_path):
        return "Error: 'output/comic.html' was not found."
    
    try:
        with open(html_path, "r") as f:
            content = f.read()
        return content
    except Exception as e:
        return f"Error reading file: {e}"

async def display_comic_images(tool_context: ToolContext) -> str:
    """
    Reads all images from 'output/images/' and saves them as artifacts 
    so they can be viewed directly in the ADK UI.
    
    Args:
        tool_context: The ADK tool context for saving artifacts.
    """
    images_dir = os.path.join("output", "images")
    if not os.path.exists(images_dir):
        return "Error: 'output/images/' directory not found."
    
    images = sorted([f for f in os.listdir(images_dir) if f.lower().endswith(('.png', '.jpg', '.jpeg'))])
    if not images:
        return "No images found in 'output/images/'."
    
    count = 0
    for image_name in images:
        image_path = os.path.join(images_dir, image_name)
        try:
            with open(image_path, "rb") as f:
                image_bytes = f.read()
            
            image_part = types.Part.from_bytes(
                data=image_bytes, 
                mime_type="image/png" if image_name.endswith(".png") else "image/jpeg"
            )
            await tool_context.save_artifact(image_name, image_part)
            count += 1
        except Exception as e:
            logger.error(f"Failed to save artifact {image_name}: {e}")
            
    return f"Successfully displayed {count} images as artifacts in the ADK UI."
