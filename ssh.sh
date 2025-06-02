#!/bin/bash

# SSH connection script with authentication failure fix and key management
# Usage: ./ssh.sh root@hostname_or_ip

# Check if argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 user@hostname"
    echo "Example: $0 root@192.168.1.1"
    exit 1
fi

TARGET="$1"
ED25519_KEY="$HOME/.ssh/id_ed25519"
ED25519_PUB="$HOME/.ssh/id_ed25519.pub"

echo "Connecting to $TARGET with authentication fixes..."

# Check if ED25519 key exists, if not generate it
if [ ! -f "$ED25519_KEY" ]; then
    echo "ED25519 key not found. Generating new key..."
    ssh-keygen -t ed25519 -f "$ED25519_KEY" -N "" -C "$(whoami)@$(hostname)"
    echo "ED25519 key generated successfully."
fi

# Function to copy SSH key to remote host
copy_ssh_key() {
    echo "Copying SSH key to $TARGET..."
    ssh-copy-id -i "$ED25519_PUB" -o IdentitiesOnly=yes -o PreferredAuthentications=password "$TARGET"
    return $?
}

# Try to copy SSH key first (will prompt for password)
copy_ssh_key

# If key copy was successful, connect using the ED25519 key
if [ $? -eq 0 ]; then
    echo "SSH key copied successfully. Connecting with key authentication..."
    ssh -o IdentitiesOnly=yes \
        -o IdentityFile="$ED25519_KEY" \
        -o PreferredAuthentications=publickey \
        "$TARGET"
else
    echo "Key copy failed. Trying password authentication methods..."
    
    # Method 1: Password authentication only
    ssh -o IdentitiesOnly=yes \
        -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no \
        -o NumberOfPasswordPrompts=3 \
        -o ConnectTimeout=10 \
        "$TARGET"
    
    # If password auth fails, try with existing keys
    if [ $? -ne 0 ]; then
        echo "Password authentication failed. Trying with ED25519 key..."
        ssh -o IdentitiesOnly=yes \
            -o IdentityFile="$ED25519_KEY" \
            -o PreferredAuthentications=publickey,password \
            -o NumberOfPasswordPrompts=3 \
            "$TARGET"
    fi
fi

# If still failing, provide troubleshooting info
if [ $? -ne 0 ]; then
    echo ""
    echo "Connection failed. Troubleshooting steps:"
    echo "1. Clear known hosts entry: ssh-keygen -R ${TARGET#*@}"
    echo "2. Check SSH agent: ssh-add -l"
    echo "3. Clear SSH agent: ssh-add -D"
    echo "4. Try manual connection: ssh -v $TARGET"
    echo "5. Manually copy key: ssh-copy-id -i $ED25519_PUB $TARGET"
    echo ""
    echo "Key information:"
    echo "- ED25519 private key: $ED25519_KEY"
    echo "- ED25519 public key: $ED25519_PUB"
    echo ""
    echo "Common fixes:"
    echo "- ssh-keygen -R ${TARGET#*@}"
    echo "- ssh-add -D"
    echo "- ssh-copy-id -i $ED25519_PUB $TARGET"
    echo "- ssh -o IdentitiesOnly=yes -i $ED25519_KEY $TARGET"
fi
