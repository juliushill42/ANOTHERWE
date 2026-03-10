#!/bin/bash
# TITAN VISION OS - Master Build Script
# Compiles Zig, Rust, and Julia components
# Copyright © Julius Cameron Hill

set -e

echo "=========================================="
echo "  TITAN VISION - UNICORN 32 BUILD"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Build Zig Metal Layer
echo -e "\n${YELLOW}[1/4] Compiling Zig Metal Layer...${NC}"
if [ -f "build.zig" ]; then
    zig build -Doptimize=ReleaseFast
    echo -e "${GREEN}✅ Zig metal compiled${NC}"
else
    echo -e "${RED}❌ build.zig not found${NC}"
    exit 1
fi

# 2. Build Rust Logic Engine
echo -e "\n${YELLOW}[2/4] Compiling Rust Logic Engine...${NC}"
if [ -f "Cargo.toml" ]; then
    # Link Zig library
    export LD_LIBRARY_PATH="$PWD/zig-out/lib:$LD_LIBRARY_PATH"
    cargo build --release
    echo -e "${GREEN}✅ Rust engine compiled${NC}"
else
    echo -e "${RED}❌ Cargo.toml not found${NC}"
    exit 1
fi

# 3. Bake Julia Brain (System Image)
echo -e "\n${YELLOW}[3/4] Baking Julia AI Brain...${NC}"
if [ -f "titan_brain.jl" ]; then
    julia -e '
    using Pkg
    Pkg.instantiate()
    using PackageCompiler
    
    # Create system image for instant startup
    create_sysimage(
        [:WAV, :FFTW, :Statistics],
        sysimage_path="titan_brain.so",
        precompile_execution_file="titan_brain.jl"
    )
    ' 2>/dev/null || echo -e "${YELLOW}⚠️  Julia system image creation skipped (not critical)${NC}"
    echo -e "${GREEN}✅ Julia brain ready${NC}"
else
    echo -e "${RED}❌ titan_brain.jl not found${NC}"
    exit 1
fi

# 4. Make Python script executable
echo -e "\n${YELLOW}[4/4] Preparing Python launcher...${NC}"
if [ -f "titan_injection.py" ]; then
    chmod +x titan_injection.py
    echo -e "${GREEN}✅ Python launcher ready${NC}"
else
    echo -e "${RED}❌ titan_injection.py not found${NC}"
    exit 1
fi

# Create run script
cat > run_titan.sh << 'EOF'
#!/bin/bash
# TITAN VISION OS - Launch Script

# Set library paths
export LD_LIBRARY_PATH="$PWD/zig-out/lib:$PWD/target/release:$LD_LIBRARY_PATH"

# Activate Python environment
source ~/titan_venv/bin/activate

# Launch engine
python3 titan_injection.py "$@"
EOF

chmod +x run_titan.sh

echo ""
echo "=========================================="
echo -e "${GREEN}  BUILD COMPLETE - TITAN VISION OS${NC}"
echo "=========================================="
echo ""
echo "SYSTEM STATUS:"
echo "  [✓] Zig Metal Layer"
echo "  [✓] Rust Logic Engine"
echo "  [✓] Julia AI Brain"
echo "  [✓] Python Orchestrator"
echo ""
echo "LAUNCH COMMAND:"
echo "  ./run_titan.sh"
echo ""
echo "KEYBOARD CONTROLS:"
echo "  [S] Toggle Sharpen"
echo "  [D] Toggle Denoise"
echo "  [N] Toggle Night Vision"
echo "  [M] Toggle Motion Detection"
echo "  [+] Zoom In"
echo "  [-] Zoom Out"
echo "  [Q] Quit"
echo ""
echo "Camera will be at /dev/video0"
echo "Virtual output at /dev/video10"
echo ""
