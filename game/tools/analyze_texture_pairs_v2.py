import base64
import requests
import json
import os

# Настройки
BASE_URL = "http://192.168.0.86:9103/v1/chat/completions"
MODEL_ID = "google/gemma-4-12B-it-qat-q4_0-gguf"
API_KEY = "dummy"

# Пути к папкам биомов
BIOMES = {
    "grass": "data/processed/grass/base",
    "sand": "data/processed/sand/base",
    "forest": "data/processed/forest/base",
    "snow": "data/processed/snow/base",
    "swamp": "data/processed/swamp/base",
    "water": "data/processed/water/base",
    "mountain": "data/processed/mountain/base"
}

def get_first_image(folder):
    if not os.path.exists(folder):
        return None
    files = [f for f in os.listdir(folder) if f.endswith(('.png', '.jpg', '.jpeg'))]
    if files:
        return os.path.join(folder, files[0])
    return None

# Формируем пары для сравнения
PAIRS = [
    ("Grass vs Sand", BIOMES["grass"], BIOMES["sand"]),
    ("Forest vs Snow", BIOMES["forest"], BIOMES["snow"]),
    ("Swamp vs Water", BIOMES["swamp"], BIOMES["water"]),
    ("Mountain vs Grass", BIOMES["mountain"], BIOMES["grass"])
]

def encode_image(path):
    if not path or not os.path.exists(path):
        return None
    with open(path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')

def analyze_pairs():
    for name, folder1, folder2 in PAIRS:
        path1 = get_first_image(folder1)
        path2 = get_first_image(folder2)
        
        if not path1 or not path2:
            print(f"Skipping {name}: Files not found in {folder1} or {folder2}")
            continue
            
        print(f"--- Analyzing: {name} ---")
        img1_b64 = encode_image(path1)
        img2_b64 = encode_image(path2)
        
        if not img1_b64 or not img2_b64:
            continue
            
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {API_KEY}"
        }
        
        payload = {
            "model": MODEL_ID,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/png;base64,{img1_b64}"}
                        },
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/png;base64,{img2_b64}"}
                        },
                        {
                            "type": "text",
                            "text": f"Compare these two textures ({name}). "
                                    "Describe their color palette, visual weight, and how well they might transition "
                                    "into each other on a world map. Which one feels more 'primary' and which 'accent'?"
                        }
                    ]
                }
            ],
            "max_tokens": 1024,
            "temperature": 0.7
        }

        response = requests.post(BASE_URL, headers=headers, data=json.dumps(payload))
        if response.status_code == 200:
            res_json = response.json()
            print(res_json['choices'][0]['message']['content'])
            print("-" * 50)
        else:
            print(f"Error: {response.status_code}")

if __name__ == "__main__":
    analyze_pairs()
