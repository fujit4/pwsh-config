#Requires -Module Microsoft.PowerShell.Utility
#Requires -Version 5.1

<#
.SYNOPSIS
    Splits the current wezterm pane into a 2x2 grid, based on a JSON configuration.
.DESCRIPTION
    This script defines the Invoke-WezPaneSplit function that splits the current 
    wezterm pane into a 2x2 grid. It uses pane IDs for robust splitting.
    It looks for a 'wez-pane-split.json' file to configure the startup command for each pane.
.EXAMPLE
    Invoke-WezPaneSplit
    Splits the panes according to the configuration file.
.NOTES
    Author: Gemini
    Date: 2025-08-16
#>

#region --- Helper Functions ---

function Find-PaneConfigFile {
    param($fileName)
    
    # Check XDG_CONFIG_HOME first
    if ($env:XDG_CONFIG_HOME) {
        $xdgPath = Join-Path $env:XDG_CONFIG_HOME "powershell/$fileName"
        if (Test-Path $xdgPath) { return $xdgPath }
    }
    
    # Fallback to default .config location
    $homePath = Join-Path $HOME ".config/powershell/$fileName"
    if (Test-Path $homePath) { return $homePath }
    
    return $null
}

function Get-PaneExecutionCommand {
    param(
        [Parameter(Mandatory)]
        [psobject]$paneConfig
    )

    if (-not $paneConfig -or -not $paneConfig.PSObject.Properties['command']) {
        return $null
    }
    
    # Directly return the command string from the config.
    return $paneConfig.command
}

#endregion

function Invoke-WezPaneSplit {
    [CmdletBinding()]
    param ()

    #region --- Main Script ---

    # 1. Load Configuration
    $configFileName = "wez-pane-split.json"
    $configPath = Find-PaneConfigFile -fileName $configFileName
    $config = $null
    if ($configPath) {
        try {
            $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
            Write-Host "Loaded configuration from: $configPath" -ForegroundColor Green
        } catch {
            Write-Error "Failed to parse config file '$configPath'. Error: $($_.Exception.Message)"
            # Continue without config on parsing error
        }
    } else {
        Write-Host "Configuration file not found. Splitting panes without custom commands."
    }

    # 2. Get the ID of the current pane (this will be our Top-Left pane)
    $topLeftPaneId = $env:WEZTERM_PANE
    if (-not $topLeftPaneId) {
        Write-Error "This script must be run from within a wezterm environment."
        return
    }

    # 3. Define a helper function to split panes and return the new pane ID
    function Split-Pane {
        param(
            [Parameter(Mandatory)]
            [array]$SplitArgs
        )
        # 'wezterm cli split-pane' returns the new pane ID to stdout, which we capture.
        return (wezterm cli split-pane @SplitArgs).Trim()
    }

    # 4. Create the grid using Pane IDs for precision
    
    # Create Top-Right pane by splitting Top-Left horizontally
    $topRightCmd = Get-PaneExecutionCommand -paneConfig $config.topRight
    $trSplitArgs = @("--pane-id", $topLeftPaneId, "--horizontal", "--percent", 50)
    if ($topRightCmd) { $trSplitArgs += "--", "pwsh", "-NoExit", "-Command", $topRightCmd }
    $topRightPaneId = Split-Pane -SplitArgs $trSplitArgs

    # Create Bottom-Left pane by splitting Top-Left vertically (default direction)
    $bottomLeftCmd = Get-PaneExecutionCommand -paneConfig $config.bottomLeft
    $blSplitArgs = @("--pane-id", $topLeftPaneId, "--percent", 50)
    if ($bottomLeftCmd) { $blSplitArgs += "--", "pwsh", "-NoExit", "-Command", $bottomLeftCmd }
    $bottomLeftPaneId = Split-Pane -SplitArgs $blSplitArgs

    # Create Bottom-Right pane by splitting Top-Right vertically (default direction)
    $bottomRightCmd = Get-PaneExecutionCommand -paneConfig $config.bottomRight
    $brSplitArgs = @("--pane-id", $topRightPaneId, "--percent", 50)
    if ($bottomRightCmd) { $brSplitArgs += "--", "pwsh", "-NoExit", "-Command", $bottomRightCmd }
    $bottomRightPaneId = Split-Pane -SplitArgs $brSplitArgs

    # 5. Setup the Top-Left pane itself (the pane where the script is running)
    $topLeftCommand = Get-PaneExecutionCommand -paneConfig $config.topLeft
    if (-not [string]::IsNullOrEmpty($topLeftCommand)) {
        Invoke-Expression $topLeftCommand
    }

    # 6. Return focus to the Top-Left Pane for final user control
    wezterm cli activate-pane --pane-id $topLeftPaneId | Out-Null

    Write-Host "wezterm 2x2 grid created successfully." -ForegroundColor Green

    #endregion
}
