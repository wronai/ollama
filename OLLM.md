**Step 1: First, let's check if Ollama is currently running and what's happening:**

```bash
# Check if Ollama is running
pgrep -fl ollama

# Check if port 8081 is in use
ss -tlnp | grep :8081

# Check if there are any Ollama services
systemctl list-units | grep ollama
```

**Step 2: Let's create the systemd service file properly:**

```bash
# Create the service file
sudo tee /etc/systemd/system/ollama-network.service > /dev/null <<EOF
[Unit]
Description=Ollama Network Server
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
User=tom
Group=tom
Environment=OLLAMA_HOST=0.0.0.0:8081
Environment=OLLAMA_ORIGINS=*
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
WorkingDirectory=/home/tom

[Install]
WantedBy=multi-user.target
EOF
```

**Step 3: Now reload, enable and start the service:**

```bash
# Reload systemd to recognize the new service
sudo systemctl daemon-reload

# Enable the service to start on boot
sudo systemctl enable ollama-network.service

# Start the service
sudo systemctl start ollama-network.service

# Check the status
sudo systemctl status ollama-network.service
```

**Step 4: If that works, test the connection:**

```bash
# Wait a moment for it to start
sleep 5

# Test locally
curl -s http://localhost:8081/api/tags

# Get your IP address
ip route get 8.8.8.8 | awk '{print $7; exit}'
```

**Alternative: Quick Manual Start (if systemd approach fails):**

If the systemd service doesn't work, let's just start it manually:

```bash
# Stop any existing Ollama processes
sudo pkill -f ollama || true

# Start Ollama manually with network access
OLLAMA_HOST=0.0.0.0:8081 OLLAMA_ORIGINS=* ollama serve &

# Check if it's running
sleep 3
curl -s http://localhost:8081/api/tags
```

**Step 5: Configure firewall:**

```bash
# Allow port 8081 through firewall
sudo ufw allow 8081/tcp
```

**Step 6: Install tinyllama model:**

```bash
# Install the model (this might take a few minutes)
ollama pull tinyllama
```

Try the systemd service creation first. If you get any error messages, please share them and we'll troubleshoot. The key is getting that service file created properly first, then we can start the service.

