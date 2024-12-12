#!/bin/bash

# Exit on error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Placeholder URL for BitcoinZ daemon
DAEMON_URL="https://github.com/btcz/bitcoinz/releases/download/2.1.0/bitcoinz-c73d5cdb2b70-x86_64-linux-gnu.tar.gz"
TEMP_DIR=$(mktemp -d)

# Download the BitcoinZ daemon
echo "Downloading BitcoinZ daemon..."
if ! wget -q "$DAEMON_URL" -O "$TEMP_DIR/bitcoinzd.tar.gz"; then
    echo "Failed to download BitcoinZ daemon"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Extract the daemon
echo "Extracting BitcoinZ daemon..."
cd "$TEMP_DIR"
if ! tar xzf bitcoinzd.tar.gz; then
    echo "Failed to extract BitcoinZ daemon"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Copy binaries to /usr/local/bin
echo "Installing BitcoinZ binaries..."
find . -type f -name "bitcoinzd" -o -name "bitcoinz-cli" | while read file; do
    cp "$file" /usr/local/bin/
    chmod +x "/usr/local/bin/$(basename "$file")"
done

# Clean up temporary directory
rm -rf "$TEMP_DIR"

# Create .bitcoinz directory
echo "Creating .bitcoinz directory..."
mkdir -p /root/.bitcoinz

# Generate random credentials
RPCUSER=$(openssl rand -hex 8)
RPCPASS=$(openssl rand -hex 16)

# Create bitcoinz.conf
echo "Creating bitcoinz.conf..."
cat << EOF > /root/.bitcoinz/bitcoinz.conf
rpcuser=$RPCUSER
rpcpassword=$RPCPASS
rpcport=1979
rpcallowip=0.0.0.0/0
txindex=1
listen=1
server=1
addnode=explorer.btcz.app:1989
addnode=explorer.btcz.rocks:1989
addnode=37.187.76.80:1989
addnode=198.100.154.162:1989
addnode=45.32.135.197:1989
EOF

# Secure the config file
chmod 600 /root/.bitcoinz/bitcoinz.conf

# Create systemd service file
echo "Creating bitcoinz.service..."
cat << EOF > /etc/systemd/system/bitcoinz.service
[Unit]
Description=BitcoinZ Daemon
After=network.target

[Service]
User=root
Group=root
Type=simple
Environment=HOME=/root
ExecStart=/usr/local/bin/bitcoinzd
ExecStop=/usr/local/bin/bitcoinz-cli stop
WorkingDirectory=/root/.bitcoinz
Restart=always
TimeoutStopSec=300
RestartSec=30
StartLimitInterval=350
StartLimitBurst=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable and start the service
echo "Enabling and starting bitcoinz.service..."
systemctl enable bitcoinz.service
systemctl start bitcoinz.service

echo "BitcoinZ installation complete!"
echo "RPC Credentials (save these):"
echo "RPC User: $RPCUSER"
echo "RPC Password: $RPCPASS"