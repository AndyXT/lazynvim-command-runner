#!/usr/bin/env python3
# Script that processes a file that may need to be regenerated with timestamp
import sys
import os
import time
import random
from datetime import datetime

if len(sys.argv) < 2:
    print("Usage: file_processor.py <data_file>")
    sys.exit(1)

data_file = sys.argv[1]

def process_file(file_path):
    """Process the data file and return success or failure"""
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()
            
        print(f"Processing file: {os.path.basename(file_path)}")
        print(f"File contains {len(lines)} lines of data")
        
        # Simulate processing
        time.sleep(1)
        
        # Random chance of failure to demonstrate regeneration
        if random.random() < 0.3:  # 30% chance of failure
            print("ERROR: Data format in file is incorrect or corrupted")
            print("Please regenerate the file and try again")
            return False
        
        # Success
        print("Successfully processed data:")
        for i, line in enumerate(lines[:5], 1):
            print(f"  {i}. {line.strip()}")
        
        if len(lines) > 5:
            print(f"  ... and {len(lines) - 5} more lines")
            
        return True
        
    except Exception as e:
        print(f"Error processing file: {e}")
        return False

# Check if we need to generate a test data file
if not os.path.exists(data_file) or data_file.endswith("_generate"):
    base_name = data_file.replace("_generate", "")
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    new_file = f"{base_name}_{timestamp}.dat"
    
    print(f"Generating new data file: {new_file}")
    
    # Generate some random data
    with open(new_file, 'w') as f:
        for i in range(random.randint(10, 20)):
            f.write(f"Data entry {i+1}: Value={random.randint(1, 100)}, Time={time.time()}\n")
    
    print(f"Data file generated: {new_file}")
    data_file = new_file

# Process the file
success = process_file(data_file)

if not success:
    print("\nSuggestion: Run this script again with '_generate' appended to create a new data file")
    print(f"Example: {sys.argv[0]} {os.path.splitext(data_file)[0]}_generate{os.path.splitext(data_file)[1]}")
else:
    print("\nProcessing complete!")