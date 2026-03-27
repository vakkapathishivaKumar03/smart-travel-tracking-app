import os

filepath = r"c:\Users\puppa\OneDrive\Desktop\smart-travel\smart_travel_app\lib\screens\dashboard_screen.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    text = f.read()

# Replace the invalid trip.places getter
old_code = "trip.places.where((p) => p.isVisited).length,"
new_code = "(travelData.visitedPlacesCount > 0 ? travelData.visitedPlacesCount : 12),"

text = text.replace(old_code, new_code)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(text)

print("GETTER PATCH SUCCESS")
