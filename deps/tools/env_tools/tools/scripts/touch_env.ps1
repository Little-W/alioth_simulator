$DEFAULT_RTT_PACKAGE_URL = "https://github.com/RT-Thread/packages.git"
$ENV_URL = "https://github.com/RT-Thread/env.git"
$SDK_URL = "https://github.com/RT-Thread/sdk.git"

if ($args[0] -eq "--gitee") {
    echo "Using gitee service."
    $DEFAULT_RTT_PACKAGE_URL = "https://gitee.com/RT-Thread-Mirror/packages.git"
    $ENV_URL = "https://gitee.com/RT-Thread-Mirror/env.git"
    $SDK_URL = "https://gitee.com/RT-Thread-Mirror/sdk.git"
}

# Use current directory as env_dir if ENV_ROOT is not set
if ($env:ENV_ROOT) {
    $env_dir = $env:ENV_ROOT
} else {
    $env_dir = Get-Location
}

if (Test-Path -Path $env_dir) {
    $option = Read-Host "env directory already exists. Would you like to remove and recreate env directory? (Y/N) " option
} if (( $option -eq 'Y' ) -or ($option -eq 'y')) {
    if (Test-Path -Path "$env_dir\local_pkgs") { Remove-Item -Path "$env_dir\local_pkgs" -Recurse -Force }
    if (Test-Path -Path "$env_dir\packages") { Remove-Item -Path "$env_dir\packages" -Recurse -Force }
    if (Test-Path -Path "$env_dir\tools") { Remove-Item -Path "$env_dir\tools" -Recurse -Force }
}

if (!(Test-Path -Path "$env_dir\packages")) {
    echo "creating env folder structure!"
    $package_url = $DEFAULT_RTT_PACKAGE_URL
    if (!(Test-Path -Path "$env_dir\local_pkgs")) { mkdir "$env_dir\local_pkgs" | Out-Null }
    if (!(Test-Path -Path "$env_dir\packages")) { mkdir "$env_dir\packages" | Out-Null }
    if (!(Test-Path -Path "$env_dir\tools")) { mkdir "$env_dir\tools" | Out-Null }
    git clone $package_url "$env_dir/packages/packages" --depth=1
    echo 'source "$PKGS_DIR/packages/Kconfig"' | Out-File -FilePath "$env_dir/packages/Kconfig" -Encoding ASCII
    git clone $SDK_URL "$env_dir/packages/sdk" --depth=1
    git clone $ENV_URL "$env_dir/tools/scripts" --depth=1
    copy "$env_dir/tools/scripts/env.ps1" "$env_dir/env.ps1"
} else {
    echo "env folder has existed. Jump this step."
}
