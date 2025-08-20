# Get the directory where this script is located, then go up two levels to get env root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"
export PATH=${ENV_ROOT}/tools/scripts:$PATH
export ENV_ROOT="${ENV_ROOT}"
