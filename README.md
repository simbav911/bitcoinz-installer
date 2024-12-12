# BitcoinZ Installation Script

This script automates the installation and setup of the BitcoinZ daemon on a Linux system. It handles the complete setup process including downloading the daemon, configuring it, and setting up the systemd service.

## Features

- Automatic download and installation of BitcoinZ daemon
- Secure configuration with random RPC credentials
- Systemd service setup for automatic startup
- Error handling and validation
- Proper file permissions and security measures

## Requirements

- Linux operating system
- Root access (sudo)
- wget
- systemd
- openssl

## Installation

1. Download the script:
```bash
wget https://raw.githubusercontent.com/simbav911/bitcoinz-installer/main/install_bitcoinz.sh
```

2. Make it executable:
```bash
chmod +x install_bitcoinz.sh
```

3. Run the script:
```bash
sudo ./install_bitcoinz.sh
```

## What the Script Does

1. Downloads the latest BitcoinZ daemon
2. Creates necessary directories and configuration files
3. Generates secure random RPC credentials
4. Sets up a systemd service for automatic startup
5. Starts the BitcoinZ daemon

## Configuration

The script creates two main configuration files:

- `/root/.bitcoinz/bitcoinz.conf`: Contains the BitcoinZ daemon configuration
- `/etc/systemd/system/bitcoinz.service`: Contains the systemd service configuration

The RPC credentials are randomly generated during installation and displayed at the end of the installation process. Make sure to save these credentials.

## Service Management

After installation, you can manage the BitcoinZ daemon using these commands:

```bash
# Start the daemon
sudo systemctl start bitcoinz.service

# Stop the daemon
sudo systemctl stop bitcoinz.service

# Check status
sudo systemctl status bitcoinz.service

# View logs
sudo journalctl -u bitcoinz.service
```

## Security Notes

- The script generates random RPC credentials for security
- Configuration file permissions are set to 600 (readable only by root)
- The daemon runs as root for proper access to the system

## Troubleshooting

If you encounter any issues:

1. Check the service status:
```bash
sudo systemctl status bitcoinz.service
```

2. View the logs:
```bash
sudo journalctl -u bitcoinz.service -n 50
```

## Contributing

If you have any suggestions or improvements for this script, feel free to submit a pull request or create an issue.

## License

This script is provided as-is under the MIT license. Use at your own risk.