#!/bin/bash

# Mali-G610 GPU Setup Script for RK3588 on Armbian
# Radxa ROCK 5B+ GPU Configuration

set -e

echo "=== Mali-G610 GPU Setup for RK3588 ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if RK3588
CPU_INFO=$(cat /proc/cpuinfo | grep "Hardware" | head -1)
if ! echo "$CPU_INFO" | grep -q "Rockchip"; then
    print_warning "This doesn't appear to be a Rockchip device"
fi

print_status "Starting Mali-G610 GPU setup..."

# Update system
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
print_status "Installing development tools and dependencies..."
sudo apt install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    pkg-config \
    libdrm-dev \
    libx11-dev \
    libxext-dev \
    libxfixes-dev \
    libxi-dev \
    libxrandr-dev \
    libudev-dev \
    libmtdev-dev \
    libxkbcommon-dev \
    libfontconfig1-dev \
    libcairo2-dev \
    libgtk2.0-dev \
    libpango1.0-dev \
    libglib2.0-dev \
    libgdk-pixbuf2.0-dev \
    libglu1-mesa-dev \
    libgles2-mesa-dev \
    libegl1-mesa-dev \
    ocl-icd-opencl-dev \
    clinfo

# Create working directory
WORK_DIR="$HOME/mali_setup"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Download Mali GPU drivers
print_status "Downloading Mali-G610 drivers..."
MALI_VERSION="r44p0-01eac0"
MALI_URL="https://developer.arm.com/downloads/-/mali-drivers/valhall-kernel"

# Note: You may need to download manually from ARM developer site
print_warning "Mali drivers require manual download from ARM Developer site"
print_warning "Please download Mali-G610 drivers and place in: $WORK_DIR"

# Check for kernel modules
print_status "Checking for Mali kernel modules..."
if lsmod | grep -q "mali"; then
    print_status "Mali kernel module is loaded"
else
    print_warning "Mali kernel module not found"
    print_status "Attempting to load Mali module..."

    # Try to load mali module
    if sudo modprobe mali 2>/dev/null; then
        print_status "Mali module loaded successfully"
    else
        print_warning "Could not load Mali module - may need kernel recompilation"
    fi
fi

# Setup OpenCL
print_status "Setting up OpenCL..."

# Create OpenCL ICD directory
sudo mkdir -p /etc/OpenCL/vendors

# Check for OpenCL devices
print_status "Checking OpenCL devices..."
if command -v clinfo &> /dev/null; then
    clinfo || print_warning "No OpenCL devices found yet"
else
    print_warning "clinfo not available"
fi

# Setup GPU memory and performance
print_status "Configuring GPU settings..."

# Create GPU configuration
sudo tee /etc/modprobe.d/mali.conf > /dev/null << EOF
# Mali GPU Configuration for RK3588
options mali mali_debug_level=2
options mali mali_shared_mem_size=1024M
EOF

# Setup udev rules for GPU access
sudo tee /etc/udev/rules.d/99-mali.rules > /dev/null << EOF
# Mali GPU udev rules
KERNEL=="mali[0-9]*", GROUP="video", MODE="0660"
KERNEL=="renderD*", GROUP="render", MODE="0666"
EOF

# Add user to video and render groups
print_status "Adding user to video and render groups..."
sudo usermod -a -G video,render "$USER"

# Create test OpenCL program
print_status "Creating OpenCL test program..."
cat > opencl_test.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <CL/cl.h>

int main() {
    cl_uint num_platforms;
    cl_platform_id *platforms;
    cl_uint num_devices;
    cl_device_id *devices;
    char buffer[1024];

    // Get platforms
    clGetPlatformIDs(0, NULL, &num_platforms);
    printf("Number of OpenCL platforms: %u\n", num_platforms);

    if (num_platforms == 0) {
        printf("No OpenCL platforms found!\n");
        return 1;
    }

    platforms = malloc(sizeof(cl_platform_id) * num_platforms);
    clGetPlatformIDs(num_platforms, platforms, NULL);

    for (int i = 0; i < num_platforms; i++) {
        clGetPlatformInfo(platforms[i], CL_PLATFORM_NAME, sizeof(buffer), buffer, NULL);
        printf("Platform %d: %s\n", i, buffer);

        // Get devices for this platform
        clGetDeviceIDs(platforms[i], CL_DEVICE_TYPE_ALL, 0, NULL, &num_devices);
        printf("  Number of devices: %u\n", num_devices);

        if (num_devices > 0) {
            devices = malloc(sizeof(cl_device_id) * num_devices);
            clGetDeviceIDs(platforms[i], CL_DEVICE_TYPE_ALL, num_devices, devices, NULL);

            for (int j = 0; j < num_devices; j++) {
                clGetDeviceInfo(devices[j], CL_DEVICE_NAME, sizeof(buffer), buffer, NULL);
                printf("    Device %d: %s\n", j, buffer);
            }
            free(devices);
        }
    }

    free(platforms);
    return 0;
}
EOF

# Compile test program
print_status "Compiling OpenCL test..."
if gcc -o opencl_test opencl_test.c -lOpenCL 2>/dev/null; then
    print_status "OpenCL test compiled successfully"
    print_status "Run './opencl_test' to test OpenCL functionality"
else
    print_warning "Could not compile OpenCL test"
fi

# Create performance tuning script
print_status "Creating GPU performance tuning script..."
cat > gpu_performance.sh << 'EOF'
#!/bin/bash

# Mali-G610 Performance Tuning Script

# Set GPU governor to performance
echo performance | sudo tee /sys/class/devfreq/fb000000.gpu/governor

# Set GPU frequency (adjust as needed)
echo 1000000000 | sudo tee /sys/class/devfreq/fb000000.gpu/max_freq
echo 400000000 | sudo tee /sys/class/devfreq/fb000000.gpu/min_freq

# Display current GPU status
echo "GPU Status:"
echo "Governor: $(cat /sys/class/devfreq/fb000000.gpu/governor)"
echo "Current Freq: $(cat /sys/class/devfreq/fb000000.gpu/cur_freq)"
echo "Max Freq: $(cat /sys/class/devfreq/fb000000.gpu/max_freq)"
echo "Min Freq: $(cat /sys/class/devfreq/fb000000.gpu/min_freq)"
EOF

chmod +x gpu_performance.sh

# Create startup service for GPU optimization
print_status "Creating GPU optimization service..."
sudo tee /etc/systemd/system/mali-gpu-opt.service > /dev/null << EOF
[Unit]
Description=Mali GPU Optimization
After=multi-user.target

[Service]
Type=oneshot
ExecStart=$WORK_DIR/gpu_performance.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mali-gpu-opt.service

print_status "Mali-G610 GPU setup completed!"
echo ""
print_warning "IMPORTANT: Please reboot your system to apply all changes"
echo ""
print_status "After reboot, test with:"
echo "  - clinfo (check OpenCL devices)"
echo "  - ./opencl_test (run OpenCL test)"
echo "  - ./gpu_performance.sh (optimize GPU performance)"
echo ""
print_status "GPU setup files are in: $WORK_DIR"