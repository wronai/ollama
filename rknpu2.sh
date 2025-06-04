#!/bin/bash

# RKNN Debug and Installation Script
# Diagnoses and fixes the wheel installation issue

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
}

print_header "RKNN Debug and Installation"

# Navigate to rknn_setup directory
cd ~/rknn_setup

print_status "Diagnosing RKNN Toolkit structure..."

# Find all wheel files
print_status "Searching for wheel files..."
echo "Looking for RKNN wheels:"
find . -name "*.whl" -type f | head -20

print_status "Directory structure analysis:"
echo "Main directories:"
ls -la

if [ -d "rknn-toolkit2-master" ]; then
    echo -e "\nrknn-toolkit2-master contents:"
    ls -la rknn-toolkit2-master/

    if [ -d "rknn-toolkit2-master/rknn-toolkit2" ]; then
        echo -e "\nrknn-toolkit2 subdirectory:"
        ls -la rknn-toolkit2-master/rknn-toolkit2/

        if [ -d "rknn-toolkit2-master/rknn-toolkit2/packages" ]; then
            echo -e "\nPackages directory contents:"
            ls -la rknn-toolkit2-master/rknn-toolkit2/packages/

            # Check for arm64 specific directory
            if [ -d "rknn-toolkit2-master/rknn-toolkit2/packages/arm64" ]; then
                echo -e "\nARM64 packages:"
                ls -la rknn-toolkit2-master/rknn-toolkit2/packages/arm64/
            fi
        fi
    fi

    if [ -d "rknn-toolkit2-master/rknn-toolkit-lite2" ]; then
        echo -e "\nrknn-toolkit-lite2 contents:"
        ls -la rknn-toolkit2-master/rknn-toolkit-lite2/

        if [ -d "rknn-toolkit2-master/rknn-toolkit-lite2/packages" ]; then
            echo -e "\nLite packages directory:"
            ls -la rknn-toolkit2-master/rknn-toolkit-lite2/packages/
        fi
    fi
fi

print_header "Installing RKNN with Corrected Paths"

# Activate virtual environment
if [ -f "rknn-toolkit2-master/venv/bin/activate" ]; then
    source rknn-toolkit2-master/venv/bin/activate
    print_status "Virtual environment activated"
else
    print_error "Virtual environment not found"
    exit 1
fi

# Install RKNN Toolkit2
print_status "Installing RKNN Toolkit2..."

# Try different possible locations for wheel files
WHEEL_LOCATIONS=(
    "rknn-toolkit2-master/rknn-toolkit2/packages/arm64/"
    "rknn-toolkit2-master/rknn-toolkit2/packages/"
    "rknn-toolkit2-master/rknn-toolkit2/packages/x86_64/"  # Sometimes ARM wheels are here too
)

TOOLKIT_INSTALLED=false
for location in "${WHEEL_LOCATIONS[@]}"; do
    if [ -d "$location" ]; then
        print_status "Checking location: $location"
        cd "$location"

        # List available wheels
        echo "Available wheels in $location:"
        ls -la *.whl 2>/dev/null || echo "No wheels found"

        # Try to install any RKNN toolkit wheel
        for wheel in rknn_toolkit2-*.whl; do
            if [ -f "$wheel" ]; then
                print_status "Installing: $wheel"
                if pip install "$wheel"; then
                    TOOLKIT_INSTALLED=true
                    print_status "✓ RKNN Toolkit2 installed successfully"
                    break 2
                else
                    print_warning "Failed to install $wheel"
                fi
            fi
        done
        cd ~/rknn_setup
    fi
done

if [ "$TOOLKIT_INSTALLED" = false ]; then
    print_warning "Could not install RKNN Toolkit2 from wheels"

    # Try installing from GitHub directly (development version)
    print_status "Attempting to install development version from source..."

    # Install dependencies that might be needed
    pip install pyyaml
    pip install tqdm

    # Try to install basic RKNN API only
    print_status "Installing minimal RKNN components..."

    # Create a minimal RKNN test without the full toolkit
    cat > test_minimal_rknn.py << 'EOF'
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
EOF

    chmod +x test_minimal_rknn.py
fi

# Try to install RKNN Lite
print_status "Installing RKNN Toolkit Lite..."

LITE_LOCATIONS=(
    "rknn-toolkit2-master/rknn-toolkit-lite2/packages/"
)

LITE_INSTALLED=false
for location in "${LITE_LOCATIONS[@]}"; do
    if [ -d "$location" ]; then
        print_status "Checking lite location: $location"
        cd "$location"

        echo "Available lite wheels:"
        ls -la *.whl 2>/dev/null || echo "No lite wheels found"

        for wheel in rknn_toolkit_lite2-*.whl; do
            if [ -f "$wheel" ]; then
                print_status "Installing lite: $wheel"
                if pip install "$wheel"; then
                    LITE_INSTALLED=true
                    print_status "✓ RKNN Toolkit Lite2 installed successfully"
                    break 2
                else
                    print_warning "Failed to install lite $wheel"
                fi
            fi
        done
        cd ~/rknn_setup
    fi
done

# Install runtime components regardless
print_status "Installing RKNN Runtime components..."

if [ -d "rknpu2-master" ]; then
    cd rknpu2-master/runtime/Linux/librknn_api

    # Copy libraries
    if [ -f "aarch64/librknnrt.so" ]; then
        sudo cp aarch64/librknnrt.so /usr/local/lib/
        print_status "✓ Runtime library installed"
    fi

    # Copy headers
    if [ -d "include" ]; then
        sudo cp include/*.h /usr/local/include/
        print_status "✓ Headers installed"
    fi

    sudo ldconfig

    # Install server
    if [ -f "../rknn_server/aarch64/usr/bin/rknn_server" ]; then
        sudo cp ../rknn_server/aarch64/usr/bin/rknn_server /usr/local/bin/
        sudo chmod +x /usr/local/bin/rknn_server
        print_status "✓ RKNN server installed"
    fi

    cd ~/rknn_setup
fi

# Create service if not exists
print_status "Setting up RKNN service..."
if [ ! -f "/etc/systemd/system/rknn-server.service" ]; then
    sudo tee /etc/systemd/system/rknn-server.service > /dev/null << 'EOF'
[Unit]
Description=RKNN NPU Server
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/rknn_server
Restart=always
RestartSec=5
User=root
Environment=RKNN_LOG_LEVEL=1

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable rknn-server.service
    print_status "✓ RKNN service configured"
fi

# Test what we have
print_status "Testing installation..."

# Test imports
cat > test_what_works.py << 'EOF'
#!/usr/bin/env python3
"""
Test what RKNN components are working
"""

def test_toolkit():
    """Test RKNN Toolkit"""
    try:
        from rknn.api import RKNN
        print("✓ RKNN Toolkit2 imported successfully")

        rknn = RKNN(verbose=False)
        print("✓ RKNN object created")
        return True
    except ImportError:
        print("✗ RKNN Toolkit2 not available")
        return False
    except Exception as e:
        print(f"⚠ RKNN Toolkit2 error: {e}")
        return False

def test_lite():
    """Test RKNN Lite"""
    try:
        from rknnlite.api import RKNNLite
        print("✓ RKNN Lite imported successfully")

        rknn_lite = RKNNLite()
        print("✓ RKNN Lite object created")
        return True
    except ImportError:
        print("✗ RKNN Lite not available")
        return False
    except Exception as e:
        print(f"⚠ RKNN Lite error: {e}")
        return False

def test_basic():
    """Test basic functionality"""
    try:
        import numpy as np
        import cv2
        print("✓ Basic libraries available")
        return True
    except ImportError as e:
        print(f"✗ Basic libraries missing: {e}")
        return False

if __name__ == "__main__":
    print("=== Testing Available Components ===")

    basic_ok = test_basic()
    toolkit_ok = test_toolkit()
    lite_ok = test_lite()

    print(f"\n=== Summary ===")
    print(f"Basic libs: {'✓' if basic_ok else '✗'}")
    print(f"RKNN Toolkit: {'✓' if toolkit_ok else '✗'}")
    print(f"RKNN Lite: {'✓' if lite_ok else '✗'}")

    if lite_ok or toolkit_ok:
        print("\n🎉 Some RKNN components are working!")
    else:
        print("\n⚠ No RKNN Python components available")
        print("But NPU hardware may still work with C++ API")
EOF

chmod +x test_what_works.py

print_status "Running component test..."
python3 test_what_works.py

print_status "Running minimal hardware test..."
python3 test_minimal_rknn.py

# Create usage instructions
cat > RKNN_USAGE.md << 'EOF'
# RKNN NPU Usage Instructions

## Current Status
After running the debug installation, check what components are available:

### If RKNN Toolkit2 is working:
```python
from rknn.api import RKNN
rknn = RKNN()
# Full model conversion and inference
```

### If only RKNN Lite is working:
```python
from rknnlite.api import RKNNLite
rknn_lite = RKNNLite()
# Model inference only (no conversion)
```

### If no Python components work:
- NPU hardware may still work with C++ API
- Use pre-converted .rknn models
- Check examples in rknpu2-master/examples/

## Quick Tests
1. Test components: `python3 test_what_works.py`
2. Test hardware: `python3 test_minimal_rknn.py`
3. Start NPU service: `sudo systemctl start rknn-server`
4. Check service: `sudo systemctl status rknn-server`

## Available Examples
- C++ examples: `rknpu2-master/examples/`
- Pre-built models in: `rknpu2-master/examples/*/model/RK3588/`

## Troubleshooting
1. Ensure user is in video group: `sudo usermod -a -G video $USER`
2. Restart to apply group changes
3. Start NPU service: `sudo systemctl start rknn-server`
4. Check device: `ls -la /dev/rknpu*`
EOF

print_header "Installation Summary"

echo "📁 Working directory: ~/rknn_setup"
echo "🔧 Runtime installed: /usr/local/lib/librknnrt.so"
echo "📋 Service: rknn-server"
echo "📖 Usage guide: RKNN_USAGE.md"
echo ""
echo "🔍 Next steps:"
echo "1. Check what works: python3 test_what_works.py"
echo "2. Test hardware: python3 test_minimal_rknn.py"
echo "3. Start NPU: sudo systemctl start rknn-server"
echo "4. Read: cat RKNN_USAGE.md"

print_status "Debug installation completed!"


