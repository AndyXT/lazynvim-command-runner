#!/usr/bin/env python3
# Script that demonstrates using piped input from previous command
import sys
import time
import random

if len(sys.argv) < 3:
    print("Usage: service_investigator.py <ip_address> <service_id>")
    sys.exit(1)

ip_address = sys.argv[1]
service_id = sys.argv[2]

# Extract service ID if a full line was piped
if "ID:" in service_id:
    import re
    match = re.search(r'ID: (SERV\d+)', service_id)
    if match:
        service_id = match.group(1)

print(f"Investigating service {service_id} on {ip_address}...")
time.sleep(1)  # Simulate work

# Generate some details about the service
details = {
    "status": random.choice(["running", "stopped", "restarting"]),
    "uptime": f"{random.randint(1, 999)} hours",
    "cpu_usage": f"{random.randint(1, 100)}%",
    "memory_usage": f"{random.randint(50, 500)} MB",
    "connections": random.randint(1, 50),
    "version": f"{random.randint(1, 5)}.{random.randint(0, 9)}.{random.randint(0, 20)}"
}

print(f"\nService Details for {service_id}:")
print("=" * 40)
for key, value in details.items():
    print(f"{key.replace('_', ' ').title()}: {value}")

print("\nLogs:")
log_entries = [
    f"[INFO] Service {service_id} started",
    f"[INFO] Connected to database",
    f"[INFO] Processed {random.randint(100, 1000)} requests",
    f"[WARN] High CPU usage detected: {details['cpu_usage']}",
    f"[INFO] Cache hit ratio: {random.randint(50, 95)}%"
]

for entry in log_entries:
    print(entry)

print("\nRecommended Actions:")
actions = [
    f"Monitor CPU usage if it remains above 80%",
    f"Check for memory leaks if usage continues to increase",
    f"Consider upgrading to version {random.randint(5, 10)}.0.0 for better performance",
    f"Restart service if connections exceed 100"
]

for i, action in enumerate(actions, 1):
    print(f"{i}. {action}")