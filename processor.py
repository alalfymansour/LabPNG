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
