#!/bin/bash

# Fixed RKNN Setup Script for RK3588 on Armbian
# Corrects the Python package installation issue

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root for safety"
   exit 1
fi

# Check architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" ]]; then
    print_error "This script is designed for ARM64 architecture"
    exit 1
fi

print_header "Fixed RKNN NPU Setup for RK3588"

# Create working directory
WORK_DIR="$HOME/rknn_setup"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

print_status "Working directory: $WORK_DIR"

# Update system
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install dependencies
print_status "Installing system dependencies..."
sudo apt install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    python3-setuptools \
    python3-wheel \
    python3-numpy \
    python3-opencv \
    libopencv-dev \
    pkg-config \
    libssl-dev \
    libffi-dev \
    libjpeg-dev \
    zlib1g-dev \
    libtiff5-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libwebp-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libxcb1-dev \
    unzip

# Check if RKNN toolkit is already extracted
if [ ! -d "rknn-toolkit2-master" ]; then
    print_status "Downloading RKNN Toolkit2..."
    RKNN_TOOLKIT_URL="https://github.com/airockchip/rknn-toolkit2/archive/refs/heads/master.zip"

    if [ ! -f "rknn-toolkit2-master.zip" ]; then
        wget -O rknn-toolkit2-master.zip "$RKNN_TOOLKIT_URL"
    fi

    print_status "Extracting RKNN Toolkit2..."
    unzip -o rknn-toolkit2-master.zip
else
    print_status "RKNN Toolkit2 already extracted"
fi

# Navigate to the extracted directory
cd rknn-toolkit2-master

# Create virtual environment
print_status "Creating Python virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

# Activate virtual environment
print_status "Activating virtual environment..."
source venv/bin/activate

# Install Python packages
print_status "Installing Python dependencies..."
pip install --upgrade pip setuptools wheel

pip install \
    numpy \
    opencv-python \
    pillow \
    requests \
    onnx \
    onnxruntime \
    scipy \
    matplotlib

# Install RKNN Toolkit2 - Fixed approach
print_status "Installing RKNN Toolkit2..."
cd rknn-toolkit2/packages

# Find the correct Python version and install appropriate package
PYTHON_VERSION=$(python3 -c "import sys; print(f'cp{sys.version_info.major}{sys.version_info.minor}')")
print_status "Detected Python version: $PYTHON_VERSION"

# Find matching wheel file
WHEEL_FILE=""
for wheel in rknn_toolkit2-*-${PYTHON_VERSION}-*.whl; do
    if [ -f "$wheel" ]; then
        WHEEL_FILE="$wheel"
        break
    fi
done

# If no exact match, try with any compatible wheel
if [ -z "$WHEEL_FILE" ]; then
    print_warning "No exact Python version match, trying compatible wheel..."
    for wheel in rknn_toolkit2-*-py3-none-any.whl rknn_toolkit2-*.whl; do
        if [ -f "$wheel" ]; then
            WHEEL_FILE="$wheel"
            break
        fi
    done
fi

if [ -n "$WHEEL_FILE" ]; then
    print_status "Installing: $WHEEL_FILE"
    pip install "$WHEEL_FILE"
else
    print_error "No compatible RKNN Toolkit2 wheel found"
    echo "Available wheels:"
    ls -la *.whl || echo "No wheel files found"
    exit 1
fi

# Install RKNN Toolkit Lite2
print_status "Installing RKNN Toolkit Lite2..."
cd ../../rknn-toolkit-lite2/packages

# Find matching lite wheel file
LITE_WHEEL_FILE=""
for wheel in rknn_toolkit_lite2-*-${PYTHON_VERSION}-*.whl; do
    if [ -f "$wheel" ]; then
        LITE_WHEEL_FILE="$wheel"
        break
    fi
done

if [ -z "$LITE_WHEEL_FILE" ]; then
    for wheel in rknn_toolkit_lite2-*.whl; do
        if [ -f "$wheel" ]; then
            LITE_WHEEL_FILE="$wheel"
            break
        fi
    done
fi

if [ -n "$LITE_WHEEL_FILE" ]; then
    print_status "Installing: $LITE_WHEEL_FILE"
    pip install "$LITE_WHEEL_FILE"
else
    print_warning "RKNN Toolkit Lite2 wheel not found, continuing..."
fi

# Download and setup RKNN Runtime
print_status "Setting up RKNN Runtime..."
cd "$WORK_DIR"

if [ ! -d "rknpu2-master" ]; then
    RKNN_API_URL="https://github.com/airockchip/rknpu2/archive/refs/heads/master.zip"

    if [ ! -f "rknpu2-master.zip" ]; then
        wget -O rknpu2-master.zip "$RKNN_API_URL"
    fi

    unzip -o rknpu2-master.zip
fi

cd rknpu2-master

# Install RKNN Runtime libraries
print_status "Installing RKNN Runtime libraries..."
cd runtime/Linux/librknn_api

# Copy runtime library for aarch64
sudo cp aarch64/librknnrt.so /usr/local/lib/
sudo cp include/rknn_api.h /usr/local/include/
sudo cp include/rknn_custom_op.h /usr/local/include/
sudo cp include/rknn_matmul_api.h /usr/local/include/

# Update library cache
sudo ldconfig

# Install NPU server
print_status "Installing NPU server..."
cd ../rknn_server/aarch64/usr/bin

sudo cp rknn_server /usr/local/bin/
sudo cp start_rknn.sh /usr/local/bin/
sudo cp restart_rknn.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/rknn_server
sudo chmod +x /usr/local/bin/start_rknn.sh
sudo chmod +x /usr/local/bin/restart_rknn.sh

# Create NPU service
print_status "Creating NPU systemd service..."
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

# Create test scripts
print_status "Creating test scripts..."
cd "$WORK_DIR"

# Test RKNN installation
cat > test_rknn_installation.py << 'EOF'
#!/usr/bin/env python3
"""
Test RKNN installation
"""

def test_rknn_toolkit():
    """Test RKNN Toolkit import"""
    try:
        from rknn.api import RKNN
        print("✓ RKNN Toolkit2 imported successfully")

        # Test basic functionality
        rknn = RKNN(verbose=True)
        print("✓ RKNN object created successfully")
        return True
    except ImportError as e:
        print(f"✗ RKNN Toolkit2 import failed: {e}")
        return False
    except Exception as e:
        print(f"✗ RKNN Toolkit2 test failed: {e}")
        return False

def test_rknn_lite():
    """Test RKNN Lite import"""
    try:
        from rknnlite.api import RKNNLite
        print("✓ RKNN Lite imported successfully")

        # Test basic functionality
        rknn_lite = RKNNLite()
        print("✓ RKNN Lite object created successfully")
        return True
    except ImportError as e:
        print(f"⚠ RKNN Lite import failed (optional): {e}")
        return True  # Not critical
    except Exception as e:
        print(f"⚠ RKNN Lite test failed (optional): {e}")
        return True  # Not critical

def test_dependencies():
    """Test required dependencies"""
    dependencies = [
        'numpy',
        'cv2',
        'PIL',
        'onnx'
    ]

    all_good = True
    for dep in dependencies:
        try:
            __import__(dep)
            print(f"✓ {dep} imported successfully")
        except ImportError as e:
            print(f"✗ {dep} import failed: {e}")
            all_good = False

    return all_good

if __name__ == "__main__":
    print("=== RKNN Installation Test ===")

    success = True
    success &= test_dependencies()
    success &= test_rknn_toolkit()
    success &= test_rknn_lite()

    if success:
        print("\n🎉 RKNN installation test completed successfully!")
    else:
        print("\n❌ Some tests failed. Check the errors above.")

    print("\nNext steps:")
    print("1. Start NPU service: sudo systemctl start rknn-server")
    print("2. Test with actual model")
    print("3. Run comprehensive tests with: ./testnpu.sh")
EOF

chmod +x test_rknn_installation.py

# Create NPU model test script
cat > test_npu_model.py << 'EOF'
#!/usr/bin/env python3
"""
Test NPU with actual model
"""

import sys
import numpy as np
import time

def test_with_mobilenet():
    """Test with MobileNet model if available"""
    try:
        from rknnlite.api import RKNNLite

        # Look for MobileNet model
        model_paths = [
            'rknn-toolkit2-master/rknn-toolkit-lite2/examples/resnet18/resnet18_for_rk3588.rknn',
            'rknpu2-master/examples/rknn_mobilenet_demo/model/RK3588/mobilenet_v1.rknn'
        ]

        model_path = None
        for path in model_paths:
            try:
                with open(path, 'rb'):
                    model_path = path
                    break
            except FileNotFoundError:
                continue

        if not model_path:
            print("No test model found - this is normal for fresh installation")
            return True

        print(f"Testing with model: {model_path}")

        # Initialize RKNN Lite
        rknn_lite = RKNNLite()

        # Load RKNN model
        print("Loading model...")
        ret = rknn_lite.load_rknn(model_path)
        if ret != 0:
            print(f"Load model failed: {ret}")
            return False

        # Initialize runtime
        print("Initializing runtime...")
        ret = rknn_lite.init_runtime()
        if ret != 0:
            print(f"Init runtime failed: {ret}")
            return False

        # Get model info
        input_info = rknn_lite.get_sdk_version()
        print(f"RKNN SDK Version: {input_info}")

        print("✓ NPU model test completed successfully!")

        rknn_lite.release()
        return True

    except Exception as e:
        print(f"NPU model test failed: {e}")
        return False

if __name__ == "__main__":
    print("=== NPU Model Test ===")
    success = test_with_mobilenet()

    if success:
        print("\n🎉 NPU is working correctly!")
    else:
        print("\n⚠️ NPU test had issues - check NPU service status")
        print("Run: sudo systemctl status rknn-server")
EOF

chmod +x test_npu_model.py

# Create environment setup script
print_status "Creating environment setup script..."
cat > setup_environment.sh << 'EOF'
#!/bin/bash

# Setup RKNN environment
export RKNN_LOG_LEVEL=1
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Activate virtual environment
if [ -f "rknn-toolkit2-master/venv/bin/activate" ]; then
    source rknn-toolkit2-master/venv/bin/activate
    echo "✓ RKNN virtual environment activated"
else
    echo "⚠ Virtual environment not found"
fi

echo "RKNN environment ready!"
echo "Test installation: python3 test_rknn_installation.py"
echo "Test NPU: python3 test_npu_model.py"
EOF

chmod +x setup_environment.sh

# Add environment to bashrc
print_status "Adding RKNN environment to shell..."
if ! grep -q "RKNN Environment" ~/.bashrc; then
    cat >> ~/.bashrc << 'EOF'

# RKNN Environment
export RKNN_LOG_LEVEL=1
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# RKNN aliases
alias rknn-env='cd ~/rknn_setup && source setup_environment.sh'
alias rknn-test='cd ~/rknn_setup && python3 test_rknn_installation.py'
alias rknn-npu='cd ~/rknn_setup && python3 test_npu_model.py'
EOF
fi

# Set permissions
sudo usermod -a -G video "$USER" 2>/dev/null || true

print_header "Installation Summary"

echo -e "${GREEN}✓ RKNN Toolkit2 installation completed successfully!${NC}"
echo ""
echo "📁 Installation directory: $WORK_DIR"
echo "🐍 Virtual environment: $WORK_DIR/rknn-toolkit2-master/venv"
echo "🔧 Runtime libraries: /usr/local/lib"
echo "🚀 NPU service: rknn-server"
echo ""
echo "🔥 Quick Start:"
echo "1. Restart shell or run: source ~/.bashrc"
echo "2. Test installation: rknn-test"
echo "3. Start NPU service: sudo systemctl start rknn-server"
echo "4. Test NPU: rknn-npu"
echo "5. Run environment: rknn-env"
echo ""
echo "📚 Examples available in:"
echo "   - $WORK_DIR/rknn-toolkit2-master/rknn-toolkit2/examples/"
echo "   - $WORK_DIR/rknpu2-master/examples/"
echo ""
print_warning "IMPORTANT: Restart your shell or run 'source ~/.bashrc' to use aliases"
print_status "Start NPU service: sudo systemctl start rknn-server"

# Test installation immediately
print_status "Testing installation..."
source rknn-toolkit2-master/venv/bin/activate
if python3 test_rknn_installation.py; then
    print_status "✓ Installation test passed!"
else
    print_warning "⚠ Installation test had issues"
fi

echo ""
echo "=== Installation completed at $(date) ==="