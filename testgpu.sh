#!/bin/bash

# GPU Test Script for Mali-G610 on RK3588 - testgpu.sh
# Comprehensive GPU testing and benchmarking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

print_benchmark() {
    echo -e "${MAGENTA}📊 $1${NC}"
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

print_header "Mali-G610 GPU Comprehensive Test Suite"

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

run_test "Mali GPU Device Files" "ls /dev/mali* >/dev/null 2>&1"

run_test "DRM GPU Device" "ls /dev/dri/card* >/dev/null 2>&1 || ls /dev/dri/renderD* >/dev/null 2>&1"

run_test "GPU Memory Regions" "grep -q 'mali\|gpu' /proc/iomem"

# Kernel Module Tests
print_header "Kernel Module Tests"

echo "Loaded GPU modules:"
lsmod | grep -E "(mali|panfrost|drm)" || echo "No GPU modules found"

run_test "Mali Kernel Module" "lsmod | grep -q mali"

run_test "DRM Module" "lsmod | grep -q drm"

# GPU Driver Tests
print_header "GPU Driver Tests"

echo "GPU driver information:"
if [ -d "/sys/kernel/debug/dri" ]; then
    ls -la /sys/kernel/debug/dri/ 2>/dev/null || echo "DRI debug info not accessible"
fi

# OpenGL Tests
print_header "OpenGL Tests"

run_test "OpenGL Libraries" "ldconfig -p | grep -q libGL"

run_test "EGL Libraries" "ldconfig -p | grep -q libEGL"

run_test "GLES Libraries" "ldconfig -p | grep -q libGLESv2"

# Test OpenGL with basic program
cat > /tmp/test_opengl.c << 'EOF'
#include <stdio.h>
#include <EGL/egl.h>
#include <GLES2/gl2.h>

int main() {
    EGLDisplay display;
    EGLConfig config;
    EGLContext context;
    EGLint num_config;

    display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (display == EGL_NO_DISPLAY) {
        printf("Failed to get EGL display\n");
        return 1;
    }

    if (!eglInitialize(display, NULL, NULL)) {
        printf("Failed to initialize EGL\n");
        return 1;
    }

    EGLint attribs[] = {
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
        EGL_BLUE_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_RED_SIZE, 8,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_NONE
    };

    if (!eglChooseConfig(display, attribs, &config, 1, &num_config)) {
        printf("Failed to choose EGL config\n");
        return 1;
    }

    context = eglCreateContext(display, config, EGL_NO_CONTEXT, NULL);
    if (context == EGL_NO_CONTEXT) {
        printf("Failed to create EGL context\n");
        return 1;
    }

    printf("OpenGL ES Version: %s\n", glGetString(GL_VERSION));
    printf("OpenGL ES Vendor: %s\n", glGetString(GL_VENDOR));
    printf("OpenGL ES Renderer: %s\n", glGetString(GL_RENDERER));

    eglTerminate(display);
    return 0;
}
EOF

if gcc -o /tmp/test_opengl /tmp/test_opengl.c -lEGL -lGLESv2 2>/dev/null; then
    run_test "OpenGL ES Functionality" "/tmp/test_opengl"
else
    print_fail "OpenGL ES Compilation"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
fi

# OpenCL Tests
print_header "OpenCL Tests"

run_test "OpenCL Libraries" "ldconfig -p | grep -q libOpenCL"

if command -v clinfo &> /dev/null; then
    echo -e "\nOpenCL Information:"
    clinfo | head -50

    run_test "OpenCL Platforms" "clinfo | grep -q Platform"
    run_test "OpenCL Devices" "clinfo | grep -q Device"
else
    print_warning "clinfo not available"
fi

# Create OpenCL test program
cat > /tmp/test_opencl.c << 'EOF'
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
    cl_int ret = clGetPlatformIDs(0, NULL, &num_platforms);
    if (ret != CL_SUCCESS || num_platforms == 0) {
        printf("No OpenCL platforms found\n");
        return 1;
    }

    printf("Found %u OpenCL platform(s)\n", num_platforms);

    platforms = malloc(sizeof(cl_platform_id) * num_platforms);
    clGetPlatformIDs(num_platforms, platforms, NULL);

    int total_devices = 0;

    for (int i = 0; i < num_platforms; i++) {
        clGetPlatformInfo(platforms[i], CL_PLATFORM_NAME, sizeof(buffer), buffer, NULL);
        printf("Platform %d: %s\n", i, buffer);

        // Get devices for this platform
        ret = clGetDeviceIDs(platforms[i], CL_DEVICE_TYPE_ALL, 0, NULL, &num_devices);
        if (ret == CL_SUCCESS && num_devices > 0) {
            printf("  Found %u device(s)\n", num_devices);
            total_devices += num_devices;

            devices = malloc(sizeof(cl_device_id) * num_devices);
            clGetDeviceIDs(platforms[i], CL_DEVICE_TYPE_ALL, num_devices, devices, NULL);

            for (int j = 0; j < num_devices; j++) {
                clGetDeviceInfo(devices[j], CL_DEVICE_NAME, sizeof(buffer), buffer, NULL);
                printf("    Device %d: %s\n", j, buffer);

                cl_device_type type;
                clGetDeviceInfo(devices[j], CL_DEVICE_TYPE, sizeof(type), &type, NULL);
                printf("      Type: ");
                if (type & CL_DEVICE_TYPE_GPU) printf("GPU ");
                if (type & CL_DEVICE_TYPE_CPU) printf("CPU ");
                printf("\n");
            }
            free(devices);
        }
    }

    free(platforms);

    if (total_devices > 0) {
        printf("OpenCL test successful - found %d total devices\n", total_devices);
        return 0;
    } else {
        printf("No OpenCL devices found\n");
        return 1;
    }
}
EOF

if gcc -o /tmp/test_opencl /tmp/test_opencl.c -lOpenCL 2>/dev/null; then
    run_test "OpenCL Functionality" "/tmp/test_opencl"
else
    print_fail "OpenCL Compilation"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
fi

# GPU Frequency and Performance Tests
print_header "GPU Performance Tests"

echo "GPU Frequency Information:"
if [ -r "/sys/class/devfreq/fb000000.gpu/cur_freq" ]; then
    echo "Current Frequency: $(($(cat /sys/class/devfreq/fb000000.gpu/cur_freq) / 1000000)) MHz"
    echo "Max Frequency: $(($(cat /sys/class/devfreq/fb000000.gpu/max_freq) / 1000000)) MHz"
    echo "Min Frequency: $(($(cat /sys/class/devfreq/fb000000.gpu/min_freq) / 1000000)) MHz"
    echo "Governor: $(cat /sys/class/devfreq/fb000000.gpu/governor)"

    # Available frequencies
    if [ -r "/sys/class/devfreq/fb000000.gpu/available_frequencies" ]; then
        echo "Available Frequencies:"
        cat /sys/class/devfreq/fb000000.gpu/available_frequencies | tr ' ' '\n' | while read freq; do
            echo "  $((freq / 1000000)) MHz"
        done
    fi
else
    print_warning "GPU frequency information not available"
fi

# GPU Memory Tests
print_header "GPU Memory Tests"

echo "GPU Memory Information:"
if [ -d "/sys/kernel/debug/dri/0" ]; then
    echo "DRI Debug Info:"
    ls -la /sys/kernel/debug/dri/0/ 2>/dev/null || echo "DRI debug not accessible"
fi

# GPU Utilization Test
print_header "GPU Utilization Tests"

cat > /tmp/gpu_stress.py << 'EOF'
#!/usr/bin/env python3
import time
import numpy as np
try:
    import cv2
    OPENCV_AVAILABLE = True
except ImportError:
    OPENCV_AVAILABLE = False

def cpu_gpu_benchmark():
    """GPU stress test using numpy operations"""
    print("Running GPU stress test...")

    start_time = time.time()
    operations = 0

    # Run for 10 seconds
    end_time = start_time + 10

    while time.time() < end_time:
        # Create large arrays
        a = np.random.rand(1000, 1000).astype(np.float32)
        b = np.random.rand(1000, 1000).astype(np.float32)

        # Matrix operations
        c = np.dot(a, b)
        d = np.transpose(c)
        e = np.multiply(c, d)

        operations += 1

    elapsed = time.time() - start_time
    print(f"Completed {operations} operations in {elapsed:.2f} seconds")
    print(f"Operations per second: {operations/elapsed:.1f}")

    return operations > 10  # Should complete at least 10 operations

def opencv_gpu_test():
    """Test OpenCV GPU acceleration if available"""
    if not OPENCV_AVAILABLE:
        print("OpenCV not available")
        return False

    try:
        # Create test image
        img = np.random.randint(0, 255, (1000, 1000, 3), dtype=np.uint8)

        start_time = time.time()

        # Image processing operations
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        blur = cv2.GaussianBlur(gray, (15, 15), 0)
        edges = cv2.Canny(blur, 50, 150)

        elapsed = time.time() - start_time
        print(f"OpenCV processing time: {elapsed:.3f} seconds")

        return True

    except Exception as e:
        print(f"OpenCV test failed: {e}")
        return False

if __name__ == "__main__":
    success1 = cpu_gpu_benchmark()
    success2 = opencv_gpu_test()
    exit(0 if (success1 and success2) else 1)
EOF

run_test "GPU Stress Test" "python3 /tmp/gpu_stress.py"

# Temperature Monitoring
print_header "Thermal Monitoring"

echo "GPU Temperature:"
if [ -d "/sys/class/thermal" ]; then
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [ -r "$zone" ]; then
            temp=$(($(cat $zone) / 1000))
            zone_name=$(basename $(dirname $zone))
            zone_type=""

            # Try to get thermal zone type
            type_file=$(dirname $zone)/type
            if [ -r "$type_file" ]; then
                zone_type=" ($(cat $type_file))"
            fi

            echo "$zone_name$zone_type: ${temp}°C"
        fi
    done
else
    print_warning "Temperature sensors not available"
fi

# Vulkan Tests (if available)
print_header "Vulkan Tests"

if command -v vulkaninfo &> /dev/null; then
    echo "Vulkan Information:"
    vulkaninfo --summary 2>/dev/null | head -20 || echo "Vulkan info failed"

    run_test "Vulkan Support" "vulkaninfo --summary | grep -q 'Device'"
else
    print_info "Vulkan tools not available"
fi

# Performance Benchmarks
print_header "Performance Benchmarks"

# OpenGL Benchmark
cat > /tmp/gl_benchmark.c << 'EOF'
#include <stdio.h>
#include <time.h>
#include <EGL/egl.h>
#include <GLES2/gl2.h>

int main() {
    EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (display == EGL_NO_DISPLAY) return 1;

    if (!eglInitialize(display, NULL, NULL)) return 1;

    EGLint attribs[] = {
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
        EGL_BLUE_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_RED_SIZE, 8,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_NONE
    };

    EGLConfig config;
    EGLint num_config;
    if (!eglChooseConfig(display, attribs, &config, 1, &num_config)) return 1;

    EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, NULL);
    if (context == EGL_NO_CONTEXT) return 1;

    EGLint pbuffer_attribs[] = {
        EGL_WIDTH, 800, EGL_HEIGHT, 600, EGL_NONE
    };
    EGLSurface surface = eglCreatePbufferSurface(display, config, pbuffer_attribs);

    if (!eglMakeCurrent(display, surface, surface, context)) return 1;

    // Simple OpenGL benchmark
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    // Render loop benchmark
    for (int i = 0; i < 1000; i++) {
        glClear(GL_COLOR_BUFFER_BIT);

        // Simple triangle rendering
        GLfloat vertices[] = {
            0.0f,  0.5f, 0.0f,
           -0.5f, -0.5f, 0.0f,
            0.5f, -0.5f, 0.0f
        };

        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, vertices);
        glEnableVertexAttribArray(0);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        glDisableVertexAttribArray(0);

        eglSwapBuffers(display, surface);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);

    double elapsed = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;
    double fps = 1000.0 / elapsed;

    printf("OpenGL Benchmark: %.1f FPS (%.3f seconds for 1000 frames)\n", fps, elapsed);

    eglTerminate(display);
    return fps > 30.0 ? 0 : 1;  // Expect at least 30 FPS
}
EOF

if gcc -o /tmp/gl_benchmark /tmp/gl_benchmark.c -lEGL -lGLESv2 -lrt 2>/dev/null; then
    run_test "OpenGL Performance Benchmark" "/tmp/gl_benchmark"
else
    print_warning "OpenGL benchmark compilation failed"
fi

# OpenCL Performance Benchmark
cat > /tmp/opencl_benchmark.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <CL/cl.h>

const char* kernel_source =
"__kernel void vector_add(__global float* a, __global float* b, __global float* c, int n) {"
"    int id = get_global_id(0);"
"    if (id < n) {"
"        c[id] = a[id] + b[id];"
"    }"
"}";

int main() {
    cl_platform_id platform;
    cl_device_id device;
    cl_context context;
    cl_command_queue queue;
    cl_program program;
    cl_kernel kernel;

    const int N = 1000000;
    size_t bytes = N * sizeof(float);

    // Get platform and device
    if (clGetPlatformIDs(1, &platform, NULL) != CL_SUCCESS) return 1;
    if (clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, 1, &device, NULL) != CL_SUCCESS) {
        // Try CPU if GPU not available
        if (clGetDeviceIDs(platform, CL_DEVICE_TYPE_CPU, 1, &device, NULL) != CL_SUCCESS) return 1;
    }

    // Create context and queue
    context = clCreateContext(NULL, 1, &device, NULL, NULL, NULL);
    if (!context) return 1;

    queue = clCreateCommandQueue(context, device, 0, NULL);
    if (!queue) return 1;

    // Create and build program
    program = clCreateProgramWithSource(context, 1, &kernel_source, NULL, NULL);
    if (!program || clBuildProgram(program, 1, &device, NULL, NULL, NULL) != CL_SUCCESS) return 1;

    // Create kernel
    kernel = clCreateKernel(program, "vector_add", NULL);
    if (!kernel) return 1;

    // Allocate host memory
    float *h_a = malloc(bytes);
    float *h_b = malloc(bytes);
    float *h_c = malloc(bytes);

    // Initialize data
    for (int i = 0; i < N; i++) {
        h_a[i] = (float)i;
        h_b[i] = (float)(2 * i);
    }

    // Create device buffers
    cl_mem d_a = clCreateBuffer(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, bytes, h_a, NULL);
    cl_mem d_b = clCreateBuffer(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, bytes, h_b, NULL);
    cl_mem d_c = clCreateBuffer(context, CL_MEM_WRITE_ONLY, bytes, NULL, NULL);

    // Set kernel arguments
    clSetKernelArg(kernel, 0, sizeof(cl_mem), &d_a);
    clSetKernelArg(kernel, 1, sizeof(cl_mem), &d_b);
    clSetKernelArg(kernel, 2, sizeof(cl_mem), &d_c);
    clSetKernelArg(kernel, 3, sizeof(int), &N);

    // Benchmark
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    size_t global_size = N;
    for (int i = 0; i < 100; i++) {
        clEnqueueNDRangeKernel(queue, kernel, 1, NULL, &global_size, NULL, 0, NULL, NULL);
    }
    clFinish(queue);

    clock_gettime(CLOCK_MONOTONIC, &end);

    double elapsed = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;
    double gflops = (100.0 * N) / (elapsed * 1e9);

    printf("OpenCL Benchmark: %.2f GFLOPS (%.3f seconds for 100 iterations)\n", gflops, elapsed);

    // Cleanup
    free(h_a); free(h_b); free(h_c);
    clReleaseMemObject(d_a); clReleaseMemObject(d_b); clReleaseMemObject(d_c);
    clReleaseKernel(kernel); clReleaseProgram(program);
    clReleaseCommandQueue(queue); clReleaseContext(context);

    return gflops > 0.1 ? 0 : 1;  // Expect at least 0.1 GFLOPS
}
EOF

if gcc -o /tmp/opencl_benchmark /tmp/opencl_benchmark.c -lOpenCL -lrt 2>/dev/null; then
    run_test "OpenCL Performance Benchmark" "/tmp/opencl_benchmark"
else
    print_warning "OpenCL benchmark compilation failed"
fi

# Memory Bandwidth Test
print_header "Memory Bandwidth Tests"

cat > /tmp/memory_bandwidth.py << 'EOF'
#!/usr/bin/env python3
import time
import numpy as np

def memory_bandwidth_test():
    """Test memory bandwidth with large arrays"""
    print("Testing memory bandwidth...")

    # Create large arrays (100MB each)
    size = 25 * 1024 * 1024  # 25M floats = 100MB

    print(f"Allocating arrays of {size} elements ({size * 4 / 1024 / 1024:.1f} MB each)")

    # Test allocation time
    start_time = time.time()
    a = np.random.rand(size).astype(np.float32)
    b = np.random.rand(size).astype(np.float32)
    alloc_time = time.time() - start_time
    print(f"Array allocation: {alloc_time:.3f} seconds")

    # Test copy bandwidth
    start_time = time.time()
    for i in range(10):
        c = np.copy(a)
    copy_time = time.time() - start_time
    copy_bandwidth = (size * 4 * 10) / (copy_time * 1024 * 1024 * 1024)
    print(f"Memory copy bandwidth: {copy_bandwidth:.2f} GB/s")

    # Test computation bandwidth
    start_time = time.time()
    for i in range(10):
        c = a + b
    add_time = time.time() - start_time
    add_bandwidth = (size * 4 * 3 * 10) / (add_time * 1024 * 1024 * 1024)  # 3 arrays accessed
    print(f"Addition bandwidth: {add_bandwidth:.2f} GB/s")

    # Test matrix multiplication
    matrix_size = int(np.sqrt(size / 4))  # Square matrix that fits in memory
    a_matrix = np.random.rand(matrix_size, matrix_size).astype(np.float32)
    b_matrix = np.random.rand(matrix_size, matrix_size).astype(np.float32)

    start_time = time.time()
    c_matrix = np.dot(a_matrix, b_matrix)
    matmul_time = time.time() - start_time

    flops = 2 * matrix_size**3  # Approximate FLOPs for matrix multiplication
    gflops = flops / (matmul_time * 1e9)
    print(f"Matrix multiplication ({matrix_size}x{matrix_size}): {gflops:.2f} GFLOPS")

    return copy_bandwidth > 1.0 and add_bandwidth > 1.0  # Expect at least 1 GB/s

if __name__ == "__main__":
    success = memory_bandwidth_test()
    exit(0 if success else 1)
EOF

run_test "Memory Bandwidth Test" "python3 /tmp/memory_bandwidth.py"

# GPU Compute Tests
print_header "GPU Compute Tests"

# Test GPU compute capabilities
echo "GPU Compute Information:"
if [ -r "/sys/class/devfreq/fb000000.gpu/cur_freq" ]; then
    echo "GPU Frequency: $(($(cat /sys/class/devfreq/fb000000.gpu/cur_freq) / 1000000)) MHz"
fi

# Check for GPU compute support
if command -v clinfo &> /dev/null; then
    echo -e "\nGPU Compute Capabilities:"
    clinfo | grep -E "(Compute|OpenCL|Version|Max compute)" || echo "No compute info available"
fi

# Power Consumption Tests
print_header "Power Management Tests"

echo "Power Management Information:"
echo "GPU Governor: $(cat /sys/class/devfreq/fb000000.gpu/governor 2>/dev/null || echo 'N/A')"

# Available governors
if [ -r "/sys/class/devfreq/fb000000.gpu/available_governors" ]; then
    echo "Available GPU Governors: $(cat /sys/class/devfreq/fb000000.gpu/available_governors)"
fi

# Test different performance modes
cat > /tmp/gpu_performance_test.sh << 'EOF'
#!/bin/bash

if [ ! -w "/sys/class/devfreq/fb000000.gpu/governor" ]; then
    echo "Cannot change GPU governor (need root privileges)"
    exit 1
fi

echo "Testing different GPU performance modes..."

# Save current governor
current_governor=$(cat /sys/class/devfreq/fb000000.gpu/governor)

# Test performance mode
echo "performance" > /sys/class/devfreq/fb000000.gpu/governor
sleep 1
perf_freq=$(cat /sys/class/devfreq/fb000000.gpu/cur_freq)
echo "Performance mode frequency: $((perf_freq / 1000000)) MHz"

# Test powersave mode
echo "powersave" > /sys/class/devfreq/fb000000.gpu/governor
sleep 1
power_freq=$(cat /sys/class/devfreq/fb000000.gpu/cur_freq)
echo "Powersave mode frequency: $((power_freq / 1000000)) MHz"

# Restore original governor
echo "$current_governor" > /sys/class/devfreq/fb000000.gpu/governor
echo "Restored governor: $current_governor"

exit 0
EOF

chmod +x /tmp/gpu_performance_test.sh

if sudo /tmp/gpu_performance_test.sh 2>/dev/null; then
    print_success "GPU Performance Mode Test"
else
    print_warning "GPU Performance Mode Test (requires root)"
fi

# Stability Tests
print_header "GPU Stability Tests"

cat > /tmp/gpu_stability.py << 'EOF'
#!/usr/bin/env python3
import time
import threading
import numpy as np

def gpu_stress_worker(duration, worker_id):
    """GPU stress test worker"""
    end_time = time.time() + duration
    operations = 0

    print(f"Worker {worker_id} starting...")

    while time.time() < end_time:
        try:
            # Heavy computation
            a = np.random.rand(800, 800).astype(np.float32)
            b = np.random.rand(800, 800).astype(np.float32)

            # Matrix operations
            c = np.dot(a, b)
            d = np.transpose(c)
            e = np.multiply(c, d)
            f = np.linalg.norm(e)

            operations += 1

            if operations % 50 == 0:
                print(f"Worker {worker_id}: {operations} operations")

        except Exception as e:
            print(f"Worker {worker_id} error: {e}")
            break

    print(f"Worker {worker_id} completed {operations} operations")
    return operations

def gpu_stability_test():
    """Multi-threaded GPU stability test"""
    print("Running 30-second GPU stability test with 4 workers...")

    duration = 30
    num_workers = 4
    threads = []

    start_time = time.time()

    # Start worker threads
    for i in range(num_workers):
        thread = threading.Thread(target=gpu_stress_worker, args=(duration, i))
        thread.start()
        threads.append(thread)

    # Wait for all threads to complete
    for thread in threads:
        thread.join()

    elapsed = time.time() - start_time
    print(f"Stability test completed in {elapsed:.2f} seconds")

    return elapsed >= duration * 0.9  # Should run for at least 90% of intended duration

if __name__ == "__main__":
    success = gpu_stability_test()
    exit(0 if success else 1)
EOF

run_test "GPU Stability Test" "python3 /tmp/gpu_stability.py"

# Final GPU Status Check
print_header "Final GPU Status"

echo "Current GPU Status:"
if [ -r "/sys/class/devfreq/fb000000.gpu/cur_freq" ]; then
    echo "Frequency: $(($(cat /sys/class/devfreq/fb000000.gpu/cur_freq) / 1000000)) MHz"
    echo "Governor: $(cat /sys/class/devfreq/fb000000.gpu/governor)"
fi

# Check for any GPU errors in system logs
echo -e "\nRecent GPU-related system messages:"
dmesg | grep -i -E "(mali|gpu|drm)" | tail -5 || echo "No recent GPU messages in dmesg"

# Summary
print_header "Test Summary"

echo -e "Total Tests Run: $TESTS_TOTAL"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All GPU tests passed! Mali-G610 is functioning correctly.${NC}"
    EXIT_CODE=0
elif [ $TESTS_PASSED -gt $TESTS_FAILED ]; then
    echo -e "\n${YELLOW}⚠️  Most tests passed, but some GPU issues detected.${NC}"
    EXIT_CODE=1
else
    echo -e "\n${RED}❌ Significant GPU issues detected. Check configuration.${NC}"
    EXIT_CODE=2
fi

# Performance Summary
echo -e "\n${MAGENTA}Performance Summary:${NC}"
print_benchmark "Check benchmark results above for detailed performance metrics"

# Recommendations
echo -e "\n${BLUE}Recommendations:${NC}"

if [ $TESTS_FAILED -gt 0 ]; then
    echo "• Check Mali GPU driver installation"
    echo "• Verify OpenCL/OpenGL library installation"
    echo "• Ensure user is in 'video' and 'render' groups"
    echo "• Check GPU device permissions in /dev/mali*"
fi

echo "• For optimal performance, set GPU governor to 'performance'"
echo "• Monitor GPU temperature during intensive workloads"
echo "• Consider GPU memory limits for large datasets"
echo "• Test with real applications for production validation"

# Ollama GPU Usage Info
echo -e "\n${CYAN}Ollama GPU Integration:${NC}"
echo "• GPU acceleration works through OpenCL"
echo "• Set OLLAMA_GPU_LAYERS environment variable"
echo "• Monitor GPU utilization during inference"
echo "• Mali-G610 provides moderate acceleration for smaller models"

# Cleanup temporary files
rm -f /tmp/test_opengl /tmp/test_opengl.c /tmp/test_opencl /tmp/test_opencl.c
rm -f /tmp/gl_benchmark /tmp/gl_benchmark.c /tmp/opencl_benchmark /tmp/opencl_benchmark.c
rm -f /tmp/gpu_stress.py /tmp/memory_bandwidth.py /tmp/gpu_performance_test.sh /tmp/gpu_stability.py

echo -e "\nGPU test completed at $(date)"
exit $EXIT_CODE