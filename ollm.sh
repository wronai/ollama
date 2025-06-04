#!/bin/bash

# Ollama Network Setup - Troubleshooting and Manual Steps
# Use this if the main script fails

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

OLLAMA_PORT="8081"

echo "========================================"
echo "    Ollama Network Setup Diagnostic    "
echo "========================================"
echo ""

# 1. Check current Ollama status
print_status "1. Checking current Ollama status..."
echo "Ollama processes:"
pgrep -fl ollama || echo "No Ollama processes running"
echo ""

# 2. Check systemd services
print_status "2. Checking systemd services..."
echo "Standard Ollama service:"
systemctl status ollama 2>/dev/null || echo "Standard ollama service not found"
echo ""
echo "Network Ollama service:"
systemctl status ollama-network 2>/dev/null || echo "ollama-network service not found"
echo ""

# 3. Check if port is in use
print_status "3. Checking if port $OLLAMA_PORT is in use..."
if command -v ss >/dev/null 2>&1; then
    ss -tlnp | grep ":$OLLAMA_PORT" || echo "Port $OLLAMA_PORT is free"
elif command -v netstat >/dev/null 2>&1; then
    netstat -tlnp | grep ":$OLLAMA_PORT" || echo "Port $OLLAMA_PORT is free"
fi
echo ""

# 4. Manual setup steps
echo "========================================"
echo "          MANUAL SETUP STEPS           "
echo "========================================"
echo ""

print_status "STEP 1: Clean stop all Ollama processes"
echo "sudo systemctl stop ollama 2>/dev/null || true"
echo "sudo systemctl stop ollama-network 2>/dev/null || true"
echo "sudo pkill -f ollama || true"
echo ""

print_status "STEP 2: Start Ollama manually with network access"
echo "export OLLAMA_HOST=0.0.0.0:$OLLAMA_PORT"
echo "export OLLAMA_ORIGINS=*"
echo "ollama serve"
echo ""
echo "Or run in background:"
echo "nohup env OLLAMA_HOST=0.0.0.0:$OLLAMA_PORT OLLAMA_ORIGINS=* ollama serve > /tmp/ollama.log 2>&1 &"
echo ""

print_status "STEP 3: Test the connection"
echo "# Test locally:"
echo "curl -s http://localhost:$OLLAMA_PORT/api/tags"
echo ""
echo "# Test from network (replace YOUR_IP):"
echo "curl -s http://YOUR_IP:$OLLAMA_PORT/api/tags"
echo ""

print_status "STEP 4: Configure firewall (if needed)"
echo "# UFW (Ubuntu/Debian):"
echo "sudo ufw allow $OLLAMA_PORT/tcp"
echo ""
echo "# Firewalld (CentOS/RHEL):"
echo "sudo firewall-cmd --permanent --add-port=$OLLAMA_PORT/tcp"
echo "sudo firewall-cmd --reload"
echo ""

print_status "STEP 5: Install a model"
echo "ollama pull deepseek-coder:1.3b"
echo "# OR"
echo "ollama pull qwen2.5-coder:1.5b"
echo "# OR"
echo "ollama pull tinyllama"
echo ""

print_status "STEP 6: Get your IP address"
ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null | head -1 | while read ip; do
    if [ -n "$ip" ]; then
        echo "Your IP address appears to be: $ip"
        echo "Test URL: http://$ip:$OLLAMA_PORT/api/tags"
    else
        echo "Could not determine IP address automatically"
        echo "Find your IP with: ip addr show | grep 'inet '"
    fi
done

echo ""
echo "========================================"
echo "         ALTERNATIVE APPROACH          "
echo "========================================"
echo ""

print_status "If you prefer a simple one-liner approach:"
echo ""
echo "# Stop any existing Ollama"
echo "sudo pkill -f ollama || true"
echo ""
echo "# Start with network access"
echo "OLLAMA_HOST=0.0.0.0:$OLLAMA_PORT OLLAMA_ORIGINS=* ollama serve &"
echo ""
echo "# Allow through firewall"
echo "sudo ufw allow $OLLAMA_PORT/tcp || true"
echo ""
echo "# Install a model"
echo "sleep 5 && ollama pull tinyllama"
echo ""

echo "========================================"
echo "            QUICK COMMANDS             "
echo "========================================"
echo ""
echo "Check if Ollama is running:"
echo "  pgrep -fl ollama"
echo ""
echo "Check port status:"
echo "  ss -tlnp | grep :$OLLAMA_PORT"
echo ""
echo "View Ollama logs:"
echo "  tail -f /tmp/ollama.log"
echo ""
echo "Kill all Ollama processes:"
echo "  sudo pkill -f ollama"
echo ""
echo "Test API:"
echo "  curl -s http://localhost:$OLLAMA_PORT/api/tags | jq"
echo ""

echo "========================================"
echo "           SYSTEMD SERVICE             "
echo "========================================"
echo ""
print_status "To create a proper systemd service manually:"
echo ""
echo "1. Create the service file:"
echo "sudo tee /etc/systemd/system/ollama-network.service > /dev/null <<EOF"
echo "[Unit]"
echo "Description=Ollama Network Server"
echo "After=network-online.target"
echo "Wants=network-online.target"
echo ""
echo "[Service]"
echo "Type=exec"
echo "User=$USER"
echo "Group=$USER"
echo "Environment=OLLAMA_HOST=0.0.0.0:$OLLAMA_PORT"
echo "Environment=OLLAMA_ORIGINS=*"
echo "Environment=PATH=/usr/local/bin:/usr/bin:/bin"
echo "ExecStart=$(which ollama) serve"
echo "Restart=always"
echo "RestartSec=3"
echo "StandardOutput=journal"
echo "StandardError=journal"
echo "WorkingDirectory=/home/$USER"
echo ""
echo "[Install]"
echo "WantedBy=multi-user.target"
echo "EOF"
echo ""
echo "2. Enable and start the service:"
echo "sudo systemctl daemon-reload"
echo "sudo systemctl enable ollama-network.service"
echo "sudo systemctl start ollama-network.service"
echo ""
echo "3. Check service status:"
echo "sudo systemctl status ollama-network.service"
echo ""

echo "========================================"
print_success "Diagnostic complete!"
echo "========================================"