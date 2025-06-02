# NPU i GPU na Radxa ROCK 5B+

## 1. **Mali-G610 GPU Setup** 
Konfiguruje GPU do pracy z OpenCL i przygotowuje do użycia z Ollama:
- Instaluje sterowniki OpenCL
- Konfiguruje uprawnienia użytkownika
- Tworzy narzędzia testowe
- Optymalizuje wydajność GPU
- Przygotowuje środowisko do acceleration

## 2. **RKNN NPU Setup**
Kompleksowa instalacja sterowników NPU z integracją Ollama:
- Pobiera i instaluje RKNN Toolkit2
- Konfiguruje runtime NPU
- Tworzy serwis systemowy dla NPU
- Przygotowuje narzędzia konwersji modeli
- Integruje z Ollama (eksperymentalnie)

**Użycie:**
```bash
# Pobierz skrypty i nadaj uprawnienia
chmod +x mali_gpu_setup.sh rknn_npu_setup.sh

# Uruchom oba skrypty
./rk_gpu.sh
./rknpup.sh

# Restartuj system
sudo reboot

# Po restarcie przetestuj
./testnpu.sh
./testgpu.sh
clinfo  # test OpenCL
```

**Ważne uwagi:**
- NPU w Ollama jest eksperymentalne
- Mali GPU sterowniki mogą wymagać ręcznego pobrania z ARM
- Po instalacji będziesz mieć dostęp do acceleration zarówno przez GPU (OpenCL) jak i NPU (RKNN)
- Skrypty tworzą kompletne środowisko testowe

