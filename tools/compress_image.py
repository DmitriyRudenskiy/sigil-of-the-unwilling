import os
from PIL import Image

def compress_to_jpg(input_path, output_path, quality=80):
    try:
        img = Image.open(input_path)
        # Convert to RGB if needed (JPG doesn't support alpha)
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")
        img.save(output_path, "JPEG", quality=quality)
        print(f"Successfully compressed: {output_path}")
    except Exception as e:
        print(f"Error during compression: {e}")

if __name__ == "__main__":
    input_file = "/Users/user/Downloads/Новая папка с объектами 33/mai-image-2.6-preview (image-edit)_b_Quality_improvements.png"
    output_file = "/Users/user/Downloads/Новая папка с объектами 33/compressed_image.jpg"
    compress_to_jpg(input_file, output_file)
