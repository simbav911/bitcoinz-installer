#!/bin/bash

set -e

echo "===================================="
echo "         BitcoinZ Installer"
echo "===================================="
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (use sudo)."
    exit 1
fi

# Update package lists
echo "Running apt-get update..."
apt-get update -qq

# Install required dependencies
# wget, openssl, coreutils (for sha256sum), tar, p7zip-full (for 7z), systemctl (usually included with systemd)
echo "Installing required dependencies..."
DEPS="wget openssl coreutils tar p7zip-full"
if ! apt-get install -y $DEPS; then
    echo "ERROR: Failed to install required packages ($DEPS). Please install them manually and re-run the script."
    exit 1
fi

# Check for systemd/systemctl
if ! command -v systemctl &> /dev/null; then
    echo "ERROR: 'systemctl' not found. This script requires a systemd-based system."
    exit 1
fi

# Verify 7z is available after installation
if ! command -v 7z &> /dev/null; then
    echo "ERROR: 7z command not found even after installation."
    echo "Please manually install p7zip-full and re-run the script."
    exit 1
fi

# Variables
DAEMON_URL="https://github.com/btcz/bitcoinz/releases/download/2.1.0/bitcoinz-c73d5cdb2b70-x86_64-linux-gnu.tar.gz"
DATA_DIR="/root/.bitcoinz"
TEMP_DIR=$(mktemp -d)

echo "Downloading BitcoinZ daemon from:"
echo "$DAEMON_URL"
echo "Please wait, downloading..."
if ! wget --progress=bar:force:noscroll "$DAEMON_URL" -O "$TEMP_DIR/bitcoinzd.tar.gz"; then
    echo "ERROR: Failed to download BitcoinZ daemon."
    rm -rf "$TEMP_DIR"
    exit 1
fi
echo "Download complete."

echo "Extracting BitcoinZ daemon..."
if ! tar xzf "$TEMP_DIR/bitcoinzd.tar.gz" -C "$TEMP_DIR"; then
    echo "ERROR: Failed to extract BitcoinZ daemon."
    rm -rf "$TEMP_DIR"
    exit 1
fi
echo "Extraction complete."

echo "Installing BitcoinZ binaries to /usr/local/bin..."
BINDIR="/usr/local/bin"
for binfile in "$TEMP_DIR"/*/bin/bitcoinzd "$TEMP_DIR"/*/bin/bitcoinz-cli "$TEMP_DIR"/bitcoinzd "$TEMP_DIR"/bitcoinz-cli; do
    if [ -f "$binfile" ]; then
        cp "$binfile" "$BINDIR/"
        chmod +x "$BINDIR/$(basename "$binfile")"
        echo "Installed $(basename "$binfile")"
    fi
done

# Clean up temporary directory
rm -rf "$TEMP_DIR"

echo "Creating $DATA_DIR directory..."
mkdir -p "$DATA_DIR"

echo "Generating random RPC credentials..."
RPCUSER=$(openssl rand -hex 8)
RPCPASS=$(openssl rand -hex 16)
echo "RPC credentials generated."

echo "Creating bitcoinz.conf..."
cat << EOF > "$DATA_DIR/bitcoinz.conf"
rpcuser=$RPCUSER
rpcpassword=$RPCPASS
rpcport=1979
rpcbind=localhost
rpcconnect=localhost
rpcallowip=127.0.0.1
txindex=1
listen=1
server=1
addnode=explorer.btcz.app:1989
addnode=explorer.btcz.rocks:1989
addnode=37.187.76.80:1989
addnode=198.100.154.162:1989
addnode=45.32.135.197:1989
EOF

chmod 600 "$DATA_DIR/bitcoinz.conf"
echo "Configuration file created and secured."

echo
read -p "Would you like to download and apply the bootstrap.dat to speed up initial sync? (y/N): " BOOTSTRAP_CHOICE

if [[ "$BOOTSTRAP_CHOICE" =~ ^[Yy]$ ]]; then
    echo "Preparing to download and apply bootstrap..."
    BOOTSTRAP_DIR=$(mktemp -d)

    # Bootstrap files and their checksums
    declare -A BOOTSTRAP_FILES=(
        ["bootstrap.dat.7z.001"]="7ccef0dd7d3090fd3424bad0cc368901a92217ad190eb81817686fae1bf6943f"
        ["bootstrap.dat.7z.002"]="4d04d24b02af9bec30f072bb845f21b1dc165387e0d365a76982104e61f89376"
        ["bootstrap.dat.7z.003"]="0db5bed761b9aa5f7c36f564395dcbc50d6dc6c839f367efc182d8f93df2e5a0"
        ["bootstrap.dat.7z.004"]="7c1d70908fbb063df2cc909e487cec2bba9b5eb9c767c92d2427abd897fd5bb5"
    )

    BASE_URL="https://github.com/btcz/bootstrap/releases/download/2024-09-04"

    for part in 001 002 003 004; do
        FILE="bootstrap.dat.7z.$part"
        echo
        echo "Downloading $FILE..."
        if ! wget --progress=bar:force:noscroll "$BASE_URL/$FILE" -O "$BOOTSTRAP_DIR/$FILE"; then
            echo "ERROR: Failed to download $FILE."
            rm -rf "$BOOTSTRAP_DIR"
            exit 1
        fi
        echo "Download complete. Verifying checksum of $FILE..."
        echo "${BOOTSTRAP_FILES[$FILE]}  $BOOTSTRAP_DIR/$FILE" | sha256sum -c -
        echo "Checksum verified for $FILE."
    done

    echo
    echo "Combining bootstrap parts into one archive..."
    cat "$BOOTSTRAP_DIR/bootstrap.dat.7z."* > "$BOOTSTRAP_DIR/bootstrap.dat.7z"
    echo "Combination complete."

    echo "Extracting bootstrap.dat (this may take a while)..."
    if ! 7z x -o"$BOOTSTRAP_DIR" "$BOOTSTRAP_DIR/bootstrap.dat.7z" > /dev/null; then
        echo "ERROR: Failed to extract bootstrap.dat"
        rm -rf "$BOOTSTRAP_DIR"
        exit 1
    fi

    if [ -f "$BOOTSTRAP_DIR/bootstrap.dat" ]; then
        echo "Moving bootstrap.dat to $DATA_DIR"
        mv "$BOOTSTRAP_DIR/bootstrap.dat" "$DATA_DIR/"
        echo "Bootstrap.dat successfully placed in $DATA_DIR"
    else
        echo "ERROR: bootstrap.dat not found after extraction."
        rm -rf "$BOOTSTRAP_DIR"
        exit 1
    fi

    rm -rf "$BOOTSTRAP_DIR"
else
    echo "Skipping bootstrap installation..."
fi

echo
echo "Creating systemd service file at /etc/systemd/system/bitcoinz.service..."
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
WorkingDirectory=$DATA_DIR
Restart=always
TimeoutStopSec=300
RestartSec=30
StartLimitInterval=350
StartLimitBurst=10

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling and starting bitcoinz.service..."
systemctl enable bitcoinz.service
systemctl start bitcoinz.service

echo
echo "===================================="
echo " BitcoinZ installation complete!"
echo "===================================="
echo "RPC Credentials (please save these):"
echo "RPC User: $RPCUSER"
echo "RPC Password: $RPCPASS"
echo
echo "You can check the daemon status with:"
echo "  systemctl status bitcoinz"
echo
echo "If you included the bootstrap, your node will now begin importing blocks."
echo "This may take some time. You can monitor progress in:"
echo "  $DATA_DIR/debug.log"
echo
echo "All done!"
