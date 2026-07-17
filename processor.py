"""
Background removal using rembg with u2netp model.

u2netp chosen over u2net: ~5MB model vs ~200MB, much faster download and inference,
while still producing high-quality results suitable for a web tool.
"""
from rembg import new_session, remove
import io

_session = new_session("u2netp")

def remove_background(image_bytes: bytes) -> bytes:
    """Remove background from image bytes, return PNG bytes."""
    input_stream = io.BytesIO(image_bytes)
    output_image = remove(input_stream, session=_session)
    output_stream = io.BytesIO()
    output_image.save(output_stream, format="PNG")
    return output_stream.getvalue()
