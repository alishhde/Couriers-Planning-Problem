import json
import os

# Change the instances you want to read from input
DO_INST = 1
UP_INST = 22


# Initialize the Markdown table header
header = "| Model | " + " | ".join([f"inst{i}" for i in range(DO_INST, UP_INST)]) + " |\n"
header += "| :---: | " + " | ".join([":---:" for _ in range(DO_INST, UP_INST)]) + " |\n"

# Initialize the Markdown table rows
rows = {}

# Process each JSON file in the Results/mzn folder
for i in range(DO_INST, UP_INST):
    file_path = f'Results/mzn/{i}.json'
    with open(file_path) as f:
        data = json.load(f)
    
    for model, details in data.items():
        if model not in rows:
            rows[model] = ["N/A"] * 21
        
        time = details["time"]
        optimal = details["optimal"]
        obj = details["obj"]
        
        if obj == "N/A":
            result = "N/A"
        elif optimal:
            result = f"`**`{obj} ({time}s)"
        else:
            result = f"`*`{obj} ({time}s)"
        
        rows[model][i-1] = result

# Construct the Markdown table
markdown_table = header
for model, results in rows.items():
    model_name = model.split("-")[0].split('. ')[1]
    markdown_table += f"| {model_name} | " + " | ".join(results) + " |\n"

# Print the Markdown table
print(markdown_table)