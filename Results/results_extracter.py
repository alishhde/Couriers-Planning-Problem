import json
import os
from collections import defaultdict

def extract_results():
    # Store results as: {instance_num: {model_name: objective}}
    results = defaultdict(dict)
    model_names = set()
    
    # Read all JSON files
    for i in range(1, 22):
        file_path = f"Results/mzn/{i}.json"
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
                
            # Extract model names and objectives
            for model_name, model_data in data.items():
                model_names.add(model_name)
                # Format objective value based on optimality
                obj_value = model_data['obj']
                if model_data['optimal']:
                    obj_value = f"{obj_value} `**`"
                elif model_data['sol'] != 'N/A':
                    obj_value = f"{obj_value} `*`"
                results[i][model_name] = obj_value
        except FileNotFoundError:
            print(f"Warning: File {file_path} not found")
            continue

    # Generate markdown table
    model_names = sorted(list(model_names))
    
    # Header
    markdown = "| Instance |"
    for model in model_names:
        markdown += f" {model.split('.')[1].split(' - Final Model - ')[0] + " " + model.split('.')[1].split(' - Final Model - ')[1]} |"
    markdown += "\n"
    
    # Separator
    markdown += "|" + "|".join(["-" * 10 for _ in range(len(model_names) + 1)]) + "|\n"
    
    # Data rows
    for i in range(1, 22):
        markdown += f"| {i} |"
        for model in model_names:
            value = results[i].get(model, "-")
            markdown += f" {value} |"
        markdown += "\n"
    
    # Write to file
    with open("results_table.md", "w") as f:
        f.write(markdown)

if __name__ == "__main__":
    extract_results()