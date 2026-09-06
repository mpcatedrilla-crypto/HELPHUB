import json
data = json.load(open('schema.json', encoding='utf-8'))
paths = json.dumps(data)
if "report_status" in paths: print("report_status found!")
else: print("report_status not found.")
import re
print("Found enums:")
for m in re.findall(r'"([^"]+)"\s*:\s*\{[^}]*"enum"\s*:\s*\[(.*?)\]', paths):
    print(m)
