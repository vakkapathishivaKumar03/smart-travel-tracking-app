import os

filepath = r"c:\Users\puppa\OneDrive\Desktop\smart-travel\smart_travel_app\lib\screens\dashboard_screen.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Image Diversification Fix (bypassing cache and ensuring uniqueness)
# Replace previous attempts if any
text = text.replace(
    "image: NetworkImage('https://picsum.photos/seed/${title.hashCode}/400/300')",
    "image: NetworkImage('https://picsum.photos/seed/${title.replaceAll(' ', '_')}_${title.length}/400/300')"
)
text = text.replace(
    "image: NetworkImage('https://picsum.photos/seed/${color.hashCode}/200/200')",
    "image: NetworkImage('https://picsum.photos/seed/mem_${color.value}/200/200')"
)

# 2. Expense Visibility
# Ensure _buildStitchExpenseWarning() and _buildStitchAutoExpenses() are only shown if tripIsActive
if "if (travelData.tripIsActive) _buildStitchExpenseWarning()" not in text:
    text = text.replace(
        "              _buildStitchExpenseWarning(),",
        "              if (travelData.tripIsActive) _buildStitchExpenseWarning(),"
    )

if "if (travelData.tripIsActive) _buildStitchAutoExpenses()" not in text:
    text = text.replace(
        "              _buildStitchAutoExpenses(),",
        "              if (travelData.tripIsActive) _buildStitchAutoExpenses(),"
    )

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(text)

print("DASHBOARD REFINEMENT SUCCESS")
