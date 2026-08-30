import base64
import requests
import json
import os

# Настройки
BASE_URL = "http://192.168.0.86:9103/v1/chat/completions"
MODEL_ID = "google/gemma-4-12B-it-qat-q4_0-gguf"
API_KEY = "dummy"

# Список пар для анализа (Путь к базовым текстурам биомов)
# Выберем по одному репрезентативному файлу для каждой пары
PAIRS = [
    {
        "name": "Grass vs Sand",
        "images": [
            "data/processed/grass/base/1.png", # Заглушка, если 1.png нет, возьмем любой
            "data/processed/sand/base/1.png"
        ]
    },
    {
        "name": "Forest vs Snow",
        "images": [
            "data/processed/forest/base/1.png",
            "data/processed/snow/base/b_удали_кристаллы.jpeg"
        ]
    },
    {
        "name": "Swamp vs Water",
        "images": [
            "data/processed/swamp/base/1787744067119-01a03dd6-496c-7899-bf37-dc9d7d792d76-0.png",
            "data/processed/water/base/1787744634669-01a03de1-2459-76b3-a9b6-e7d068a3a481-0.png"
        ]
    },
    {
        "name": "Mountain vs Grass",
        "images": [
            "data/processed/mountain/base/1.png",
            "data/processed/grass/base/1.png"
        ]
    }
]

def encode_image(path):
    if not os.path.exists(path):
        # Попытка найти любой файл в папке, если конкретный не найден
        folder = os.path.dirname(path)
        files = [f for f in os.listdir(folder) if f.endswith(('.png', '.jpg', '.jpeg'))]
        if files:
            path = os.path.join(folder, files[0])
            print(f"Warning: File {path} not found, using {path} instead.")
        else:
            print(f"Error: No image found for {path}")
            return None
            
    with open(path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')

def analyze_pairs():
    results = []
    for pair in PAIRS:
        print(f"--- Analyzing: {pair['name']} ---")
        img1_b64 = encode_image(pair['images'][0])
        img2_b64 = encode_image(pair['images'][1])
        
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
                            "text": f"Compare these two textures ({pair['name']}). "
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
            content = res_json['choices'][0]['message']['content']
            print(content)
            results.append(content)
        else:
            print(f"Failed: {response.status_code}")

if __name__ == "__main__":
    analyze_pairs()
