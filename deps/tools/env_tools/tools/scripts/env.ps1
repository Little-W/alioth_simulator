# Get the directory where this script is located, then go up two levels to get env root
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$ENV_ROOT = Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR)
$VENV_ROOT = "$ENV_ROOT\.venv"

# Set ENV_ROOT environment variable
$env:ENV_ROOT = $ENV_ROOT

# rt-env目录是否存在
if (-not (Test-Path -Path $VENV_ROOT)) {
    Write-Host "Create Python venv for RT-Thread..."
    python -m venv $VENV_ROOT
    # 激活python venv
    & "$VENV_ROOT\Scripts\Activate.ps1"
    # 安装env-script
    pip install "$ENV_ROOT\tools\scripts"
} else {
    # 激活python venv
    & "$VENV_ROOT\Scripts\Activate.ps1"
}

$env:pathext = ".PS1;$env:pathext"
$env:PATH = "$ENV_ROOT\tools\scripts;$env:PATH"
