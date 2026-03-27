import os
import glob

# Patch Dart files in services
files = glob.glob('smart_travel_app/lib/services/*.dart')
for filepath in files:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Very safely prefix ALL raw print(' sentences
    content = content.replace("print('", "print('[AGENT] ")
    content = content.replace('print("', 'print("[AGENT] ')
    
    # Clean up double agent string if it happened:
    content = content.replace('[AGENT] [AGENT]', '[AGENT]')
    content = content.replace('[AGENT] [API SEQUENCE]', '[API SEQUENCE]')

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
print("DART PRINT PREFIX COMPLETE")
