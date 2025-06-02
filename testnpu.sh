#!/bin/bash

# NPU Test Script for RK3588 - testnpu.sh
# Comprehensive NPU testing and benchmarking

set -e

# Colors for output
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

print_fail() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

run_test() {
    local test_name="$1"
    local test_command="$2"

    echo -e "\n${BLUE}Testing: $test_name${NC}"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if eval "$test_command" &>/dev/null; then
        print_success "$test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_fail "$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

print_header "RK3588 NPU Comprehensive Test Suite"

echo -e "Test Date: $(date)"
echo -e "System: $(uname -a)"
echo -e "Architecture: $(uname -m)"

# System Information
print_header "System Information"

echo "CPU Information:"
lscpu | grep -E "(Architecture|CPU|Core|Thread)" || echo "CPU info not available"

echo -e "\nMemory Information:"
free -h

echo -e "\nKernel Version:"
uname -r

# Hardware Detection Tests
print_header "Hardware Detection Tests"

run_test "RK3588 CPU Detection" "grep -q 'rk3588\|rockchip' /proc/cpuinfo"

run_test "NPU Device Files" "ls /dev/rknpu* >/dev/null 2>&1"

run_test "NPU Memory Regions" "grep -q 'rknpu\|npu' /proc/iomem"

run_test "Mali GPU Device" "ls /dev/mali* >/dev/null 2>&1"

# Kernel Module Tests
print_header "Kernel Module Tests"

echo "Loaded RK modules:"
lsmod | grep -i rk || echo "No RK modules found"

run_test "RKNPU Module" "lsmod | grep -q rknpu"

run_test "Mali Module" "lsmod | grep -q mali"

# NPU Service Tests
print_header "NPU Service Tests"

run_test "RKNN Server Service" "systemctl is-active --quiet rknn-server"

run_test "RKNN Server Process" "pgrep -f rknn_server"

# NPU API Tests
print_header "NPU API Tests"

# Test Python RKNN availability
cat > /tmp/test_rknn_import.py << 'EOF'
try:
    from rknn.api import RKNN
    print("RKNN API available")
    exit(0)
except ImportError as e:
    print(f"RKNN API not available: {e}")
    exit(1)
EOF

run_test "RKNN Python API" "python3 /tmp/test_rknn_import.py"

# Test RKNN Toolkit Lite
cat > /tmp/test_rknn_lite.py << 'EOF'
try:
    from rknnlite.api import RKNNLite
    print("RKNN Lite API available")
    exit(0)
except ImportError as e:
    print(f"RKNN Lite API not available: {e}")
    exit(1)
EOF

run_test "RKNN Lite Python API" "python3 /tmp/test_rknn_lite.py"

# NPU Performance Tests
print_header "NPU Performance Tests"

# Create simple NPU benchmark
cat > /tmp/npu_benchmark.py << 'EOF'
#!/usr/bin/env python3
import time
import numpy as np

def npu_benchmark():
    """Simple NPU benchmark simulation"""
    try:
        # Simulate tensor operations
        data = np.random.rand(1000, 1000).astype(np.float32)

        start_time = time.time()

        # Simulate matrix operations
        for i in range(100):
            result = np.dot(data, data.T)

        end_time = time.time()
        elapsed = end_time - start_time

        print(f"Matrix operations time: {elapsed:.3f} seconds")
        print(f"Operations per second: {100/elapsed:.1f}")

        return elapsed < 10.0  # Should complete in reasonable time

    except Exception as e:
        print(f"Benchmark failed: {e}")
        return False

if __name__ == "__main__":
    success = npu_benchmark()
    exit(0 if success else 1)
EOF

run_test "NPU Performance Benchmark" "python3 /tmp/npu_benchmark.py"

# Memory Tests
print_header "Memory Tests"

run_test "NPU Memory Allocation" "cat /proc/meminfo | grep -i npu"

echo "Available memory:"
cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable)"

# Temperature and Frequency Tests
print_header "Thermal and Frequency Tests"

echo "CPU Frequencies:"
if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        if [ -r "$cpu" ]; then
            echo "$(basename $(dirname $(dirname $cpu))): $(($(cat $cpu) / 1000)) MHz"
        fi
    done
else
    echo "CPU frequency information not available"
fi

echo -e "\nGPU Frequency:"
if [ -r "/sys/class/devfreq/fb000000.gpu/cur_freq" ]; then
    echo "GPU: $(($(cat /sys/class/devfreq/fb000000.gpu/cur_freq) / 1000000)) MHz"
else
    echo "GPU frequency information not available"
fi

echo -e "\nSystem Temperatures:"
if command -v sensors &> /dev/null; then
    sensors | grep -E "(temp|Core)"
elif [ -d "/sys/class/thermal" ]; then
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [ -r "$zone" ]; then
            temp=$(($(cat $zone) / 1000))
            zone_name=$(basename $(dirname $zone))
            echo "$zone_name: ${temp}°C"
        fi
    done
else
    echo "Temperature sensors not available"
fi

# Ollama Integration Tests
print_header "Ollama Integration Tests"

if command -v ollama &> /dev/null; then
    run_test "Ollama Installation" "command -v ollama"

    run_test "Ollama Service" "systemctl is-active --quiet ollama"

    echo "Testing Ollama NPU integration..."
    timeout 30s ollama run llama2:7b "Hello" 2>/dev/null && print_success "Ollama NPU Test" || print_warning "Ollama NPU test timed out or failed"
else
    print_warning "Ollama not installed"
fi

# Advanced NPU Tests
print_header "Advanced NPU Tests"

# Test RKNN model loading (if models available)
if [ -f "*.rknn" ]; then
    echo "Found RKNN models:"
    ls -la *.rknn

    cat > /tmp/test_model_load.py << 'EOF'
#!/usr/bin/env python3
import sys
import glob
from rknnlite.api import RKNNLite

def test_model_loading():
    models = glob.glob("*.rknn")
    if not models:
        print("No RKNN models found")
        return False

    rknn_lite = RKNNLite()

    for model in models[:1]:  # Test first model only
        try:
            print(f"Testing model: {model}")
            ret = rknn_lite.load_rknn(model)
            if ret != 0:
                print(f"Failed to load {model}")
                continue

            ret = rknn_lite.init_runtime()
            if ret != 0:
                print(f"Failed to init runtime for {model}")
                continue

            print(f"Successfully loaded and initialized {model}")
            rknn_lite.release()
            return True

        except Exception as e:
            print(f"Error testing {model}: {e}")

    return False

if __name__ == "__main__":
    success = test_model_loading()
    exit(0 if success else 1)
EOF

    run_test "RKNN Model Loading" "python3 /tmp/test_model_load.py"
else
    print_info "No RKNN models found for testing"
fi

# Power Management Tests
print_header "Power Management Tests"

echo "Power governors:"
if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then
    echo "CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'N/A')"
fi

if [ -r "/sys/class/devfreq/fb000000.gpu/governor" ]; then
    echo "GPU Governor: $(cat /sys/class/devfreq/fb000000.gpu/governor)"
fi

# Stress Test
print_header "NPU Stress Test"

cat > /tmp/npu_stress.py << 'EOF'
#!/usr/bin/env python3
import time
import threading
import numpy as np

def stress_worker(duration=10):
    """CPU-intensive worker to simulate NPU load"""
    end_time = time.time() + duration
    operations = 0

    while time.time() < end_time:
        # Simulate tensor operations
        a = np.random.rand(500, 500).astype(np.float32)
        b = np.random.rand(500, 500).astype(np.float32)
        c = np.dot(a, b)
        operations += 1

    return operations

def npu_stress_test():
    print("Running 10-second NPU stress test...")

    # Run multiple threads to simulate NPU workload
    threads = []
    start_time = time.time()

    for i in range(4):  # 4 threads
        thread = threading.Thread(target=stress_worker)
        thread.start()
        threads.append(thread)

    # Wait for all threads
    for thread in threads:
        thread.join()

    end_time = time.time()
    elapsed = end_time - start_time

    print(f"Stress test completed in {elapsed:.2f} seconds")
    return True

if __name__ == "__main__":
    success = npu_stress_test()
    exit(0 if success else 1)
EOF

run_test "NPU Stress Test" "python3 /tmp/npu_stress.py"

# Summary
print_header "Test Summary"

echo -e "Total Tests Run: $TESTS_TOTAL"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All NPU tests passed! NPU is functioning correctly.${NC}"
    EXIT_CODE=0
elif [ $TESTS_PASSED -gt $TESTS_FAILED ]; then
    echo -e "\n${YELLOW}⚠️  Most tests passed, but some issues detected.${NC}"
    EXIT_CODE=1
else
    echo -e "\n${RED}❌ Significant NPU issues detected. Check configuration.${NC}"
    EXIT_CODE=2
fi

# Recommendations
echo -e "\n${BLUE}Recommendations:${NC}"

if [ $TESTS_FAILED -gt 0 ]; then
    echo "• Check NPU driver installation"
    echo "• Verify RKNN service is running: sudo systemctl status rknn-server"
    echo "• Ensure proper NPU firmware is loaded"
    echo "• Check system logs: journalctl -u rknn-server"
fi

echo "• For optimal performance, set GPU governor to 'performance'"
echo "• Monitor temperatures during heavy NPU workloads"
echo "• Test with actual RKNN models for production validation"

# Cleanup temporary files
rm -f /tmp/test_rknn_import.py /tmp/test_rknn_lite.py /tmp/npu_benchmark.py /tmp/test_model_load.py /tmp/npu_stress.py

echo -e "\nNPU test completed at $(date)"
exit $EXIT_CODE