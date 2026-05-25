#!/bin/bash
# ==============================================================================
# ComfyUI Startup Script — Flux Klein
# ==============================================================================

echo "================================================="
echo " Starting ComfyUI — Flux Klein"
echo "================================================="

# ── Symlink ComfyUI internal folders to persistent /workspace/ ─────────────────
# Symlinks are created only if not already present — existing data is never deleted

if [ ! -L "/workspace/ComfyUI/models" ]; then
    mkdir -p /workspace/models
    ln -s /workspace/models /workspace/ComfyUI/models
    echo "✅ models → /workspace/models"
else
    echo "✅ models symlink already exists"
fi

if [ ! -L "/workspace/ComfyUI/output" ]; then
    mkdir -p /workspace/output
    ln -s /workspace/output /workspace/ComfyUI/output
    echo "✅ output → /workspace/output"
else
    echo "✅ output symlink already exists"
fi

if [ ! -L "/workspace/ComfyUI/input" ]; then
    mkdir -p /workspace/input
    ln -s /workspace/input /workspace/ComfyUI/input
    echo "✅ input → /workspace/input"
else
    echo "✅ input symlink already exists"
fi

if [ ! -L "/workspace/ComfyUI/custom_nodes" ]; then
    mkdir -p /workspace/custom_nodes
    ln -s /workspace/custom_nodes /workspace/ComfyUI/custom_nodes
    echo "✅ custom_nodes → /workspace/custom_nodes"
else
    echo "✅ custom_nodes symlink already exists"
fi

if [ ! -L "/workspace/ComfyUI/user/default/workflows" ]; then
    mkdir -p /workspace/workflows
    mkdir -p /workspace/ComfyUI/user/default
    ln -s /workspace/workflows /workspace/ComfyUI/user/default/workflows
    echo "✅ workflows → /workspace/workflows"
else
    echo "✅ workflows symlink already exists"
fi

# ── Seed Flux Klein workflow from HuggingFace (first boot only) ────────────────
if [ -z "$(ls -A /workspace/workflows 2>/dev/null)" ]; then
    echo "Seeding Flux Klein workflow..."
    wget -q -O "/workspace/workflows/flux2_klein_control_net.json" \
        "https://huggingface.co/VixenQuest/Workflows/resolve/main/flux2_klein_control_net.json"
    echo "✅ Flux Klein workflow seeded"
else
    echo "✅ Workflows already present, skipping seed"
fi

# ── Re-pin transformers at runtime ─────────────────────────────────────────────
# Flux Klein's Qwen text encoder requires transformers>=4.50.3.
# Some custom nodes silently downgrade this on startup — this guard ensures
# the correct version is always active before ComfyUI launches.
CURRENT_TF=$(python3.11 -m pip show transformers 2>/dev/null | grep "^Version" | awk '{print $2}')
echo "   transformers current: $CURRENT_TF"
python3.11 -c "
from packaging.version import Version
import subprocess, sys
current = '$CURRENT_TF'
if not current or Version(current) < Version('4.50.3'):
    print('   Re-pinning transformers to >=4.50.3...')
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'transformers>=4.50.3', '--force-reinstall', '-q'])
    print('   ✅ transformers re-pinned')
else:
    print('   ✅ transformers version OK')
" 2>/dev/null || echo "   ⚠️  transformers version check skipped"

# ── Start JupyterLab ───────────────────────────────────────────────────────────
echo "================================================="
echo " Starting JupyterLab on port 8888..."
echo "================================================="
jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --ServerApp.token='' \
    --ServerApp.password='' \
    --ServerApp.allow_remote_access=True \
    --ServerApp.root_dir=/workspace \
    &

# ── Start ComfyUI (port 8188, SageAttention enabled) ──────────────────────────
echo "================================================="
echo " Starting ComfyUI on port 8188..."
echo "================================================="
cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 8188 --enable-cors-header --use-sage-attention
