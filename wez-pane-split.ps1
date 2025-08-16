#Requires -Module Microsoft.PowerShell.Utility
#Requires -Version 5.1

<#
.SYNOPSIS
    Splits the current wezterm pane into four, based on a JSON configuration.
.DESCRIPTION
    This script defines the Invoke-WezPaneSplit function that splits the current 
    wezterm pane into a 2x2 grid. It looks for a 'wez-pane-split.json' file to 
    configure the startup command for each pane.
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
    # The JSON is now expected to contain the full command, e.g., "Set-Location ~; ls"
    return $paneConfig.command
}

function New-WeztermPane {
    param(
        [Parameter(Mandatory)]
        [string]$Direction,
        [psobject]$PaneConfig
    )
    
    $commandToRun = Get-PaneExecutionCommand -paneConfig $PaneConfig
    
    $splitArgs = @($Direction)
    if (-not [string]::IsNullOrEmpty($commandToRun)) {
        # Use -NoExit to keep the pane open after the initial command runs.
        # The command string is passed as a single argument.
        $splitArgs += "--", "pwsh", "-NoExit", "-Command", $commandToRun
    }
    
    wezterm cli split-pane @splitArgs | Out-Null
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
        }
    } else {
        Write-Host "Configuration file not found. Splitting panes without custom commands."
    }

    # 2. Create Panes in a specific order for a 2x2 grid
    # Create Top-Right pane
    New-WeztermPane -Direction "--right" -PaneConfig $config.topRight
    Start-Sleep -Milliseconds 100 # A brief pause for wezterm to process the split
    wezterm cli activate-pane-direction Left | Out-Null

    # Create Bottom-Left pane from the Top-Left
    New-WeztermPane -Direction "--bottom" -PaneConfig $config.bottomLeft
    wezterm cli activate-pane-direction Down | Out-Null

    # Create Bottom-Right pane from the Bottom-Left
    New-WeztermPane -Direction "--right" -PaneConfig $config.bottomRight

    # 3. Setup Top-Left Pane (the current pane where the script is running)
    $topLeftCommand = Get-PaneExecutionCommand -paneConfig $config.topLeft
    if (-not [string]::IsNullOrEmpty($topLeftCommand)) {
        Invoke-Expression $topLeftCommand
    }

    # 4. Return focus to the Top-Left Pane
    wezterm cli activate-pane-direction Up   | Out-Null
    wezterm cli activate-pane-direction Left | Out-Null

    Write-Host "wezterm panes have been set up." -ForegroundColor Green

    #endregion
}
