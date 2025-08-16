Set-PSReadLineOption -EditMode vi
Invoke-Expression (&starship init powershell)

# Load custom wezterm pane splitting function
. "$PSScriptRoot/wez-pane-split.ps1"
