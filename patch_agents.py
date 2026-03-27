import os

filepath = 'routes/agents.py'
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    new_lines.append(line)
    if 'summary = expense_agent.run({"expenses":' in line:
        new_lines.append('    print("[API SEQUENCE] ExpenseAgent persisting new transaction.")\n')
    elif 'result = planning_agent.run(input_data)' in line:
        new_lines.insert(-1, '        print("[API SEQUENCE] TripAgent syncing location status to Cloud.")\n')
    elif 'memory_response = memory_agent.run({"note": note' in line:
        new_lines.append('    print("[API SEQUENCE] AlbumAgent archiving generated media.")\n')

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print("PATCH SUCCESSFUL")
