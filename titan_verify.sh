#!/bin/bash
# TITAN VISION OS - System Verification Script
# Tests all components before launch

echo "╔═══════════════════════════════════════════╗"
echo "║   TITAN VISION - SYSTEM VERIFICATION     ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
        ((PASS++))
    else
        echo -e "${RED}✗${NC} $1"
        ((FAIL++))
    fi
}

echo "CHECKING DEPENDENCIES..."
echo "------------------------"

# Check compilers
command -v zig > /dev/null 2>&1
check "Zig compiler installed"

command -v rustc > /dev/null 2>&1
check "Rust compiler installed"

command -v julia > /dev/null 2>&1
check "Julia installed"

command -v python3 > /dev/null 2>&1
check "Python3 installed"

command -v go > /dev/null 2>&1
check "Go installed"

echo ""
echo "CHECKING BUILD ARTIFACTS..."
echo "----------------------------"

[ -f "zig-out/lib/libtitan_metal.so" ] || [ -f "zig-out/lib/libtitan_metal.dylib" ]
check "Zig metal library built"

[ -f "target/release/libtitan_engine.so" ] || [ -f "target/release/libtitan_engine.dylib" ]
check "Rust engine library built"

[ -f "titan_brain.jl" ]
check "Julia brain script present"

[ -f "titan_injection.py" ]
check "Python orchestrator present"

echo ""
echo "CHECKING HARDWARE..."
echo "--------------------"

# Check for V4L2 devices
if ls /dev/video* > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Video devices found:"
    ls -1 /dev/video* | while read dev; do
        echo "    $dev"
    done
else
    echo -e "${YELLOW}⚠${NC}  No video devices found. Attach camera or run usbipd."
fi

# Check virtual camera module
if lsmod | grep -q v4l2loopback; then
    echo -e "${GREEN}✓${NC} Virtual camera driver loaded"
else
    echo -e "${YELLOW}⚠${NC}  Virtual camera driver not loaded"
    echo "    Run: sudo modprobe v4l2loopback video_nr=10 card_label=\"TitanVision\""
fi

echo ""
echo "CHECKING SYSTEM RESOURCES..."
echo "-----------------------------"

# Check CPU cores
CORES=$(nproc)
echo "CPU Cores: $CORES"
if [ $CORES -ge 8 ]; then
    echo -e "${GREEN}✓${NC} Sufficient CPU cores"
else
    echo -e "${YELLOW}⚠${NC}  Low CPU cores (recommended: 8+)"
fi

# Check RAM
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
echo "Total RAM: ${TOTAL_RAM}GB"
if [ $TOTAL_RAM -ge 8 ]; then
    echo -e "${GREEN}✓${NC} Sufficient RAM"
else
    echo -e "${YELLOW}⚠${NC}  Low RAM (recommended: 8GB+)"
fi

echo ""
echo "TESTING COMPONENT INTEGRATION..."
echo "---------------------------------"

# Test Zig library load
python3 -c "
from ctypes import CDLL
try:
    lib = CDLL('./zig-out/lib/libtitan_metal.so')
    print('${GREEN}✓${NC} Zig library loads correctly')
except:
    print('${RED}✗${NC} Zig library failed to load')
" 2>/dev/null

# Test Rust library load
python3 -c "
from ctypes import CDLL
try:
    lib = CDLL('./target/release/libtitan_engine.so')
    print('${GREEN}✓${NC} Rust library loads correctly')
except:
    print('${RED}✗${NC} Rust library failed to load')
" 2>/dev/null

# Test Julia
julia -e "println(\"${GREEN}✓${NC} Julia runtime functional\")" 2>/dev/null || echo -e "${RED}✗${NC} Julia runtime error"

echo ""
echo "═══════════════════════════════════════════"
echo "VERIFICATION SUMMARY"
echo "═══════════════════════════════════════════"
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}System ready for launch!${NC}"
    echo "Run: ./run_titan.sh"
else
    echo -e "${YELLOW}Some checks failed. Review above.${NC}"
    echo "Run: ./titan_build.sh to rebuild"
fi

echo ""
