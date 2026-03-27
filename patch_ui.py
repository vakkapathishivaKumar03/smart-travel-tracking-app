import os

filepath = r"c:\Users\puppa\OneDrive\Desktop\smart-travel\smart_travel_app\lib\screens\dashboard_screen.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("'Voyager',", "'TripPilot',")
text = text.replace("travelData.cityName.isEmpty ? 'Hyderabad' : travelData.cityName", "travelData.cityName.isEmpty ? 'a new destination' : travelData.cityName")
text = text.replace("'Banjara Hills, Road No. 12'", "'Discovering local gems...'")

old_container = """                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFDAB9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.book, size: 16, color: Colors.white),
                      ),"""

new_container = """                      Container(
                        padding: const EdgeInsets.all(2),
                        child: Image.asset('assets/logo/travelpilot_logo.png', width: 24, height: 24),
                      ),"""

if old_container in text:
    text = text.replace(old_container, new_container)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(text)

print("PATCH UI COMPLETE")
