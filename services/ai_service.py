import os
import requests

# This is an example implementation using OpenAI REST API.
# If OpenAI package is not installed use this with requests.

OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY', '')
OPENAI_API_URL = 'https://api.openai.com/v1/completions'


def generate_ai_response(prompt: str) -> str:
    if not OPENAI_API_KEY:
        print('AI Service: OPENAI_API_KEY not found, skipping AI call.')
        return 'AI unavailable: API key missing.'

    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {OPENAI_API_KEY}',
    }

    body = {
        'model': 'text-davinci-003',
        'prompt': prompt,
        'max_tokens': 150,
        'temperature': 0.7,
        'n': 1,
    }

    try:
        response = requests.post(OPENAI_API_URL, headers=headers, json=body, timeout=10)
        response.raise_for_status()
        data = response.json()
        choices = data.get('choices', [])
        if choices and isinstance(choices, list):
            return choices[0].get('text', '').strip()
        return 'AI did not return a result.'
    except Exception as e:
        print(f'AI Service: failed to generate response: {e}')
        return f'AI error: {str(e)}'
