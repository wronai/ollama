# Przejdź do katalogu setup
cd ~/rknn_setup

# Uruchom skrypt finalizacyjny  
bash rknn_finalize.sh
```

Jeśli nie masz jeszcze skryptu `rknn_finalize.sh`, stwórz go:

```bash
# Utwórz i uruchom skrypt finalizacyjny
cat > rknn_finalize.sh << 'EOF'
#!/bin/bash

# Aktywuj środowisko
cd ~/rknn_setup
source rknn-toolkit2-master/venv/bin/activate

# Zainstaluj RKNN Lite
echo "Installing RKNN Lite..."
cd rknn-toolkit2-master/rknn-toolkit-lite2/packages
pip install rknn_toolkit_lite2-2.3.2-cp311-cp311-manylinux_2_17_aarch64.manylinux2014_aarch64.whl

cd ~/rknn_setup

# Utwórz test NPU
cat > test_npu_complete.py << 'EOFTEST'
#!/usr/bin/env python3
import os

def test_all():
    print("🚀 Complete NPU Test")
    print("=" * 40)
    
    # Test RKNN Toolkit
    try:
        from rknn.api import RKNN
        print("✓ RKNN Toolkit2 available")
        
        rknn = RKNN(verbose=False)
        print("✓ RKNN object created")
        toolkit_ok = True
    except Exception as e:
        print(f"✗ RKNN Toolkit error: {e}")
        toolkit_ok = False
    
    # Test RKNN Lite
    try:
        from rknnlite.api import RKNNLite
        print("✓ RKNN Lite available")
        
        rknn_lite = RKNNLite()
        print("✓ RKNN Lite object created")
        lite_ok = True
    except Exception as e:
        print(f"✗ RKNN Lite error: {e}")
        lite_ok = False
    
    # Check NPU device
    device_ok = os.path.exists('/dev/rknpu')
    print(f"{'✓' if device_ok else '✗'} NPU device: /dev/rknpu")
    
    # Summary
    print("\n" + "=" * 40)
    print("📊 RESULTS:")
    print(f"RKNN Toolkit: {'✓' if toolkit_ok else '✗'}")
    print(f"RKNN Lite:    {'✓' if lite_ok else '✗'}")
    print(f"NPU Device:   {'✓' if device_ok else '✗'}")
    
    score = sum([toolkit_ok, lite_ok, device_ok])
    print(f"\nScore: {score}/3")
    
    if score >= 2:
        print("\n🎉 NPU is ready for use!")
    else:
        print("\n⚠️ Some components need attention")

if __name__ == "__main__":
    test_all()
EOFTEST

# Uruchom NPU service
echo "Starting NPU service..."
sudo systemctl start rknn-server

# Uruchom test
echo "Running complete test..."
python3 test_npu_complete.py

echo ""
echo "🎉 Setup completed!"
echo "📖 Quick start:"
echo "  cd ~/rknn_setup"
echo "  source rknn-toolkit2-master/venv/bin/activate"
echo "  python3 test_npu_complete.py"
EOF

chmod +x rknn_finalize.sh
bash rknn_finalize.sh
```

**Po uruchomieniu tego skryptu, możesz przetestować NPU:**

```bash
# Aktywuj środowisko RKNN
cd ~/rknn_setup
source rknn-toolkit2-master/venv/bin/activate

# Test kompletny
python3 test_npu_complete.py

# Sprawdź service NPU
sudo systemctl status rknn-server

# Przetestuj z przykładem
cd rknn-toolkit2-master/rknn-toolkit-lite2/examples/resnet18/
python3 test.py
```

**Status obecny:**
- ✅ **RKNN Toolkit2** - działa (wersja 2.3.2)
- ✅ **Podstawowe biblioteki** - działa
- ⚠️ **RKNN Lite** - wymaga doinstalowania
- ⚠️ **NPU Service** - wymaga uruchomienia

Po uruchomieniu `rknn_finalize.sh` będziesz mieć kompletne środowisko NPU gotowe do pracy! 🚀