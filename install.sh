#!/bin/bash

# Linux Installation Script for PDF Translation Tool
# This script installs all required dependencies for the PDF translation tool

echo "====================================="
echo "PDF Translation Tool - Dependencies Installer"
echo "====================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_warning "This script is running as root. Some operations may require non-root privileges."
fi

# Detect Linux distribution
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
else
    print_error "Cannot detect Linux distribution"
    exit 1
fi

print_info "Detected distribution: $DISTRO $VERSION"

# Update package manager
echo -e "\n${YELLOW}Updating package manager...${NC}"
case $DISTRO in
    ubuntu|debian)
        sudo apt update
        ;;
    fedora)
        sudo dnf update -y
        ;;
    centos|rhel)
        sudo yum update -y
        ;;
    arch|manjaro)
        sudo pacman -Syu --noconfirm
        ;;
    *)
        print_warning "Unknown distribution. Please update your package manager manually."
        ;;
esac

# Install system dependencies
echo -e "\n${YELLOW}Installing system dependencies...${NC}"
case $DISTRO in
    ubuntu|debian)
        sudo apt install -y python3 python3-pip python3-dev python3-venv curl wget
        ;;
    fedora)
        sudo dnf install -y python3 python3-pip python3-devel curl wget
        ;;
    centos|rhel)
        sudo yum install -y python3 python3-pip python3-devel curl wget
        ;;
    arch|manjaro)
        sudo pacman -S --noconfirm python python-pip curl wget
        ;;
    *)
        print_error "Please install Python 3, pip, curl, and wget manually for your distribution"
        exit 1
        ;;
esac

# Check if Python is installed
echo -e "\n${YELLOW}Checking Python installation...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    print_status "Python found: $PYTHON_VERSION"
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_VERSION=$(python --version)
    print_status "Python found: $PYTHON_VERSION"
    PYTHON_CMD="python"
else
    print_error "Python is not installed!"
    exit 1
fi

# Check if pip is available
echo -e "\n${YELLOW}Checking pip installation...${NC}"
if command -v pip3 &> /dev/null; then
    PIP_VERSION=$(pip3 --version)
    print_status "Pip found: $PIP_VERSION"
    PIP_CMD="pip3"
elif command -v pip &> /dev/null; then
    PIP_VERSION=$(pip --version)
    print_status "Pip found: $PIP_VERSION"
    PIP_CMD="pip"
else
    print_error "pip is not available!"
    exit 1
fi

# Upgrade pip
echo -e "\n${YELLOW}Upgrading pip to latest version...${NC}"
$PYTHON_CMD -m pip install --upgrade pip --user

# Install Python packages
echo -e "\n${YELLOW}Installing Python dependencies...${NC}"

packages=(
    "pdfplumber"
    "python-docx"
    "transformers"
    "torch"
    "torchvision"
    "torchaudio"
)

for package in "${packages[@]}"; do
    echo -e "${CYAN}Installing $package...${NC}"
    if $PIP_CMD install "$package" --user; then
        print_status "$package installed successfully"
    else
        print_error "Failed to install $package"
    fi
done

# Install Ollama
echo -e "\n${YELLOW}Checking Ollama installation...${NC}"
if command -v ollama &> /dev/null; then
    OLLAMA_VERSION=$(ollama --version)
    print_status "Ollama found: $OLLAMA_VERSION"
else
    echo -e "${YELLOW}Ollama not found. Installing Ollama...${NC}"
    
    # Download and install Ollama
    if curl -fsSL https://ollama.com/install.sh | sh; then
        print_status "Ollama installed successfully"
        
        # Add ollama to PATH if not already there
        if ! command -v ollama &> /dev/null; then
            export PATH="/usr/local/bin:$PATH"
            echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
            print_info "Added Ollama to PATH. You may need to restart your terminal."
        fi
    else
        print_error "Failed to install Ollama"
        print_info "Please install manually from: https://ollama.com/download/linux"
    fi
fi

# Start Ollama service if systemd is available
if command -v systemctl &> /dev/null; then
    echo -e "\n${YELLOW}Starting Ollama service...${NC}"
    if sudo systemctl start ollama 2>/dev/null; then
        print_status "Ollama service started"
        sudo systemctl enable ollama
        print_status "Ollama service enabled for startup"
    else
        print_warning "Could not start Ollama service (may not be available)"
        print_info "You can start Ollama manually with: ollama serve"
    fi
fi

# Wait a moment for Ollama to start
sleep 2

# Download required Ollama models
echo -e "\n${YELLOW}Downloading required Ollama models...${NC}"
echo -e "${CYAN}This may take a while depending on your internet connection...${NC}"

models=(
    "gemma2:27b"
    "deepseek-r1:32b"
    "llama3.1:latest"
)

for model in "${models[@]}"; do
    echo -e "${CYAN}Downloading $model...${NC}"
    if timeout 300 ollama pull "$model" 2>/dev/null; then
        print_status "$model downloaded successfully"
    else
        print_error "Failed to download $model"
        print_info "You can download it later with: ollama pull $model"
    fi
done

# Installation summary
echo -e "\n====================================="
echo -e "${GREEN}Installation Summary${NC}"
echo -e "====================================="

echo -e "\n${YELLOW}Python packages installed:${NC}"
for package in "${packages[@]}"; do
    if $PIP_CMD show "$package" &> /dev/null; then
        VERSION=$($PIP_CMD show "$package" | grep Version | cut -d' ' -f2)
        print_status "$package ($VERSION)"
    else
        print_error "$package (not found)"
    fi
done

echo -e "\n${YELLOW}Ollama models:${NC}"
for model in "${models[@]}"; do
    if ollama list 2>/dev/null | grep -q "${model%%:*}"; then
        print_status "$model"
    else
        print_error "$model (not downloaded)"
    fi
done

echo -e "\n====================================="
echo -e "${GREEN}Installation completed!${NC}"
echo -e "${YELLOW}You can now run the translation script:${NC}"
echo -e "${CYAN}$PYTHON_CMD translate.py${NC}"
echo -e "====================================="

# Check if Ollama service is running
if ! pgrep -x "ollama" > /dev/null; then
    echo -e "\n${YELLOW}Note: Ollama service is not running.${NC}"
    echo -e "${CYAN}Start it with: ollama serve${NC}"
    echo -e "${CYAN}Or run in background: nohup ollama serve &${NC}"
fi