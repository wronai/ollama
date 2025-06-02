#!/bin/bash

# Test CPU (drugi terminal)
stress --cpu 4 --timeout 60s

# Test pamięci
stress --vm 2 --vm-bytes 1G --timeout 60s

echo "=== DISK PERFORMANCE TEST ==="

# Znajdź wszystkie dyski
disks=$(lsblk -d -n -o NAME | grep -E "(sd|nvme|mmcblk)")

for disk in $disks; do
    device="/dev/$disk"
    if [ -b "$device" ]; then
        echo "Testing $device..."
        echo "Buffered read test:"
        sudo hdparm -t "$device"
        echo "Cache read test:"
        sudo hdparm -T "$device"
        echo "---"
        sleep 1
    fi
done