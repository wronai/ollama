# 🚀 Start Ollama Network Service & SSH Scripts

This repository contains scripts for setting up Ollama as a network service and managing SSH connections with automatic key generation and copying.

*serve ollama on embedded without pain*

## 📋 Table of Contents

- [Overview](#overview)
- [Scripts](#scripts)
- [Ollama Network Service](#ollama-network-service)
- [SSH Connection Script](#ssh-connection-script)
- [Installation](#installation)
- [Usage Examples](#usage-examples)
- [API Reference](#api-reference)
- [Troubleshooting](#troubleshooting)

## 🔍 Overview

### Ollama Network Service (`ollama.sh`)
Automatically configures Ollama to serve across your entire network, making AI models accessible from any device on your local network. Features include:

- 🌐 Network-wide accessibility
- 🔧 Automatic systemd service creation
- 🔒 Firewall configuration
- 🤖 Automatic model installation (DeepSeek Coder)
- 📊 Comprehensive testing and monitoring
- 🐍 Python API examples

### SSH Connection Script (`ssh.sh`)
Fixes common SSH authentication issues and automatically manages SSH keys:

- 🔐 Automatic ED25519 key generation
- 📋 Automatic key copying to remote hosts
- 🛠️ Fixes "Too many authentication failures" errors
- 🔄 Multiple authentication fallback methods

## 📁 Scripts

### `ollama.sh`
Main script for setting up Ollama network service.

**Key Features:**
- Serves Ollama on specified port (default: 11434)
- Creates systemd service for automatic startup
- Configures firewall rules
- Installs DeepSeek Coder model automatically
- Provides comprehensive testing and examples

### `ssh.sh`
SSH connection script with automatic key management.

**Key Features:**
- Generates ED25519 SSH keys if not present
- Copies keys to remote hosts automatically
- Handles authentication failures gracefully
- Multiple fallback authentication methods

## 🌐 Ollama Network Service

### Quick Start

```bash
# Make executable
chmod +x ollama.sh

# Start with default settings (port 11434)
./ollama.sh

# Start on custom port
./ollama.sh -p 8081

# Test the service
./ollama.sh --test

# View API examples
./ollama.sh --examples
```

### Service Management

```bash
# Check service status
sudo systemctl status ollama-network

# Start/stop/restart service
sudo systemctl start ollama-network
sudo systemctl stop ollama-network
sudo systemctl restart ollama-network

# View logs
sudo journalctl -u ollama-network -f

# Enable/disable auto-start
sudo systemctl enable ollama-network
sudo systemctl disable ollama-network
```

### Network Access

Once running, your Ollama service will be accessible from any device on your network:

```bash
# Replace 192.168.1.100 with your server's IP
curl http://192.168.1.100:11434/api/tags
```

### Available Commands

| Command | Description |
|---------|-------------|
| `./ollama.sh` | Start service with default settings |
| `./ollama.sh -p PORT` | Start on specific port |
| `./ollama.sh --stop` | Stop the service |
| `./ollama.sh --status` | Show service status |
| `./ollama.sh --test` | Run comprehensive tests |
| `./ollama.sh --examples` | Show API usage examples |
| `./ollama.sh --install-model` | Install DeepSeek Coder model |
| `./ollama.sh --logs` | View service logs |

## 🔐 SSH Connection Script

### Quick Start

```bash
# Make executable
chmod +x ssh.sh

# Connect to remote host (will generate keys if needed)
./ssh.sh root@192.168.1.100

# Connect to different host
./ssh.sh user@hostname.local
```

### What it does automatically:

1. **Checks for ED25519 key** - generates if missing
2. **Copies key to remote host** - prompts for password once
3. **Establishes connection** - uses key authentication
4. **Handles failures** - falls back to password auth if needed

### Key Files Created:
- `~/.ssh/id_ed25519` - Private key
- `~/.ssh/id_ed25519.pub` - Public key

## 🛠️ Installation

### Prerequisites

**For Ollama Service:**
- Linux system with systemd
- Ollama installed (`curl -fsSL https://ollama.ai/install.sh | sh`)
- Root or sudo access
- Network connectivity

**For SSH Script:**
- OpenSSH client
- ssh-keygen utility
- ssh-copy-id utility

### Installation Steps

1. **Download scripts:**
```bash
wget https://your-repo/ollama.sh
wget https://your-repo/ssh.sh
```

2. **Make executable:**
```bash
chmod +x ollama.sh ssh.sh
```

3. **Install Ollama (if needed):**
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

4. **Run setup:**
```bash
./ollama.sh
```

## 📚 Usage Examples

### Ollama API Examples

#### 1. List Available Models
```bash
curl -s http://192.168.1.100:11434/api/tags | jq '.models[].name'
```

#### 2. Generate Code
```bash
curl -X POST http://192.168.1.100:11434/api/generate \
     -H 'Content-Type: application/json' \
     -d '{
       "model": "deepseek-coder:1.3b",
       "prompt": "Write a Python function to sort a list",
       "stream": false
     }'
```

#### 3. Chat Conversation
```bash
curl -X POST http://192.168.1.100:11434/api/chat \
     -H 'Content-Type: application/json' \
     -d '{
       "model": "deepseek-coder:1.3b",
       "messages": [
         {"role": "user", "content": "Explain recursion in programming"}
       ],
       "stream": false
     }'
```

#### 4. Pull New Model
```bash
curl -X POST http://192.168.1.100:11434/api/pull \
     -H 'Content-Type: application/json' \
     -d '{"name": "mistral:latest"}'
```

#### 5. Streaming Response
```bash
curl -X POST http://192.168.1.100:11434/api/generate \
     -H 'Content-Type: application/json' \
     -d '{
       "model": "deepseek-coder:1.3b",
       "prompt": "Create a REST API in Python",
       "stream": true
     }'
```

### Python Client Example

```python
import requests
import json

class OllamaClient:
    def __init__(self, host="192.168.1.100", port=11434):
        self.base_url = f"http://{host}:{port}"
    
    def generate(self, model, prompt, stream=False):
        response = requests.post(
            f"{self.base_url}/api/generate",
            json={
                "model": model,
                "prompt": prompt,
                "stream": stream
            }
        )
        return response.json()
    
    def chat(self, model, messages, stream=False):
        response = requests.post(
            f"{self.base_url}/api/chat",
            json={
                "model": model,
                "messages": messages,
                "stream": stream
            }
        )
        return response.json()
    
    def list_models(self):
        response = requests.get(f"{self.base_url}/api/tags")
        return response.json()

# Usage
client = OllamaClient()

# Generate code
result = client.generate(
    "deepseek-coder:1.3b", 
    "Write a function to calculate fibonacci numbers"
)
print(result['response'])

# Chat
messages = [{"role": "user", "content": "What is machine learning?"}]
result = client.chat("deepseek-coder:1.3b", messages)
print(result['message']['content'])
```

### SSH Examples

```bash
# Connect to server (first time - will setup keys)
./ssh.sh root@192.168.1.100

# Connect to different user
./ssh.sh admin@server.local

# Connect to server with non-standard port (manual)
ssh -p 2222 -i ~/.ssh/id_ed25519 root@192.168.1.100
```

## 📖 API Reference

### Ollama REST API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/tags` | GET | List available models |
| `/api/generate` | POST | Generate text completion |
| `/api/chat` | POST | Chat conversation |
| `/api/pull` | POST | Download model |
| `/api/push` | POST | Upload model |
| `/api/show` | POST | Show model information |
| `/api/copy` | POST | Copy model |
| `/api/delete` | DELETE | Delete model |

### Request/Response Examples

#### Generate Text
**Request:**
```json
{
  "model": "deepseek-coder:1.3b",
  "prompt": "Write hello world in Python",
  "stream": false,
  "options": {
    "temperature": 0.7,
    "top_p": 0.9
  }
}
```

**Response:**
```json
{
  "model": "deepseek-coder:1.3b",
  "created_at": "2025-06-02T08:42:07.311663549Z",
  "response": "print(\"Hello, World!\")",
  "done": true,
  "context": [...],
  "total_duration": 1234567890,
  "load_duration": 1234567,
  "prompt_eval_duration": 1234567,
  "eval_count": 10,
  "eval_duration": 1234567890
}
```

## 🔧 Troubleshooting

### Common Issues

#### Ollama Service Won't Start
```bash
# Check if port is in use
ss -tlnp | grep :11434

# Check service logs
sudo journalctl -u ollama-network -f

# Restart service
sudo systemctl restart ollama-network

# Check firewall
sudo ufw status
```

#### Network Access Issues
```bash
# Test local connection first
curl http://localhost:11434/api/tags

# Check firewall rules
sudo ufw allow 11434/tcp

# Check if service binds to all interfaces
ss -tlnp | grep :11434
# Should show 0.0.0.0:11434, not 127.0.0.1:11434
```

#### SSH Connection Problems
```bash
# Clear SSH agent
ssh-add -D

# Remove old host keys
ssh-keygen -R hostname

# Try with password only
ssh -o IdentitiesOnly=yes -o PreferredAuthentications=password user@host

# Debug connection
ssh -v user@host
```

#### Model Download Failures
```bash
# Check disk space
df -h

# Check internet connection
curl -I https://ollama.ai

# Try smaller model
ollama pull tinyllama

# Check Ollama logs
tail -f /tmp/ollama.log
```

### Performance Optimization

#### For Better Performance:
```bash
# Increase model context (if you have RAM)
export OLLAMA_CONTEXT_LENGTH=8192

# Enable GPU acceleration (if available)
export OLLAMA_INTEL_GPU=1

# Adjust concurrent requests
export OLLAMA_MAX_QUEUE=512
```

#### Monitor Resource Usage:
```bash
# CPU and memory usage
htop

# GPU usage (if applicable)
nvidia-smi

# Disk usage
df -h ~/.ollama/models/
```

### Security Considerations

#### Network Security:
- 🔒 Only run on trusted networks
- 🛡️ Consider using VPN for remote access
- 🚫 Don't expose to public internet without authentication
- 🔐 Use firewall rules to restrict access

#### SSH Security:
- 🔑 ED25519 keys are more secure than RSA
- 🚫 Disable password authentication after key setup
- 🔒 Use SSH agent for key management
- 📝 Regularly rotate SSH keys

## 📞 Support

### Getting Help

1. **Check logs:** `sudo journalctl -u ollama-network -f`
2. **Test connectivity:** `./ollama.sh --test`
3. **View examples:** `./ollama.sh --examples`
4. **Check service status:** `sudo systemctl status ollama-network`

### Useful Commands

```bash
# Complete system status
./ollama.sh --test

# View all running services
systemctl list-units --type=service --state=running | grep ollama

# Check network configuration
ip addr show
ss -tlnp | grep ollama

# Monitor real-time logs
tail -f /var/log/syslog | grep ollama
```

---

## 📄 License

This project is open source. Feel free to modify and distribute.

## 🤝 Contributing

Contributions welcome! Please feel free to submit issues and pull requests.

---

**Happy coding with Ollama! 🚀🤖**
