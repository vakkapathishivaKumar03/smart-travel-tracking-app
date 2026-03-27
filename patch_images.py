import os

filepath = r"c:\Users\puppa\OneDrive\Desktop\smart-travel\smart_travel_app\lib\screens\dashboard_screen.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    text = f.read()

# Banner
if "if (travelData.tripIsActive) _buildLiveNowCard()" not in text:
    text = text.replace("                _buildLiveNowCard(),", "                if (travelData.tripIsActive) _buildLiveNowCard(),")

# _tripStitchCard
old_trip = """  Widget _tripStitchCard(String title, String dates, Color tagColor) {
    return Container(
      width: 220,
      height: 120,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: tagColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: AssetImage('assets/images/header.png'),"""
new_trip = """  Widget _tripStitchCard(String title, String dates, Color tagColor) {
    return Container(
      width: 220,
      height: 120,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: tagColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: NetworkImage('https://picsum.photos/seed/${title.hashCode}/400/300'),"""

text = text.replace(old_trip, new_trip)

# _memoryStitchCard
old_mem = """  Widget _memoryStitchCard(Color color) {
    return Container(
      width: 90,
      height: 90,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(
          image: AssetImage('assets/images/header.png'),"""
new_mem = """  Widget _memoryStitchCard(Color color) {
    return Container(
      width: 90,
      height: 90,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: NetworkImage('https://picsum.photos/seed/${color.hashCode}/200/200'),"""

text = text.replace(old_mem, new_mem)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(text)

print("IMAGE DIVERSIFICATION SUCCESS")
