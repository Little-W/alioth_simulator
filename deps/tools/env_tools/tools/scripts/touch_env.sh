#!/usr/bin/env bash

DEFAULT_RTT_PACKAGE_URL=https://github.com/RT-Thread/packages.git
ENV_URL=https://github.com/RT-Thread/env.git
SDK_URL="https://github.com/RT-Thread/sdk.git"

if [ $1 ] && [ $1 = --gitee ]; then
    gitee=1
    DEFAULT_RTT_PACKAGE_URL=https://gitee.com/RT-Thread-Mirror/packages.git
    ENV_URL=https://gitee.com/RT-Thread-Mirror/env.git
    SDK_URL="https://gitee.com/RT-Thread-Mirror/sdk.git"
fi

# Use current directory as env_dir if ENV_ROOT is not set
env_dir=${ENV_ROOT:-$(pwd)}
if [ -d $env_dir ]; then
    read -p 'env directory already exists. Would you like to remove and recreate env directory? (Y/N) ' option
    if [[ "$option" =~ [Yy*] ]]; then
        rm -rf $env_dir/local_pkgs $env_dir/packages $env_dir/tools
    fi
fi

if ! [ -d $env_dir/packages ]; then
    package_url=${RTT_PACKAGE_URL:-$DEFAULT_RTT_PACKAGE_URL}
    mkdir -p $env_dir/local_pkgs
    mkdir -p $env_dir/packages
    mkdir -p $env_dir/tools
    git clone $package_url $env_dir/packages/packages --depth=1
    echo 'source "$PKGS_DIR/packages/Kconfig"' >$env_dir/packages/Kconfig
    git clone $SDK_URL $env_dir/packages/sdk --depth=1
    git clone $ENV_URL $env_dir/tools/scripts --depth=1
    # Create env.sh with dynamic paths
    cat > $env_dir/env.sh << 'EOF'
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH=`python3 -m site --user-base`/bin:${SCRIPT_DIR}/tools/scripts:$PATH
export RTT_EXEC_PATH=/usr/bin
export ENV_ROOT="${SCRIPT_DIR}"
EOF
fi
