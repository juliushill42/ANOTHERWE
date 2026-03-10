#!/bin/bash
# TITAN VISION OS - UNICORN 32 BUILD
# Master Installation Script for Ubuntu
# Copyright © Julius Cameron Hill

set -e

echo "=========================================="
echo "  TITAN VISION OS - UNICORN 32 BUILD"
echo "  Initializing Multi-Language Stack..."
echo "=========================================="

# 1. FIX WSL PATH ISSUES
echo "[1/10] Fixing WSL PATH configuration..."
if ! grep -q "appendWindowsPath = false" /etc/wsl.conf 2>/dev/null; then
    sudo bash -c 'cat >> /etc/wsl.conf << EOF
[interop]
appendWindowsPath = false
EOF'
    echo "WSL PATH fixed. Please restart WSL after this script completes."
fi

# 2. SYSTEM DEPENDENCIES
echo "[2/10] Installing system dependencies..."
sudo apt update
sudo apt install -y \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    git \
    curl \
    wget \
    v4l-utils \
    linux-tools-virtual \
    hwdata \
    ffmpeg \
    python3-pip \
    python3-venv

# 3. RUST INSTALLATION
echo "[3/10] Installing Rust toolchain..."
if ! command -v rustc &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# 4. ZIG INSTALLATION (Latest stable)
echo "[4/10] Installing Zig compiler..."
if ! command -v zig &> /dev/null; then
    ZIG_VERSION="0.13.0"
    wget "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz"
    sudo tar -xf "zig-linux-x86_64-${ZIG_VERSION}.tar.xz" -C /usr/local/
    sudo ln -sf "/usr/local/zig-linux-x86_64-${ZIG_VERSION}/zig" /usr/local/bin/zig
    rm "zig-linux-x86_64-${ZIG_VERSION}.tar.xz"
fi

# 5. GO INSTALLATION
echo "[5/10] Installing Go..."
if ! command -v go &> /dev/null; then
    GO_VERSION="1.22.0"
    wget "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
    rm "go${GO_VERSION}.linux-amd64.tar.gz"
fi

# 6. JULIA INSTALLATION
echo "[6/10] Installing Julia..."
if ! command -v julia &> /dev/null; then
    JULIA_VERSION="1.10.0"
    wget "https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-${JULIA_VERSION}-linux-x86_64.tar.gz"
    sudo tar -xzf "julia-${JULIA_VERSION}-linux-x86_64.tar.gz" -C /opt/
    sudo ln -sf "/opt/julia-${JULIA_VERSION}/bin/julia" /usr/local/bin/julia
    rm "julia-${JULIA_VERSION}-linux-x86_64.tar.gz"
fi

# 7. PYTHON DEPENDENCIES
echo "[7/10] Setting up Python environment..."
python3 -m venv ~/titan_venv
source ~/titan_venv/bin/activate
pip install --upgrade pip
pip install opencv-python-headless numpy pyvirtualcam

# 8. JULIA PACKAGES
echo "[8/10] Installing Julia packages..."
julia -e 'using Pkg; Pkg.add(["Whisper", "WAV", "SignalAnalysis", "PackageCompiler", "FFTW"])'

# 9. V4L2LOOPBACK (Virtual Camera)
echo "[9/10] Setting up virtual camera driver..."
if ! lsmod | grep -q v4l2loopback; then
    sudo apt install -y v4l2loopback-dkms
    sudo modprobe v4l2loopback video_nr=10 card_label="TitanVision" exclusive_caps=1
    echo "v4l2loopback" | sudo tee -a /etc/modules-load.d/modules.conf
fi

# 10. WAILS (Go GUI Framework)
echo "[10/10] Installing Wails framework..."
if ! command -v wails &> /dev/null; then
    go install github.com/wailsapp/wails/v2/cmd/wails@latest
    echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
    export PATH=$PATH:$HOME/go/bin
fi

echo ""
echo "=========================================="
echo "  TITAN VISION OS - Installation Complete"
echo "=========================================="
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1. If WSL config was updated, run: wsl --shutdown (from Windows)"
echo "2. Restart Ubuntu terminal"
echo "3. Run: source ~/.bashrc"
echo "4. Verify camera connection: lsusb"
echo "5. Launch build: ./titan_build.sh"
echo ""
echo "System is ready for Titan Vision deployment."
