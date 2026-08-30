import base64
import requests
import json

# Настройки из вашего конфига
BASE_URL = "http://192.168.0.86:9103/v1/chat/completions"
MODEL_ID = "google/gemma-4-12B-it-qat-q4_0-gguf"
API_KEY = "dummy"

# Путь к сжатому файлу
IMAGE_PATH = "/Users/user/Downloads/Новая папка с объектами 33/compressed_image.jpg"

def encode_image(path):
    with open(path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')

def analyze_image():
    try:
        print(f"--- Reading image: {IMAGE_PATH} ---")
        base64_image = encode_image(IMAGE_PATH)
        
        print(f"--- Sending to server: {BASE_URL} ---")
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
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}"
                            }
                        },
                        {
                            "type": "text",
                            "text": "What is shown in this image? Describe it in detail."
                        }
                    ]
                }
            ],
            "max_tokens": 1024,
            "temperature": 0.7
        }

        response = requests.post(BASE_URL, headers=headers, data=json.dumps(payload))
        
        if response.status_code == 200:
            print("--- Response received ---")
            res_json = response.json()
            if 'choices' in res_json and len(res_json['choices']) > 0:
                print(res_json['choices'][0]['message']['content'])
            else:
                print(json.dumps(res_json, indent=2))
        else:
            print(f"Error: {response.status_code}")
            print(response.text)

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    analyze_image()
