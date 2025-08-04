#!/usr/bin/env bash

# Setup script for RT-Thread env tools without fixed directory dependency
# This script can be used to setup the environment anywhere

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_ROOT="${SCRIPT_DIR}"

echo "Setting up RT-Thread environment tools in: ${ENV_ROOT}"

# Check if we have the necessary structure
if [ ! -d "${ENV_ROOT}/tools/scripts" ]; then
    echo "Error: tools/scripts directory not found in ${ENV_ROOT}"
    echo "This script should be run from the env root directory"
    exit 1
fi

# Check if packages directory exists
if [ ! -d "${ENV_ROOT}/packages" ]; then
    echo "Warning: packages directory not found. You may need to initialize it."
fi

# Set up environment variables
export ENV_ROOT="${ENV_ROOT}"
export PATH="${ENV_ROOT}/tools/scripts:${PATH}"

echo "Environment setup complete!"
echo ""
echo "To use the environment in your current shell session:"
echo "  source ${ENV_ROOT}/env.sh"
echo ""
echo "To make this persistent, add the following to your ~/.bashrc:"
echo "  source ${ENV_ROOT}/env.sh"
echo ""
echo "Available commands after sourcing env.sh:"
echo "  - menuconfig: Configure RT-Thread"
echo "  - pkgs: Package management"
echo "  - sdk: SDK management"
echo ""
