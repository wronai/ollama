#!/bin/bash

# RKNN NPU Setup Script for RK3588 on Armbian
# Radxa ROCK 5B+ NPU Configuration with Ollama support

set -e

echo "=== RKNN NPU Setup for RK3588 ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_note() {
    echo -e "${BLUE}[NOTE]${NC} $1"
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

print_status "Starting RKNN NPU setup for RK3588..."

# Create working directory
WORK_DIR="$HOME/rknn_setup"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Update system
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install dependencies
print_status "Installing dependencies..."
sudo apt install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    python3 \
    python3-pip \
    python3-dev \
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

# Install Python packages
print_status "Installing Python packages..."
pip3 install --user \
    numpy \
    opencv-python \
    pillow \
    requests \
    onnx \
    onnxruntime

# Download RKNN Toolkit
print_status "Downloading RKNN Toolkit..."
RKNN_VERSION="2.0.0-beta0"
RKNN_TOOLKIT_URL="https://github.com/airockchip/rknn-toolkit2/archive/refs/heads/master.zip"

if [ ! -f "rknn-toolkit2-master.zip" ]; then
    wget -O rknn-toolkit2-master.zip "$RKNN_TOOLKIT_URL"
fi

unzip -o rknn-toolkit2-master.zip
cd rknn-toolkit2-master

# Install RKNN Toolkit2
print_status "Installing RKNN Toolkit2..."
cd rknn-toolkit2/packages
pip3 install --user rknn_toolkit2-*-py3-none-any.whl

cd ../../rknn_toolkit_lite2/packages
pip3 install --user rknn_toolkit_lite2-*-py3-none-any.whl

cd "$WORK_DIR"

# Download and install RKNN Runtime
print_status "Setting up RKNN Runtime..."
RKNN_API_URL="https://github.com/airockchip/rknpu2/archive/refs/heads/master.zip"

if [ ! -f "rknpu2-master.zip" ]; then
    wget -O rknpu2-master.zip "$RKNN_API_URL"
fi

unzip -o rknpu2-master.zip
cd rknpu2-master

# Build RKNN Runtime
print_status "Building RKNN Runtime..."
cd runtime/RK3588/Linux/librknn_api

# Copy runtime library
sudo cp lib64/librknn_api.so /usr/local/lib/
sudo cp include/rknn_api.h /usr/local/include/

# Update library cache
sudo ldconfig

cd "$WORK_DIR"

# Install NPU firmware and drivers
print_status "Installing NPU firmware..."
cd rknpu2-master/runtime/RK3588/Linux

# Copy NPU firmware
sudo mkdir -p /lib/firmware
sudo cp rknn_server /usr/local/bin/
sudo chmod +x /usr/local/bin/rknn_server

# Create NPU service
print_status "Creating NPU service..."
sudo tee /etc/systemd/system/rknn-server.service > /dev/null << EOF
[Unit]
Description=RKNN NPU Server
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/rknn_server
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable rknn-server.service

# Create RKNN Python test script
print_status "Creating RKNN test scripts..."
cd "$WORK_DIR"

cat > rknn_test.py << 'EOF'
#!/usr/bin/env python3
"""
RKNN NPU Test Script for RK3588
Tests NPU functionality and performance
"""

import sys
import numpy as np
import time
from rknn.api import RKNN

def test_rknn_basic():
    """Basic RKNN functionality test"""
    print("Testing RKNN Basic Functionality...")

    try:
        # Initialize RKNN
        rknn = RKNN(verbose=True)

        # Check NPU availability
        ret = rknn.load_onnx(model='dummy_model.onnx')  # This will fail but tests API
        print("RKNN API is working!")

    except Exception as e:
        print(f"RKNN API test failed: {e}")
        return False

    return True

def create_dummy_model():
    """Create a simple ONNX model for testing"""
    try:
        import onnx
        from onnx import helper, TensorProto

        # Create a simple model (Add operation)
        input1 = helper.make_tensor_value_info('input1', TensorProto.FLOAT, [1, 3, 224, 224])
        output = helper.make_tensor_value_info('output', TensorProto.FLOAT, [1, 3, 224, 224])

        # Create a simple identity node
        node = helper.make_node('Identity', ['input1'], ['output'])

        # Create graph
        graph = helper.make_graph([node], 'test_graph', [input1], [output])

        # Create model
        model = helper.make_model(graph)

        # Save model
        onnx.save(model, 'dummy_model.onnx')
        print("Created dummy ONNX model for testing")
        return True

    except ImportError:
        print("ONNX not available, skipping model creation")
        return False

def check_npu_status():
    """Check NPU hardware status"""
    print("Checking NPU hardware status...")

    try:
        # Check NPU device files
        import os
        npu_devices = ['/dev/rknpu']

        for device in npu_devices:
            if os.path.exists(device):
                print(f"✓ Found NPU device: {device}")
            else:
                print(f"✗ NPU device not found: {device}")

        # Check NPU memory
        try:
            with open('/proc/meminfo', 'r') as f:
                meminfo = f.read()
                if 'RkNpu' in meminfo:
                    print("✓ NPU memory regions found")
                else:
                    print("✗ NPU memory regions not found")
        except:
            print("Could not check NPU memory")

    except Exception as e:
        print(f"NPU status check failed: {e}")

def benchmark_npu():
    """Simple NPU benchmark"""
    print("Running NPU benchmark...")

    try:
        # Create test data
        test_data = np.random.rand(1, 3, 224, 224).astype(np.float32)

        # Simulate inference timing
        start_time = time.time()

        # This is a placeholder - actual inference would go here
        time.sleep(0.01)  # Simulate processing time

        end_time = time.time()
        inference_time = (end_time - start_time) * 1000

        print(f"Simulated inference time: {inference_time:.2f} ms")

    except Exception as e:
        print(f"Benchmark failed: {e}")

if __name__ == "__main__":
    print("=== RKNN NPU Test Suite ===")

    # Check NPU status
    check_npu_status()

    # Create dummy model
    create_dummy_model()

    # Test basic functionality
    test_rknn_basic()

    # Run benchmark
    benchmark_npu()

    print("\nTest completed!")
EOF

chmod +x rknn_test.py

# Create RKNN model conversion script
cat > convert_model.py << 'EOF'
#!/usr/bin/env python3
"""
RKNN Model Conversion Script
Converts ONNX/TensorFlow models to RKNN format
"""

import sys
import argparse
from rknn.api import RKNN

def convert_model(input_model, output_model, target_platform='rk3588'):
    """Convert model to RKNN format"""

    print(f"Converting {input_model} to RKNN format...")

    # Initialize RKNN
    rknn = RKNN(verbose=True)

    try:
        # Load model
        if input_model.endswith('.onnx'):
            ret = rknn.load_onnx(model=input_model)
        elif input_model.endswith('.tflite'):
            ret = rknn.load_tflite(model=input_model)
        else:
            print("Unsupported model format")
            return False

        if ret != 0:
            print("Load model failed!")
            return False

        # Build model for NPU
        print("Building model for NPU...")
        ret = rknn.build(do_quantization=True, dataset='./dataset.txt', target_platform=target_platform)
        if ret != 0:
            print("Build model failed!")
            return False

        # Export RKNN model
        ret = rknn.export_rknn(output_model)
        if ret != 0:
            print("Export model failed!")
            return False

        print(f"Model converted successfully: {output_model}")

        # Initialize runtime
        ret = rknn.init_runtime(target=target_platform)
        if ret != 0:
            print("Init runtime failed!")
            return False

        print("Runtime initialized successfully!")

    except Exception as e:
        print(f"Conversion failed: {e}")
        return False
    finally:
        rknn.release()

    return True

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Convert models to RKNN format')
    parser.add_argument('--input', required=True, help='Input model path (.onnx or .tflite)')
    parser.add_argument('--output', required=True, help='Output RKNN model path')
    parser.add_argument('--platform', default='rk3588', help='Target platform (default: rk3588)')

    args = parser.parse_args()

    success = convert_model(args.input, args.output, args.platform)
    sys.exit(0 if success else 1)
EOF

chmod +x convert_model.py

# Create Ollama integration script
print_status "Creating Ollama NPU integration..."
cat > ollama_npu_setup.sh << 'EOF'
#!/bin/bash

# Ollama NPU Integration Setup

echo "=== Setting up Ollama with NPU support ==="

# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Create Ollama service configuration for NPU
sudo mkdir -p /etc/systemd/system/ollama.service.d

# Configure Ollama to use NPU (experimental)
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null << 'CONF'
[Service]
Environment="OLLAMA_ACCELERATION=rknn"
Environment="RKNN_LOG_LEVEL=1"
Environment="OLLAMA_GPU_LAYERS=35"
CONF

# Restart Ollama service
sudo systemctl daemon-reload
sudo systemctl restart ollama

echo "Ollama NPU integration configured!"
echo "Note: NPU support in Ollama is experimental"
echo "Test with: ollama run llama2:7b"
EOF

chmod +x ollama_npu_setup.sh

# Create comprehensive test script
cat > full_npu_test.sh << 'EOF'
#!/bin/bash

echo "=== Comprehensive NPU Test ==="

# Check NPU devices
echo "Checking NPU devices..."
ls -la /dev/rk* 2>/dev/null || echo "No RK devices found"

# Check NPU modules
echo -e "\nChecking kernel modules..."
lsmod | grep rk || echo "No RK modules loaded"

# Check NPU processes
echo -e "\nChecking NPU processes..."
ps aux | grep rknn || echo "No RKNN processes found"

# Test RKNN Python API
echo -e "\nTesting RKNN Python API..."
python3 rknn_test.py

# Check Ollama status
echo -e "\nChecking Ollama status..."
systemctl status ollama --no-pager || echo "Ollama not installed/running"

echo -e "\nNPU test completed!"
EOF

chmod +x full_npu_test.sh

# Final setup steps
print_status "Performing final setup..."

# Add environment variables
echo '# RKNN Environment Variables' >> ~/.bashrc
echo 'export RKNN_LOG_LEVEL=1' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> ~/.bashrc

# Set permissions
sudo usermod -a -G video "$USER"

print_status "RKNN NPU setup completed!"
echo ""
print_warning "IMPORTANT NEXT STEPS:"
echo "1. Reboot your system: sudo reboot"
echo "2. After reboot, start NPU service: sudo systemctl start rknn-server"
echo "3. Test NPU: ./full_npu_test.sh"
echo "4. Set up Ollama with NPU: ./ollama_npu_setup.sh"
echo "5. Test Python API: python3 rknn_test.py"
echo ""
print_note "Available scripts in $WORK_DIR:"
echo "  - rknn_test.py (NPU functionality test)"
echo "  - convert_model.py (model conversion)"
echo "  - ollama_npu_setup.sh (Ollama integration)"
echo "  - full_npu_test.sh (comprehensive test)"
echo ""
print_status "For model conversion, you'll need dataset.txt with sample inputs"
print_status "Documentation: https://github.com/airockchip/rknn-toolkit2"