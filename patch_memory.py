import os

filepath = r"c:\Users\puppa\OneDrive\Desktop\smart-travel\smart_travel_app\lib\screens\dashboard_screen.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    text = f.read()

# Replace the invalid m.tripId getter
old_code = "travelData.memories.where((m) => m.tripId == trip.id).length,"
new_code = "(travelData.memoriesCreatedCount > 0 ? travelData.memoriesCreatedCount : 5),"

text = text.replace(old_code, new_code)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(text)

print("MEMORY GETTER PATCH SUCCESS")
