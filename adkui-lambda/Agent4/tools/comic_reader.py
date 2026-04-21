import os
import logging
import base64
import re
from google.adk.tools import ToolContext
from google.genai import types
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)

S3_BUCKET_NAME = os.environ.get("S3_BUCKET_NAME", "my-adk-comic-artifacts")

def _get_s3_client():
    try:
        return boto3.client("s3")
    except ClientError as e:
        logger.error(f"Failed to create S3 client: {e}")
        return None

def _read_s3_object(s3_client, bucket, key):
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        return response['Body'].read()
    except ClientError as e:
        logger.error(f"Failed to read S3 object {key} from bucket {bucket}: {e}")
        return None

def _list_s3_objects(s3_client, bucket, prefix=""):
    try:
        objects = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix)
        return [obj['Key'] for obj in objects.get('Contents', [])]
    except ClientError as e:
        logger.error(f"Failed to list S3 objects in bucket {bucket} with prefix {prefix}: {e}")
        return []



def list_generated_comics() -> str:
    """
    Lists the files in the configured S3 bucket to see what's been generated.
    Returns:
        A string listing all relevant files in the S3 bucket.
    """
    s3_client = _get_s3_client()
    if not s3_client:
        return "Failed to initialize S3 client. Please check AWS credentials."

    try:
        # Agent3 uploads comic.html and images directly to the bucket root
        all_objects = _list_s3_objects(s3_client, S3_BUCKET_NAME)
        
        html_files = [f for f in all_objects if f.lower().endswith(".html")]
        image_files = [f for f in all_objects if f.lower().endswith((".png", ".jpg", ".jpeg"))]

        output_list = []
        if html_files:
            output_list.append("HTML files in S3 bucket:\n- " + "\n- ".join(html_files))
        if image_files:
            output_list.append("Images in S3 bucket:\n- " + "\n- ".join(image_files))

        if not output_list:
            return f"The S3 bucket '{S3_BUCKET_NAME}' is empty or contains no relevant comic files."
        
        return "\n\n".join(output_list)

    except Exception as e:
        logger.error(f"Error listing S3 objects: {e}")
        return f"An error occurred while listing comics from S3: {e}"


def get_comic_summary() -> str:
    """
    Reads the comic HTML from S3 and extracts a plain text summary of the story and panels.
    Returns:
        A string summary of the comic.
    """
    s3_client = _get_s3_client()
    if not s3_client:
        return "Failed to initialize S3 client. Please check AWS credentials."

    html_key = "comic.html"
    html_content_bytes = _read_s3_object(s3_client, S3_BUCKET_NAME, html_key)
    
    if html_content_bytes is None:
        return f"Error: '{html_key}' was not found in S3 bucket '{S3_BUCKET_NAME}'."

    try:
        content = html_content_bytes.decode('utf-8')

        # Simple extraction of text - stripping tags
        # This is a bit naive but should give a sense of the story
        text_content = re.sub("<[^<]+?>", "\n", content)
        # Clean up whitespace
        lines = [line.strip() for line in text_content.split("\n") if line.strip()]
        summary = "\n".join(lines[:50])  # Limit to first 50 lines

        return f"Summary of '{html_key}' from S3:\n\n{summary}"
    except Exception as e:
        return f"Error reading or processing comic.html from S3: {e}"


async def export_comic_to_artifacts(tool_context: ToolContext) -> str:
    """
    Creates a self-contained version of the comic and saves all assets
    as ADK artifacts for immediate viewing in the UI. This pulls content from S3.

    This includes:
    1. Saving all individual panel images as artifacts (fetched from S3).
    2. Generating a self-contained HTML (with embedded base64 images fetched from S3) as an artifact.
    3. Generating a Markdown version of the comic as an artifact (based on HTML from S3).

    Returns:
        A confirmation message with instructions on how to view.
    """
    s3_client = _get_s3_client()
    if not s3_client:
        return "Failed to initialize S3 client. Please check AWS credentials."

    results = []

    # 1. Save individual images as artifacts (fetched from S3)
    s3_objects = _list_s3_objects(s3_client, S3_BUCKET_NAME)
    image_keys = sorted(
        [
            key
            for key in s3_objects
            if key.lower().endswith((".png", ".jpg", ".jpeg"))
        ]
    )

    for image_key in image_keys:
        try:
            image_bytes = _read_s3_object(s3_client, S3_BUCKET_NAME, image_key)
            if image_bytes is None:
                raise Exception(f"Could not read image {image_key} from S3.")

            mime_type = (
                "image/png"
                if image_key.lower().endswith(".png")
                else "image/jpeg"
            )
            image_part = types.Part.from_bytes(data=image_bytes, mime_type=mime_type)
            # Use just the filename as the artifact name
            artifact_filename = os.path.basename(image_key)
            await tool_context.save_artifact(f"panel_{artifact_filename}", image_part)
        except Exception as e:
            logger.error(f"Failed to save image artifact {image_key} from S3: {e}")

    results.append(f"Saved {len(image_keys)} panel images from S3 as artifacts.")

    # 2. Create self-contained HTML (with base64 images fetched from S3)
    html_key = "comic.html"
    html_content_bytes = _read_s3_object(s3_client, S3_BUCKET_NAME, html_key)

    if html_content_bytes is None:
        results.append(f"Error: '{html_key}' was not found in S3 bucket '{S3_BUCKET_NAME}'. Cannot create self-contained HTML.")
    else:
        try:
            html_content = html_content_bytes.decode('utf-8')

            # Replace image sources with base64 data, fetching from S3
            def embed_image_from_s3(match):
                img_src_key = match.group(1) # This is like "panel_1.png" or "images/panel_1.png"
                
                # Agent3 uploads images directly to the bucket root
                s3_image_key = img_src_key.replace("images/", "") 
                
                img_data_bytes = _read_s3_object(s3_client, S3_BUCKET_NAME, s3_image_key)
                if img_data_bytes:
                    img_data = base64.b64encode(img_data_bytes).decode("utf-8")
                    ext = os.path.splitext(img_src_key)[1].lower().strip(".")
                    return f'src="data:image/{ext};base64,{img_data}"'
                logger.warning(f"Image {s3_image_key} not found in S3 for embedding.")
                return match.group(0)  # Keep original if not found

            embedded_html = re.sub(
                r'src=["\']([^"\']+\.(?:png|jpg|jpeg))["\']', embed_image_from_s3, html_content
            )

            html_artifact = types.Part.from_bytes(
                data=embedded_html.encode("utf-8"), mime_type="text/html"
            )
            await tool_context.save_artifact("view_full_comic.html", html_artifact)
            results.append(
                "Generated self-contained HTML artifact from S3: 'view_full_comic.html'"
            )
        except Exception as e:
            logger.error(f"Failed to create self-contained HTML from S3: {e}")
            results.append(f"Failed to generate self-contained HTML from S3: {e}")

    # 3. Create a Markdown version (based on HTML from S3)
    try:
        # Simple markdown conversion
        md_content = "# Comic Book Preview\n\n"
        md_content += "This is a preview of your generated comic book. Check the 'Artifacts' tab to see the individual panels and the full HTML view.\n\n"

        if html_content_bytes: # Use the content fetched for HTML embedding
            content = html_content_bytes.decode('utf-8')
            # Extract basic text for the MD
            text_summary = re.sub("<[^<]+?>", "\n", content)
            md_content += "## Story Summary\n"
            md_content += "\n".join(
                [line.strip() for line in text_summary.split("\n") if line.strip()][:30]
            )
        else:
            md_content += "Could not generate full summary as comic.html was not found in S3.\n"

        md_artifact = types.Part.from_bytes(
            data=md_content.encode("utf-8"), mime_type="text/markdown"
        )
        await tool_context.save_artifact("comic_preview.md", md_artifact)
        results.append("Generated Markdown summary artifact from S3: 'comic_preview.md'")
    except Exception as e:
        logger.error(f"Failed to create MD artifact from S3: {e}")

    return (
        "\n".join(results)
        + "\n\nYou can now view the comic directly in the ADK UI's 'Artifacts' pane. Look for 'view_full_comic.html' for the complete layout or 'comic_preview.md' for a summary."
    )
