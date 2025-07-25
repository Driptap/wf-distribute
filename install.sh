#!/bin/bash

# Water Freedom Smart System Installation Script
# Usage: curl -o- https://raw.githubusercontent.com/Driptap/wf-distribute/main/install.sh | bash

set -e  # Exit on any error

# Configuration
REPO_URL="https://github.com/Driptap/wf-distribute"
RELEASE_URL="https://github.com/Driptap/wf-distribute/releases/download/0.0.4"
PACKAGE_NAME="water-freedom-smart-system_0.0.4_arm64.deb"
APP_NAME="Water Freedom Smart System"
EXECUTABLE_NAME="water-freedom-smart-system"  # Adjust this to your actual executable name

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on supported architecture
check_architecture() {
    ARCH=$(uname -m)
    if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
        print_error "This package is designed for ARM64 architecture. Detected: $ARCH"
        exit 1
    fi
    print_status "Architecture check passed: $ARCH"
}

# Check if running as root or with sudo access
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root"
        SUDO_CMD=""
    else
        if ! command -v sudo &> /dev/null; then
            print_error "sudo is required but not installed"
            exit 1
        fi
        SUDO_CMD="sudo"
        print_status "Will use sudo for installation"
    fi
}

# Download the .deb package
download_package() {
    print_status "Downloading $PACKAGE_NAME..."

    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    # Download the package
    if command -v curl &> /dev/null; then
        curl -L -o "$PACKAGE_NAME" "$RELEASE_URL/$PACKAGE_NAME"
    elif command -v wget &> /dev/null; then
        wget -O "$PACKAGE_NAME" "$RELEASE_URL/$PACKAGE_NAME"
    else
        print_error "Neither curl nor wget is available. Please install one of them."
        exit 1
    fi

    print_status "Package downloaded successfully"
}

# Install the package
install_package() {
    print_status "Installing $PACKAGE_NAME..."

    # Update package index
    $SUDO_CMD apt-get update

    # Install the package
    $SUDO_CMD dpkg -i "$PACKAGE_NAME"

    # Fix any dependency issues
    $SUDO_CMD apt-get install -f -y

    print_status "Package installed successfully"
}

# Create desktop entry
create_desktop_entry() {
    print_status "Creating desktop entry..."

    # Desktop entry content
    DESKTOP_ENTRY="[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Comment=Water Freedom Smart System Application
Exec=/usr/bin/$EXECUTABLE_NAME"

    # Create desktop entry
    DESKTOP_FILE="/usr/share/applications/$EXECUTABLE_NAME.desktop"
    echo "$DESKTOP_ENTRY" | $SUDO_CMD tee "$DESKTOP_FILE" > /dev/null

    # Make it executable
    $SUDO_CMD chmod +x "$DESKTOP_FILE"

    # Also create a user desktop entry if not root
    if [[ $EUID -ne 0 ]]; then
        USER_DESKTOP_DIR="$HOME/.config/autostart"
        mkdir -p "$USER_DESKTOP_DIR"
        echo "$DESKTOP_ENTRY" > "$USER_DESKTOP_DIR/$EXECUTABLE_NAME.desktop"
        chmod +x "$USER_DESKTOP_DIR/$EXECUTABLE_NAME.desktop"
        print_status "Desktop entry created for user"
    fi

    print_status "Desktop entry created successfully"
}

# Configure systemd service (optional)
configure_service() {
    print_status "Configuring systemd service..."

    # Check if service file exists
    if [[ -f "/etc/systemd/system/$EXECUTABLE_NAME.service" ]]; then
        $SUDO_CMD systemctl daemon-reload
        $SUDO_CMD systemctl enable "$EXECUTABLE_NAME.service"
        print_status "Service enabled"
    else
        print_warning "No systemd service file found, skipping service configuration"
    fi
}

# Cleanup temporary files
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

# Main installation function
main() {
    print_status "Starting Water Freedom Smart System installation..."

    # Run checks
    check_architecture
    check_permissions

    # Install
    download_package
    install_package
    create_desktop_entry
    configure_service

    # Cleanup
    cleanup

    print_status "Installation completed successfully!"
    print_status "You can now find '$APP_NAME' in your applications menu"
    print_status "Or run it from terminal with: $EXECUTABLE_NAME"

    # Optional: Start the service if it exists
    if systemctl list-unit-files | grep -q "$EXECUTABLE_NAME.service"; then
        print_status "Starting service..."
        $SUDO_CMD systemctl start "$EXECUTABLE_NAME.service"
    fi
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
