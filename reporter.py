import json
import os

def write_json_report(data, file_path):
    """
    Writes a dictionary to a JSON file (pretty-printing).
    """
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with open(file_path, 'w') as f:
        json.dump(data, f, indent=4)

def write_txt_report(data, file_path):
    """
    Writes a list of strings to a text file, one per line.
    """
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with open(file_path, 'w') as f:
        for line in data:
            f.write(line + '\n')
