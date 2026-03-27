import os

filepath = r"c:\Users\puppa\OneDrive\Desktop\smart-travel\smart_travel_app\lib\screens\dashboard_screen.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace(r"\${report['expenses']", r"${report['expenses']")
text = text.replace(r"\${report['visited_places']}", r"${report['visited_places']}")
text = text.replace(r"\${report['memories_logged']}", r"${report['memories_logged']}")
text = text.replace(r"\${report['assessment']}", r"${report['assessment']}")

# Fix import
if "import '../services/smart_travel_agent.dart';" not in text:
    text = text.replace("import '../services/travel_data_service.dart';", "import '../services/smart_travel_agent.dart';\nimport '../services/travel_data_service.dart';")

# Fix travelData.memoryList to travelData.memories
text = text.replace("travelData.memoryList.where", "travelData.memories.where")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(text)
print("DASHBOARD COMPILE FIX SUCCESS")
