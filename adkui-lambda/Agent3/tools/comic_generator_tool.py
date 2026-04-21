import os
import re
import logging
from google.adk.tools import ToolContext
import google.generativeai as genai
from .image_generation import generate_image
import json
from typing import List, Dict, Any
import boto3

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def create_comic_from_script(script: str, tool_context: ToolContext) -> str:
    """
    Takes a comic script, generates all assets, assembles the HTML, uploads to S3, and saves it.
    This tool orchestrates the panelization, image generation, and final HTML assembly.
    Args:
        script: The comic book script.
        tool_context: The ADK tool context.
    Returns:
        A confirmation message indicating success or failure.
    """
    output_dir = "/tmp/output"
    s3_bucket_name = os.environ.get("S3_BUCKET_NAME", "my-adk-comic-artifacts")
    try:
        os.makedirs(output_dir, exist_ok=True)
        logger.info(f"Created output directory: {output_dir}")

        # 1. Panelization: Call LLM to break script into panels
        logger.info("Starting panelization...")
        api_key = os.environ.get("GEMINI_API_KEY")
        genai.configure(api_key=api_key)
        
        panelization_prompt = f"""
            You are a comic book panelization expert. Your task is to take the following script
            and break it down into a JSON array of 8 distinct panels. Each panel should be a
            JSON object containing 'panel_number', 'description' (a detailed visual prompt
            for an image generation model), and 'dialogue' (a dictionary of character to line).
            
            SCRIPT:
            {script}
            
            JSON_OUTPUT:
        """
        model = genai.GenerativeModel('gemini-2.5-flash')
        response = model.generate_content(panelization_prompt)
        
        # Extract JSON from markdown code block
        match = re.search(r"```json\n(.*)\n```", response.text, re.DOTALL)
        if match:
            json_text = match.group(1)
        else:
            json_text = response.text

        panels = json.loads(json_text)
        logger.info("Successfully panelized script into 8 panels.")

        # 2. Image Generation: Generate image for each panel
        gallery: List[Dict[str, Any]] = []
        for panel in panels:
            panel_num = panel.get("panel_number", "unknown")
            logger.info(f"Generating image for panel {panel_num}...")
            image_gen_result = await generate_image(
                prompt=panel.get("description", ""),
                image_name=f"panel_{panel_num}",
                tool_context=tool_context
            )
            if image_gen_result.get("status") == "success":
                panel["artifact_name"] = image_gen_result.get("artifact_name")
                gallery.append(panel)
                logger.info(f"Successfully generated image for panel {panel_num}.")
            else:
                error_message = image_gen_result.get("message", "Unknown error")
                logger.error(f"Failed to generate image for panel {panel_num}: {error_message}")
                panel["artifact_name"] = "error"
                gallery.append(panel)

        # 3. HTML Assembly & S3 Upload
        logger.info("Assembling HTML content and uploading to S3...")
        s3_client = boto3.client("s3")

        html_panels = []
        for panel in gallery:
            artifact_name = panel.get("artifact_name", "")
            if artifact_name == "error":
                image_url = "" # Or a placeholder image URL
            else:
                # Upload image to S3
                local_image_path = f"/tmp/images/{artifact_name}"
                s3_image_key = f"images/{artifact_name}"
                s3_client.upload_file(local_image_path, s3_bucket_name, s3_image_key)
                # Generate a presigned URL for the image
                image_url = s3_client.generate_presigned_url('get_object',
                                                              Params={'Bucket': s3_bucket_name,
                                                                      'Key': s3_image_key},
                                                              ExpiresIn=3600)

            dialogue_html = ""
            if panel.get("dialogue"):
                for speaker, line in panel["dialogue"].items():
                    dialogue_html += f"<p><strong>{speaker}:</strong> {line}</p>"

            html_panels.append(
                f'''<div class="comic-panel">
                    <img src="{image_url}" alt="Panel {panel.get('panel_number', '')}">
                    <div class="comic-dialogue">{dialogue_html}</div>
                </div>'''
            )

        html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ADK Comic</title>
    <style>
        body {{ font-family: sans-serif; background-color: #f0f0f0; padding: 20px; }}
        .comic-container {{ display: flex; flex-direction: column; gap: 1em; max-width: 800px; margin: auto; background: white; border: 1px solid #ccc; padding: 20px; }}
        .comic-panel {{ border: 1px solid black; padding: 1em; }}
        .comic-panel img {{ max-width: 100%; height: auto; }}
    </style>
</head>
<body>
    <h1>Your Comic</h1>
    <div class="comic-container">
        {''.join(html_panels)}
    </div>
</body>
</html>"""
        logger.info("Generated final HTML content.")

        # 4. Final Output
        html_file_path = os.path.join(output_dir, "comic.html")
        with open(html_file_path, "w") as f:
            f.write(html_content)
        logger.info(f"Successfully wrote comic HTML to {html_file_path}")

        # Upload HTML to S3
        s3_html_key = "comic.html"
        s3_client.upload_file(html_file_path, s3_bucket_name, s3_html_key)
        
        # Generate a presigned URL for the HTML file
        s3_html_url = s3_client.generate_presigned_url('get_object',
                                                      Params={'Bucket': s3_bucket_name,
                                                              'Key': s3_html_key},
                                                      ExpiresIn=3600)

        return f"Successfully created comic. You can view it at: {s3_html_url}"

    except Exception as e:
        logger.exception("An error occurred in the comic creation tool.")
        return f"An error occurred: {e}"
