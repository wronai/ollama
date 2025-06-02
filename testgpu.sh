#!/bin/bash

# GPU Permission and Groups Fix Script for RK3588
# Comprehensive fix for GPU access permissions and user groups

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

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   print_info "Run as regular user - script will use sudo when needed"
   exit 1
fi

print_header "GPU Permission and Groups Fix Script"

echo "System: $(uname -a)"
echo "Current user: $(whoami)"
echo "Date: $(date)"

# All GPU-related groups to add user to
GPU_GROUPS=(
    "video"      # Primary GPU access group
    "render"     # DRM render nodes access
    "audio"      # Sometimes needed for multimedia acceleration
    "input"      # Input devices (for some GPU applications)
    "dialout"    # Serial devices (sometimes used by GPU tools)
    "plugdev"    # Pluggable devices
    "users"      # General users group
)

# Check current user groups
print_header "Current User Groups Analysis"

echo "Current groups for user $(whoami):"
current_groups=$(groups)
echo "$current_groups"

# Check which groups are missing
missing_groups=()
for group in "${GPU_GROUPS[@]}"; do
    if echo "$current_groups" | grep -q "\b$group\b"; then
        print_success "User is in group: $group"
    else
        print_warning "User is NOT in group: $group"
        missing_groups+=("$group")
    fi
done

# Check GPU device permissions
print_header "GPU Device Permissions Analysis"

echo "GPU device files:"
if ls /dev/mali* >/dev/null 2>&1; then
    ls -la /dev/mali*
    for device in /dev/mali*; do
        if [ -r "$device" ] && [ -w "$device" ]; then
            print_success "Can read/write: $device"
        else
            print_warning "Cannot access: $device"
        fi
    done
else
    print_error "No Mali devices found"
fi

echo -e "\nDRM device files:"
if ls /dev/dri/* >/dev/null 2>&1; then
    ls -la /dev/dri/*
    for device in /dev/dri/renderD*; do
        if [ -r "$device" ] && [ -w "$device" ]; then
            print_success "Can read/write: $device"
        else
            print_warning "Cannot access: $device"
        fi
    done
else
    print_error "No DRM devices found"
fi

# Check if groups exist on system
print_header "System Groups Verification"

for group in "${GPU_GROUPS[@]}"; do
    if getent group "$group" >/dev/null 2>&1; then
        print_success "Group exists: $group"
    else
        print_warning "Group does not exist: $group"
    fi
done

# Install required packages
print_header "Installing Required Packages"

print_info "Updating package list..."
sudo apt update

packages_to_install=(
    "mesa-utils"
    "mesa-utils-extra"
    "libegl1-mesa-dev"
    "libgles2-mesa-dev"
    "libdrm-dev"
    "libgbm-dev"
    "libwayland-egl1-mesa"
    "clinfo"
    "vulkan-tools"
    "libvulkan1"
)

print_info "Installing graphics packages..."
for package in "${packages_to_install[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
        print_success "Already installed: $package"
    else
        print_info "Installing: $package"
        sudo apt install -y "$package" || print_warning "Failed to install: $package"
    fi
done

# Add user to groups
print_header "Adding User to Required Groups"

if [ ${#missing_groups[@]} -gt 0 ]; then
    print_info "Adding user $(whoami) to missing groups..."

    # Build usermod command
    groups_string=$(IFS=,; echo "${missing_groups[*]}")

    print_info "Adding to groups: $groups_string"
    sudo usermod -a -G "$groups_string" "$(whoami)"

    print_success "User added to groups: $groups_string"
else
    print_success "User is already in all required groups"
fi

# Fix device permissions
print_header "Fixing Device Permissions"

# Fix Mali devices
if ls /dev/mali* >/dev/null 2>&1; then
    for device in /dev/mali*; do
        print_info "Setting permissions for: $device"
        sudo chmod 666 "$device"
        sudo chown root:video "$device"
        print_success "Fixed permissions: $device"
    done
else
    print_warning "No Mali devices to fix"
fi

# Fix DRM devices
if ls /dev/dri/* >/dev/null 2>&1; then
    for device in /dev/dri/renderD*; do
        print_info "Setting permissions for: $device"
        sudo chmod 666 "$device"
        sudo chown root:render "$device"
        print_success "Fixed permissions: $device"
    done

    for device in /dev/dri/card*; do
        print_info "Setting permissions for: $device"
        sudo chmod 666 "$device"
        sudo chown root:video "$device"
        print_success "Fixed permissions: $device"
    done
else
    print_warning "No DRM devices to fix"
fi

# Create udev rules for persistent permissions
print_header "Creating Persistent udev Rules"

print_info "Creating udev rules for GPU devices..."

sudo tee /etc/udev/rules.d/99-gpu-permissions.rules > /dev/null << 'EOF'
# GPU device permissions for RK3588 Mali-G610
# Mali GPU devices
KERNEL=="mali[0-9]*", GROUP="video", MODE="0666"

# DRM devices
KERNEL=="card[0-9]*", GROUP="video", MODE="0666"
KERNEL=="renderD[0-9]*", GROUP="render", MODE="0666"
KERNEL=="controlD[0-9]*", GROUP="video", MODE="0666"

# NPU devices (if present)
KERNEL=="rknpu[0-9]*", GROUP="video", MODE="0666"

# General GPU-related devices
SUBSYSTEM=="drm", GROUP="video", MODE="0666"
SUBSYSTEM=="gpu", GROUP="video", MODE="0666"
EOF

print_success "Created udev rules: /etc/udev/rules.d/99-gpu-permissions.rules"

# Reload udev rules
print_info "Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger
print_success "udev rules reloaded"

# Set environment variables
print_header "Setting Environment Variables"

# Create GPU environment file
env_file="$HOME/.gpu_environment"
cat > "$env_file" << 'EOF'
# GPU Environment Variables for RK3588 Mali-G610
export MESA_LOADER_DRIVER_OVERRIDE=panfrost
export MESA_GL_VERSION_OVERRIDE=3.3
export MESA_GLSL_VERSION_OVERRIDE=330
export EGL_PLATFORM=drm
export GBM_BACKEND=panfrost
export LIBGL_DRIVERS_PATH=/usr/lib/aarch64-linux-gnu/dri
export LIBGL_ALWAYS_SOFTWARE=0
export GALLIUM_DRIVER=panfrost
EOF

print_success "Created GPU environment file: $env_file"

# Add to shell profiles
for profile in ~/.bashrc ~/.profile ~/.zshrc; do
    if [ -f "$profile" ]; then
        if ! grep -q "gpu_environment" "$profile"; then
            echo "" >> "$profile"
            echo "# GPU Environment Variables" >> "$profile"
            echo "if [ -f ~/.gpu_environment ]; then" >> "$profile"
            echo "    source ~/.gpu_environment" >> "$profile"
            echo "fi" >> "$profile"
            print_success "Added GPU environment to: $profile"
        else
            print_info "GPU environment already in: $profile"
        fi
    fi
done

# Create GPU optimization script
print_header "Creating GPU Optimization Script"

cat > "$HOME/gpu_optimize.sh" << 'EOF'
#!/bin/bash

# GPU Optimization Script for RK3588 Mali-G610

echo "=== GPU Optimization ==="

# Set GPU governor to performance
if [ -w "/sys/class/devfreq/fb000000.gpu/governor" ]; then
    echo performance | sudo tee /sys/class/devfreq/fb000000.gpu/governor
    echo "✓ Set GPU governor to performance"
else
    echo "⚠ Cannot access GPU governor"
fi

# Set GPU frequencies
if [ -w "/sys/class/devfreq/fb000000.gpu/min_freq" ]; then
    echo 400000000 | sudo tee /sys/class/devfreq/fb000000.gpu/min_freq
    echo 1000000000 | sudo tee /sys/class/devfreq/fb000000.gpu/max_freq
    echo "✓ Set GPU frequency range: 400-1000 MHz"
else
    echo "⚠ Cannot access GPU frequency controls"
fi

# Show current GPU status
echo -e "\nCurrent GPU Status:"
if [ -r "/sys/class/devfreq/fb000000.gpu/cur_freq" ]; then
    echo "Frequency: $(($(cat /sys/class/devfreq/fb000000.gpu/cur_freq) / 1000000)) MHz"
    echo "Governor: $(cat /sys/class/devfreq/fb000000.gpu/governor)"
fi

echo "✓ GPU optimization completed"
EOF

chmod +x "$HOME/gpu_optimize.sh"
print_success "Created GPU optimization script: $HOME/gpu_optimize.sh"

# Test GPU access
print_header "Testing GPU Access"

# Source the new environment
source "$env_file"

# Test basic GPU commands
print_info "Testing basic GPU functionality..."

if command -v glxinfo >/dev/null 2>&1; then
    if glxinfo >/dev/null 2>&1; then
        print_success "glxinfo works"
        echo "OpenGL Renderer: $(glxinfo | grep "OpenGL renderer" | cut -d: -f2 | xargs)"
    else
        print_warning "glxinfo failed"
    fi
else
    print_warning "glxinfo not available"
fi

if command -v clinfo >/dev/null 2>&1; then
    if clinfo >/dev/null 2>&1; then
        print_success "clinfo works"
        echo "OpenCL Platforms: $(clinfo | grep -c "Platform #" || echo "0")"
    else
        print_warning "clinfo failed"
    fi
else
    print_warning "clinfo not available"
fi

# Summary
print_header "Summary and Next Steps"

print_success "GPU permission and groups fix completed!"

echo -e "\nChanges made:"
echo "• Added user to groups: ${missing_groups[*]:-none needed}"
echo "• Fixed device permissions for Mali and DRM devices"
echo "• Created persistent udev rules"
echo "• Set GPU environment variables"
echo "• Created GPU optimization script"

print_warning "IMPORTANT: To apply group changes, you must:"
echo "1. Logout and login again, OR"
echo "2. Restart your system, OR"
echo "3. Run: newgrp video && newgrp render"

print_info "After relogin/restart:"
echo "1. Source GPU environment: source ~/.gpu_environment"
echo "2. Optimize GPU: ./gpu_optimize.sh"
echo "3. Test GPU: ./testgpu_fixed.sh"

print_info "Useful commands:"
echo "• Check GPU status: cat /sys/class/devfreq/fb000000.gpu/cur_freq"
echo "• Test OpenGL: glxinfo | grep OpenGL"
echo "• Test OpenCL: clinfo"
echo "• Verify groups: groups"

echo -e "\nGPU setup completed at $(date)"
print_success "Ready to test GPU functionality!"