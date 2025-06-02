# RK3588 GPU & NPU Testing Documentation

## Overview
This document provides comprehensive testing procedures and documentation for both GPU (Mali-G610) and NPU (Neural Processing Unit) on RK3588 platforms. The test suite includes hardware detection, performance benchmarking, and functional validation.

## Prerequisites

- RK3588-based device
- Ubuntu 20.04/22.04 or compatible Linux distribution
- Root access (for some tests)
- Internet connection (for downloading test models and dependencies)
- Basic development tools (gcc, make, git, etc.)

## Test Scripts

### 1. GPU Test Suite (`testgpu.sh`)

#### Purpose
Comprehensive testing of the Mali-G610 GPU, including OpenCL support, 3D acceleration, and performance benchmarking.

#### Key Test Categories

1. **Hardware Detection**
   - RK3588 CPU detection
   - Mali GPU device files
   - DRM GPU device
   - GPU memory regions

2. **Kernel Module Tests**
   - Mali kernel module verification
   - DRM/KMS module checks

3. **OpenCL Tests**
   - OpenCL platform detection
   - Device enumeration
   - Basic OpenCL operations
   - Memory bandwidth tests

4. **Performance Benchmarks**
   - Matrix multiplication
   - Image processing
   - Compute performance

#### Usage
```bash
# Make the script executable
chmod +x testgpu.sh

# Run the test suite
./testgpu.sh

# For verbose output
./testgpu.sh -v

# Run specific test category
./testgpu.sh --category opencl
```

### 2. NPU Test Suite (`testnpu.sh`)

#### Purpose
Comprehensive testing of the RK3588 NPU, including model loading, inference, and performance benchmarking.

#### Key Test Categories

1. **Hardware Detection**
   - RK3588 CPU detection
   - NPU device files
   - NPU memory regions
   - Mali GPU device verification

2. **Kernel Module Tests**
   - RKNPU module verification
   - Mali module checks

3. **NPU Service Tests**
   - NPU service status
   - Runtime version checks

4. **Model Testing**
   - Model loading
   - Inference execution
   - Performance metrics

#### Usage
```bash
# Make the script executable
chmod +x testnpu.sh

# Run the test suite
./testnpu.sh

# For verbose output
./testnpu.sh -v

# Test specific model
./testnpu.sh --model path/to/model.rknn
```

## Test Results Interpretation

### Exit Codes
- `0`: All tests passed successfully
- `1`: Some tests failed
- `2`: Critical failures detected
- `3`: Environment issues found

### Output Format
- ✅ Success messages in green
- ❌ Error messages in red
- ⚠️  Warning messages in yellow
- ℹ️  Information messages in blue

## Common Issues and Troubleshooting

### GPU Issues
1. **No OpenCL devices found**
   - Verify Mali drivers are installed
   - Check if `/dev/mali*` devices exist
   - Ensure user is in the `video` and `render` groups

2. **Poor Performance**
   - Check for thermal throttling
   - Verify GPU frequency scaling
   - Ensure proper power supply

### NPU Issues
1. **NPU not detected**
   - Verify NPU drivers are installed
   - Check if `/dev/rknpu*` devices exist
   - Ensure NPU service is running

2. **Model loading failures**
   - Check model compatibility
   - Verify model was properly converted for RK3588
   - Check available memory

## Performance Tuning

### GPU Tuning
- Adjust GPU frequency scaling governor
- Optimize OpenCL work group sizes
- Use appropriate memory access patterns

### NPU Tuning
- Batch size optimization
- Model quantization
- Input preprocessing optimization

## Integration with Ollama

### GPU Acceleration
- Set environment variable: `OLLAMA_GPU=1`
- Verify with: `ollama info | grep -i gpu`

### NPU Acceleration (Experimental)
- Set environment variable: `OLLAMA_NPU=1`
- Verify with: `ollama info | grep -i npu`

## License
This documentation is provided under the MIT License. See the LICENSE file for more details.

## Support
For issues and support, please open an issue in the repository.

