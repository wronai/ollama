#!/bin/bash

# Ollama Network Server Setup Script
# This script configures Ollama to serve on the entire network

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
OLLAMA_HOST="0.0.0.0"
OLLAMA_PORT="11434"
OLLAMA_ORIGINS="*"

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get local IP address
get_local_ip() {
    # Try different methods to get local IP
    local ip=""
    
    # Method 1: ip route (Linux)
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null)
    fi
    
    # Method 2: hostname -I (Linux)
    if [ -z "$ip" ] && command -v hostname >/dev/null 2>&1; then
        ip=$(hostname -I | awk '{print $1}' 2>/dev/null)
    fi
    
    # Method 3: ifconfig (macOS/Linux)
    if [ -z "$ip" ] && command -v ifconfig >/dev/null 2>&1; then
        ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
    fi
    
    # Method 4: route (macOS)
    if [ -z "$ip" ] && command -v route >/dev/null 2>&1; then
        ip=$(route get default | grep interface | awk '{print $2}' | xargs ifconfig | grep inet | grep -v inet6 | awk '{print $2}' | head -1)
    fi
    
    echo "$ip"
}

# Function to check if Ollama is installed
check_ollama() {
    if ! command -v ollama >/dev/null 2>&1; then
        print_error "Ollama is not installed!"
        echo "Install Ollama first:"
        echo "curl -fsSL https://ollama.ai/install.sh | sh"
        exit 1
    else
        print_success "Ollama is installed"
    fi
}

# Function to stop existing Ollama service
stop_ollama() {
    print_status "Stopping existing Ollama service..."
    
    # Stop systemd service if it exists
    if systemctl is-active --quiet ollama 2>/dev/null; then
        systemctl stop ollama 2>/dev/null || true
        print_status "Stopped ollama systemd service"
    fi
    
    # Stop our custom service if it exists
    if systemctl is-active --quiet ollama-network 2>/dev/null; then
        systemctl stop ollama-network 2>/dev/null || true
        print_status "Stopped ollama-network service"
    fi
    
    # Kill any running ollama processes
    if pgrep -f ollama >/dev/null 2>&1; then
        pkill -f ollama 2>/dev/null || true
        print_status "Killed existing ollama processes"
    fi
    
    # Wait for processes to stop
    sleep 3
    
    # Verify processes are stopped
    if pgrep -f ollama >/dev/null 2>&1; then
        print_warning "Some ollama processes may still be running"
        pgrep -fl ollama
    else
        print_success "All ollama processes stopped"
    fi
}

# Function to configure firewall
configure_firewall() {
    print_status "Configuring firewall for port $OLLAMA_PORT..."
    
    # UFW (Ubuntu/Debian)
    if command -v ufw >/dev/null 2>&1; then
        ufw allow $OLLAMA_PORT/tcp 2>/dev/null && print_success "UFW rule added" || print_warning "UFW rule may already exist"
    fi
    
    # Firewalld (CentOS/RHEL/Fedora)
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=$OLLAMA_PORT/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        print_success "Firewalld rule added"
    fi
    
    # iptables (generic Linux)
    if command -v iptables >/dev/null 2>&1 && ! command -v ufw >/dev/null 2>&1 && ! command -v firewall-cmd >/dev/null 2>&1; then
        iptables -A INPUT -p tcp --dport $OLLAMA_PORT -j ACCEPT 2>/dev/null && print_success "iptables rule added" || true
    fi
    
    print_success "Firewall configuration completed"
}

# Function to create systemd service
create_systemd_service() {
    print_status "Creating systemd service for network access..."
    
    cat << EOF > /etc/systemd/system/ollama-network.service
[Unit]
Description=Ollama Network Server
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
User=$USER
Group=$USER
Environment=OLLAMA_HOST=$OLLAMA_HOST:$OLLAMA_PORT
Environment=OLLAMA_ORIGINS=$OLLAMA_ORIGINS
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=$(which ollama) serve
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
WorkingDirectory=/home/$USER

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable ollama-network.service
    print_success "Systemd service created and enabled"
}

# Function to start Ollama server
start_ollama_server() {
    print_status "Starting Ollama server for network access..."
    
    # Export environment variables
    export OLLAMA_HOST="$OLLAMA_HOST:$OLLAMA_PORT"
    export OLLAMA_ORIGINS="$OLLAMA_ORIGINS"
    
    # Start using systemd service
    if systemctl start ollama-network.service 2>/dev/null; then
        print_success "Ollama network service started"
        sleep 5  # Give it time to start
    else
        print_warning "Systemd service failed, starting manually..."
        # Fallback: start manually in background
        OLLAMA_HOST="$OLLAMA_HOST:$OLLAMA_PORT" OLLAMA_ORIGINS="$OLLAMA_ORIGINS" nohup ollama serve > /tmp/ollama.log 2>&1 &
        sleep 5
        if pgrep -f "ollama serve" > /dev/null; then
            print_success "Ollama started manually"
        else
            print_error "Failed to start Ollama"
            print_status "Check logs: cat /tmp/ollama.log"
            exit 1
        fi
    fi
}

# Function to install default model
install_default_model() {
    print_status "Checking for models..."
    
    # Check if any models are installed
    models_response=$(curl -s --connect-timeout 10 "http://localhost:$OLLAMA_PORT/api/tags" 2>/dev/null | jq -r '.models[]?.name' 2>/dev/null)
    
    if [ -z "$models_response" ]; then
        print_warning "No models found. Installing DeepSeek Coder..."
        print_status "This may take several minutes depending on your internet connection..."
        
        # Pull DeepSeek Coder model
        echo "Downloading DeepSeek Coder model (approximately 3.8GB)..."
        ollama pull deepseek-coder:1.3b 2>/dev/null || ollama pull deepseek-coder 2>/dev/null || {
            print_warning "Failed to pull deepseek-coder, trying smaller model..."
            ollama pull qwen2.5-coder:1.5b 2>/dev/null || {
                print_warning "Failed to pull qwen2.5-coder, trying tinyllama..."
                ollama pull tinyllama 2>/dev/null || {
                    print_error "Failed to install any model. Install manually:"
                    echo "  ollama pull deepseek-coder"
                    echo "  ollama pull qwen2.5-coder"
                    echo "  ollama pull tinyllama"
                    return 1
                }
            }
        }
        
        # Verify installation
        sleep 2
        models_response=$(curl -s "http://localhost:$OLLAMA_PORT/api/tags" 2>/dev/null | jq -r '.models[]?.name' 2>/dev/null)
        if [ -n "$models_response" ]; then
            print_success "Model installed successfully!"
            echo "Available models:"
            echo "$models_response" | sed 's/^/  - /'
        else
            print_error "Model installation verification failed"
            return 1
        fi
    else
        print_success "Models already installed:"
        echo "$models_response" | sed 's/^/  - /'
    fi
}
test_server() {
    local ip=$(get_local_ip)
    print_status "Testing server connection..."
    
    sleep 3
    
    # Test 1: Check if Ollama process is running
    if pgrep -f "ollama serve" > /dev/null; then
        print_success "Ollama process is running"
    else
        print_error "Ollama process is not running"
        return 1
    fi
    
    # Test 2: Local connection test
    print_status "Testing local connection..."
    local local_response
    local_response=$(curl -s --connect-timeout 10 "http://localhost:$OLLAMA_PORT/api/tags" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$local_response" ]; then
        print_success "Local connection successful"
        echo "Response: $(echo "$local_response" | head -c 100)..."
    else
        print_error "Local connection failed"
        print_status "Checking if port is listening..."
        if command -v ss >/dev/null 2>&1; then
            ss -tlnp | grep ":$OLLAMA_PORT"
        elif command -v netstat >/dev/null 2>&1; then
            netstat -tlnp | grep ":$OLLAMA_PORT"
        fi
        return 1
    fi
    
    # Test 3: Network connection test
    if [ -n "$ip" ]; then
        print_status "Testing network connection from $ip..."
        local network_response
        network_response=$(curl -s --connect-timeout 10 "http://$ip:$OLLAMA_PORT/api/tags" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$network_response" ]; then
            print_success "Network connection successful"
        else
            print_warning "Network connection failed - may be blocked by firewall"
            print_status "Checking firewall status..."
            check_firewall_status
        fi
    fi
    
    # Test 4: Check available models
    print_status "Checking available models..."
    local models_response
    models_response=$(curl -s "http://localhost:$OLLAMA_PORT/api/tags" 2>/dev/null | jq -r '.models[].name' 2>/dev/null)
    if [ -n "$models_response" ]; then
        echo "Available models:"
        echo "$models_response" | sed 's/^/  - /'
    else
        print_warning "No models installed. Install a model first:"
        echo "  ollama pull llama2"
        echo "  ollama pull mistral"
    fi
}

# Function to check firewall status
check_firewall_status() {
    # Check UFW
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(ufw status 2>/dev/null | grep "$OLLAMA_PORT")
        if [ -n "$ufw_status" ]; then
            print_success "UFW rule exists for port $OLLAMA_PORT"
        else
            print_warning "UFW rule missing for port $OLLAMA_PORT"
        fi
    fi
    
    # Check firewalld
    if command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --list-ports 2>/dev/null | grep -q "$OLLAMA_PORT"; then
            print_success "Firewalld rule exists for port $OLLAMA_PORT"
        else
            print_warning "Firewalld rule missing for port $OLLAMA_PORT"
        fi
    fi
}

# Function to show connection info
show_connection_info() {
    local ip=$(get_local_ip)
    
    echo ""
    echo "========================================"
    print_success "Ollama is now serving on the network!"
    echo "========================================"
    echo ""
    echo "📡 SERVER ADDRESSES:"
    echo "  Local:   http://localhost:$OLLAMA_PORT"
    echo "  Network: http://$ip:$OLLAMA_PORT"
    echo ""
    echo "🔗 API ENDPOINTS:"
    echo "  Tags:     http://$ip:$OLLAMA_PORT/api/tags"
    echo "  Generate: http://$ip:$OLLAMA_PORT/api/generate"
    echo "  Chat:     http://$ip:$OLLAMA_PORT/api/chat"
    echo "  Pull:     http://$ip:$OLLAMA_PORT/api/pull"
    echo "  Show:     http://$ip:$OLLAMA_PORT/api/show"
    echo ""
    echo "🧪 CURL EXAMPLES:"
    echo ""
    echo "1. List available models:"
    echo "   curl -s http://$ip:$OLLAMA_PORT/api/tags | jq"
    echo ""
    echo "2. Pull a model (from server machine):"
    echo "   curl -X POST http://$ip:$OLLAMA_PORT/api/pull \\"
    echo "        -H 'Content-Type: application/json' \\"
    echo "        -d '{\"name\": \"llama2\"}'"
    echo ""
    echo "3. Generate text (simple):"
    echo "   curl -X POST http://$ip:$OLLAMA_PORT/api/generate \\"
    echo "        -H 'Content-Type: application/json' \\"
    echo "        -d '{\"model\": \"llama2\", \"prompt\": \"Hello, how are you?\", \"stream\": false}'"
    echo ""
    echo "4. Chat conversation:"
    echo "   curl -X POST http://$ip:$OLLAMA_PORT/api/chat \\"
    echo "        -H 'Content-Type: application/json' \\"
    echo "        -d '{\"model\": \"llama2\", \"messages\": [{\"role\": \"user\", \"content\": \"Explain quantum computing\"}], \"stream\": false}'"
    echo ""
    echo "5. Model information:"
    echo "   curl -X POST http://$ip:$OLLAMA_PORT/api/show \\"
    echo "        -H 'Content-Type: application/json' \\"
    echo "        -d '{\"name\": \"llama2\"}'"
    echo ""
    echo "6. Streaming response:"
    echo "   curl -X POST http://$ip:$OLLAMA_PORT/api/generate \\"
    echo "        -H 'Content-Type: application/json' \\"
    echo "        -d '{\"model\": \"llama2\", \"prompt\": \"Tell me a story\", \"stream\": true}'"
    echo ""
    echo "🐍 PYTHON EXAMPLE:"
    echo "   import requests"
    echo "   response = requests.post('http://$ip:$OLLAMA_PORT/api/generate',"
    echo "       json={'model': 'llama2', 'prompt': 'Hello!', 'stream': False})"
    echo "   print(response.json()['response'])"
    echo ""
    echo "🟢 SERVICE MANAGEMENT:"
    echo "  Status:  sudo systemctl status ollama-network"
    echo "  Stop:    sudo systemctl stop ollama-network"
    echo "  Start:   sudo systemctl start ollama-network"
    echo "  Restart: sudo systemctl restart ollama-network"
    echo "  Logs:    sudo journalctl -u ollama-network -f"
    echo ""
    echo "📊 MONITORING:"
    echo "  Test connection: curl -s http://$ip:$OLLAMA_PORT/api/tags"
    echo "  Check process:   pgrep -fl ollama"
    echo "  Check port:      ss -tlnp | grep $OLLAMA_PORT"
    echo ""
    
    # Show model-specific examples if models are available
    local models_response
    models_response=$(curl -s "http://localhost:$OLLAMA_PORT/api/tags" 2>/dev/null | jq -r '.models[].name' 2>/dev/null | head -3)
    if [ -n "$models_response" ]; then
        echo "🤖 AVAILABLE MODELS EXAMPLES:"
        while IFS= read -r model; do
            [ -n "$model" ] && echo "   curl -X POST http://$ip:$OLLAMA_PORT/api/generate -H 'Content-Type: application/json' -d '{\"model\": \"$model\", \"prompt\": \"Hello!\", \"stream\": false}'"
        done <<< "$models_response"
        echo ""
    else
        echo "⚠️  NO MODELS INSTALLED YET:"
        echo "   First, install a model on the server:"
        echo "   ollama pull llama2"
        echo "   ollama pull mistral"
        echo "   ollama pull codellama"
        echo ""
    fi
    
    echo "🔒 SECURITY NOTE:"
    echo "   This server is accessible from your entire network."
    echo "   Make sure you're on a trusted network!"
    echo ""
    
    # Final connectivity test
    print_status "Performing final connectivity test..."
    if curl -s --connect-timeout 5 "http://localhost:$OLLAMA_PORT/api/tags" >/dev/null 2>&1; then
        print_success "✅ Server is ready and responding!"
    else
        print_error "❌ Server may not be responding correctly"
        echo "Try: systemctl status ollama-network"
        echo "Logs: journalctl -u ollama-network -f"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --port PORT     Set port (default: 11434)"
    echo "  -h, --help          Show this help message"
    echo "  --stop              Stop the Ollama network service"
    echo "  --status            Show service status"
    echo "  --test              Run comprehensive service tests"
    echo "  --examples          Show API usage examples"
    echo "  --install-model     Install DeepSeek Coder model"
    echo "  --logs              Show service logs"
    echo ""
    echo "Examples:"
    echo "  $0                      Start with default settings"
    echo "  $0 -p 8080             Start on port 8080"
    echo "  $0 --stop              Stop the service"
    echo "  $0 --status            Check service status"
    echo "  $0 --test              Test the running service"
    echo "  $0 --examples          Show curl examples"
    echo "  $0 --install-model     Install DeepSeek Coder model"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            OLLAMA_PORT="$2"
            shift 2
            ;;
        --stop)
            print_status "Stopping Ollama network service..."
            systemctl stop ollama-network.service 2>/dev/null || true
            pkill -f ollama 2>/dev/null || true
            print_success "Ollama network service stopped"
            exit 0
            ;;
        --status)
            echo "Service status:"
            systemctl status ollama-network.service 2>/dev/null || echo "Service not found"
            echo ""
            echo "Process status:"
            pgrep -fl ollama || echo "No Ollama processes running"
            echo ""
            echo "Port status:"
            ss -tlnp | grep ":$OLLAMA_PORT" || echo "Port $OLLAMA_PORT not listening"
            exit 0
            ;;
        --test)
            print_status "Testing Ollama network service..."
            ip=$(get_local_ip)
            echo ""
            echo "🔍 COMPREHENSIVE SERVICE TEST"
            echo "============================="
            
            # Test 1: Process check
            echo "1. Process Status:"
            if pgrep -f "ollama serve" > /dev/null; then
                print_success "✓ Ollama process is running"
                pgrep -fl ollama
            else
                print_error "✗ Ollama process not found"
            fi
            echo ""
            
            # Test 2: Port check
            echo "2. Port Status:"
            if command -v ss >/dev/null 2>&1; then
                port_status=$(ss -tlnp | grep ":$OLLAMA_PORT")
                if [ -n "$port_status" ]; then
                    print_success "✓ Port $OLLAMA_PORT is listening"
                    echo "$port_status"
                else
                    print_error "✗ Port $OLLAMA_PORT is not listening"
                fi
            fi
            echo ""
            
            # Test 3: Local API test
            echo "3. Local API Test:"
            local_test=$(curl -s --connect-timeout 5 "http://localhost:$OLLAMA_PORT/api/tags" 2>/dev/null)
            if [ $? -eq 0 ] && [ -n "$local_test" ]; then
                print_success "✓ Local API responding"
                echo "Response: $(echo "$local_test" | jq -c . 2>/dev/null || echo "$local_test")"
            else
                print_error "✗ Local API not responding"
            fi
            echo ""
            
            # Test 4: Network API test
            echo "4. Network API Test:"
            if [ -n "$ip" ]; then
                network_test=$(curl -s --connect-timeout 5 "http://$ip:$OLLAMA_PORT/api/tags" 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$network_test" ]; then
                    print_success "✓ Network API responding from $ip"
                    echo "Test command: curl -s http://$ip:$OLLAMA_PORT/api/tags"
                else
                    print_error "✗ Network API not responding from $ip"
                fi
            else
                print_warning "⚠ Could not determine local IP address"
            fi
            echo ""
            
            # Test 5: Models check
            echo "5. Available Models:"
            models=$(curl -s "http://localhost:$OLLAMA_PORT/api/tags" 2>/dev/null | jq -r '.models[]?.name' 2>/dev/null)
            if [ -n "$models" ]; then
                print_success "✓ Models available:"
                echo "$models" | sed 's/^/   /'
                echo ""
                echo "Test generation with first model:"
                first_model=$(echo "$models" | head -1)
                echo "curl -X POST http://$ip:$OLLAMA_PORT/api/generate -H 'Content-Type: application/json' -d '{\"model\": \"$first_model\", \"prompt\": \"Hello!\", \"stream\": false}'"
            else
                print_warning "⚠ No models installed"
                echo "Install a model first: ollama pull deepseek-coder"
            fi
            echo ""
            
            # Test 6: Service status
            echo "6. Systemd Service:"
            if systemctl is-active --quiet ollama-network.service 2>/dev/null; then
                print_success "✓ ollama-network service is active"
            else
                print_warning "⚠ ollama-network service is not active"
            fi
            
            if systemctl is-enabled --quiet ollama-network.service 2>/dev/null; then
                print_success "✓ ollama-network service is enabled"
            else
                print_warning "⚠ ollama-network service is not enabled"
            fi
            
            exit 0
            ;;
        --examples)
            ip=$(get_local_ip)
            echo ""
            echo "🧪 OLLAMA API EXAMPLES"
            echo "====================="
            echo ""
            echo "Replace $ip with your server IP address"
            echo ""
            echo "1. 📝 BASIC TEXT GENERATION:"
            echo "curl -X POST http://$ip:$OLLAMA_PORT/api/generate \\"
            echo "     -H 'Content-Type: application/json' \\"
            echo "     -d '{\"model\": \"deepseek-coder\", \"prompt\": \"Write a Python function to sort a list\", \"stream\": false}'"
            echo ""
            echo "2. 💬 CHAT CONVERSATION:"
            echo "curl -X POST http://$ip:$OLLAMA_PORT/api/chat \\"
            echo "     -H 'Content-Type: application/json' \\"
            echo "     -d '{\"model\": \"deepseek-coder\", \"messages\": [{\"role\": \"user\", \"content\": \"Explain recursion in programming\"}], \"stream\": false}'"
            echo ""
            echo "3. 📋 LIST MODELS:"
            echo "curl -s http://$ip:$OLLAMA_PORT/api/tags | jq '.models[].name'"
            echo ""
            echo "4. 📥 PULL MODEL:"
            echo "curl -X POST http://$ip:$OLLAMA_PORT/api/pull \\"
            echo "     -H 'Content-Type: application/json' \\"
            echo "     -d '{\"name\": \"deepseek-coder:latest\"}'"
            echo ""
            echo "5. 🔍 MODEL INFO:"
            echo "curl -X POST http://$ip:$OLLAMA_PORT/api/show \\"
            echo "     -H 'Content-Type: application/json' \\"
            echo "     -d '{\"name\": \"deepseek-coder\"}'"
            echo ""
            echo "6. 🌊 STREAMING RESPONSE:"
            echo "curl -X POST http://$ip:$OLLAMA_PORT/api/generate \\"
            echo "     -H 'Content-Type: application/json' \\"
            echo "     -d '{\"model\": \"deepseek-coder\", \"prompt\": \"Create a REST API in Python\", \"stream\": true}'"
            echo ""
            echo "7. 🐍 PYTHON CLIENT:"
            echo "import requests"
            echo "import json"
            echo ""
            echo "def ask_ollama(prompt, model='deepseek-coder'):"
            echo "    response = requests.post(f'http://$ip:$OLLAMA_PORT/api/generate', json={"
            echo "        'model': model,"
            echo "        'prompt': prompt,"
            echo "        'stream': False"
            echo "    })"
            echo "    return response.json()['response']"
            echo ""
            echo "# Usage"
            echo "answer = ask_ollama('How to create a web server in Python?')"
            echo "print(answer)"
            echo ""
            exit 0
            ;;
        --install-model)
            print_status "Installing DeepSeek Coder model..."
            
            # Check if Ollama is running
            if ! pgrep -f "ollama serve" > /dev/null; then
                print_error "Ollama is not running. Start it first with: $0"
                exit 1
            fi
            
            # Install model
            echo "Downloading DeepSeek Coder model..."
            ollama pull deepseek-coder:1.3b || ollama pull deepseek-coder || {
                print_error "Failed to install model"
                exit 1
            }
            
            print_success "Model installed successfully!"
            ollama list
            exit 0
            ;;
        --logs)
            journalctl -u ollama-network -f
            exit 0
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo "========================================"
    echo "      Ollama Network Server Setup      "
    echo "========================================"
    echo ""
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root is not recommended"
    fi
    
    # Check prerequisites
    check_ollama
    print_status "Continuing with setup..."
    
    # Stop existing services
    stop_ollama
    print_status "Proceeding to firewall configuration..."
    
    # Configure firewall
    configure_firewall
    print_status "Proceeding to service creation..."
    
    # Create systemd service
    create_systemd_service
    print_status "Proceeding to start server..."
    
    # Start server
    start_ollama_server
    print_status "Proceeding to test server..."
    
    # Test server
    test_server
    print_status "Proceeding to install model..."
    
    # Install default model if none exists
    install_default_model
    print_status "Proceeding to show connection info..."
    
    # Show connection information
    show_connection_info
    
    print_success "Setup completed successfully!"
}

# Run main function
main "$@"
