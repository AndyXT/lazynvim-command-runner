#!/usr/bin/env python3
# Simple script to analyze a log file
import sys
import os.path

if len(sys.argv) < 2:
    print("Usage: analyze_log.py <log_file>")
    sys.exit(1)

log_file = sys.argv[1]

print(f"Analyzing log file: {os.path.basename(log_file)}")

try:
    with open(log_file, 'r') as f:
        lines = f.readlines()
        print(f"Log file contains {len(lines)} lines")
        
        if lines:
            print("First entry:", lines[0].strip())
            if len(lines) > 1:
                print("Last entry:", lines[-1].strip())
                
        print(f"Analysis complete for {os.path.basename(log_file)}")
except Exception as e:
    print(f"Error analyzing log file: {e}")
    sys.exit(1)