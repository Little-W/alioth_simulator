# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH=`python3 -m site --user-base`/bin:${SCRIPT_DIR}/tools/scripts:$PATH
export RTT_EXEC_PATH=/usr/bin
export ENV_ROOT="${SCRIPT_DIR}"
