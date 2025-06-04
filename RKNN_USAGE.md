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
