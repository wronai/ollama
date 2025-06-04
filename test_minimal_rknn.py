#!/usr/bin/env python3
"""
Minimal RKNN test - tests if we can access NPU hardware
"""

import sys
import os
import subprocess

def test_npu_device():
    """Test if NPU device is accessible"""
    npu_devices = ['/dev/rknpu']

    for device in npu_devices:
        if os.path.exists(device):
            print(f"✓ Found NPU device: {device}")

            # Check permissions
            if os.access(device, os.R_OK | os.W_OK):
                print(f"✓ Device {device} is accessible")
                return True
            else:
                print(f"⚠ Device {device} exists but no permissions")
                return False
        else:
            print(f"✗ NPU device {device} not found")

    return False

def test_rknn_server():
    """Test if RKNN server is running"""
    try:
        result = subprocess.run(['pgrep', 'rknn_server'],
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("✓ RKNN server is running")
            return True
        else:
            print("✗ RKNN server is not running")
            return False
    except Exception as e:
        print(f"⚠ Could not check RKNN server: {e}")
        return False

def test_basic_libs():
    """Test basic required libraries"""
    libs = ['numpy', 'cv2', 'PIL']

    all_ok = True
    for lib in libs:
        try:
            __import__(lib)
            print(f"✓ {lib} available")
        except ImportError:
            print(f"✗ {lib} not available")
            all_ok = False

    return all_ok

if __name__ == "__main__":
    print("=== Minimal RKNN Hardware Test ===")

    print("\n1. Testing basic libraries:")
    libs_ok = test_basic_libs()

    print("\n2. Testing NPU device:")
    device_ok = test_npu_device()

    print("\n3. Testing RKNN server:")
    server_ok = test_rknn_server()

    print(f"\n=== Results ===")
    print(f"Libraries: {'✓' if libs_ok else '✗'}")
    print(f"NPU Device: {'✓' if device_ok else '✗'}")
    print(f"RKNN Server: {'✓' if server_ok else '✗'}")

    if device_ok and server_ok:
        print("\n🎉 NPU hardware is ready!")
        print("You can use the NPU even without the full RKNN Toolkit2")
    elif device_ok:
        print("\n⚠ NPU hardware detected but server not running")
        print("Start with: sudo systemctl start rknn-server")
    else:
        print("\n❌ NPU hardware issues detected")

    print("\nNext steps:")
    print("- Check NPU service: sudo systemctl status rknn-server")
    print("- Start NPU service: sudo systemctl start rknn-server")
    print("- Check user groups: groups")
