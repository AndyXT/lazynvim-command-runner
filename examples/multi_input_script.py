#!/usr/bin/env python3
# Script that demonstrates multiple input prompts and generates a list
import sys
import time
import random

# This script will:
# 1. Ask for an IP address
# 2. Ask for a port number
# 3. Generate a list of "services" that might be running

if len(sys.argv) < 1:
    print("Usage: multi_input_script.py")
    sys.exit(1)

# These would normally be requested from the user via input()
# but we're using command line arguments to make it work with our system
ip_address = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
port = sys.argv[2] if len(sys.argv) > 2 else "8080"

print(f"Scanning {ip_address}:{port} for services...")
time.sleep(1)  # Simulate work

# Generate some random services
services = [
    f"HTTP server (Apache) - ID: SERV{random.randint(1000, 9999)}",
    f"Database (PostgreSQL) - ID: SERV{random.randint(1000, 9999)}",
    f"Cache (Redis) - ID: SERV{random.randint(1000, 9999)}",
    f"Message Queue (RabbitMQ) - ID: SERV{random.randint(1000, 9999)}",
    f"File server (NFS) - ID: SERV{random.randint(1000, 9999)}"
]

print(f"\nFound {len(services)} services on {ip_address}:{port}:")
for i, service in enumerate(services, 1):
    print(f"{i}. {service}")

print("\nSelect a service by its number or ID to investigate further.")