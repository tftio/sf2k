#!/usr/bin/env bash
# sf2k development environment setup
#
# Installs all required tooling via mise and configures git hooks via prek.
# Run this once after cloning the repo.

set -euo pipefail

echo "=== sf2k development setup ==="

# Check for mise
if ! command -v mise &>/dev/null; then
    echo "ERROR: mise is not installed."
    echo "Install it from https://mise.jdx.dev/ or via:"
    echo "  curl https://mise.run | sh"
    exit 1
fi

# Install tools defined in .mise.toml
echo "Installing tools via mise..."
mise install

# Verify installations
echo "Verifying installations..."

if mise which godot &>/dev/null; then
    echo "  godot: $(mise exec -- godot --version 2>/dev/null || echo 'installed (version check requires display)')"
else
    echo "  WARNING: godot not found after mise install"
fi

if mise which prek &>/dev/null; then
    echo "  prek: $(mise exec -- prek --version 2>/dev/null)"
else
    echo "  WARNING: prek not found after mise install"
fi

# Trust the mise config if needed
mise trust 2>/dev/null || true

# Set up git hooks via prek
echo "Configuring git hooks via prek..."
if mise which prek &>/dev/null; then
    mise exec -- prek install
    mise exec -- prek install --hook-type pre-push
    mise exec -- prek install-hooks
    echo "  Git hooks installed (pre-commit + pre-push)."
else
    echo "  WARNING: prek not available, skipping git hooks."
fi

echo ""
echo "=== Setup complete ==="
echo "Run 'mise exec -- godot --editor --path .' to open the project in Godot."
