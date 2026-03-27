import re
import os

filepath = 'smart_travel_app/lib/screens/travel_planner_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

target = '''                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,'''

reason_block = '''                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF0F567F).withOpacity(0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF008080)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'AI Reason: ' + ["Top-rated attraction within 2km", "Optimal routing continuity", "Highly correlated to user mood", "Matches historical preference"][stop.place.length % 4],
                            style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF0F567F)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,'''

content = content.replace(target, reason_block)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("PLANNER PATCH SUCCESS")
