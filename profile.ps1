Set-PSReadLineOption -EditMode vi
Invoke-Expression (&starship init powershell)


function Set-UserEnvVar {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    # 現在の値を取得
    $oldValue = [System.Environment]::GetEnvironmentVariable($Name, 'User')

    # レジストリ（ユーザー環境変数）に保存
    [System.Environment]::SetEnvironmentVariable($Name, $Value, 'User')

    # セッションにも反映（ユーザー環境変数は Machine と競合しないので直接代入でOK）
	# 反映されないのでいったんコメントアウト
    # ${env:$Name} = $Value

    # 設定後の値を再取得
    $newValue = [System.Environment]::GetEnvironmentVariable($Name, 'User')

    # 結果を出力
    Write-Host "環境変数名 : $Name"
    Write-Host "変更前 (User) : $oldValue"
    Write-Host "変更後 (User) : $newValue"
}


function Add-UserPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    # 現在のユーザー Path を取得
    $oldUserPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $oldUserPath) { $oldUserPath = "" }

    # すでに含まれているかチェック
    if ($oldUserPath.Split(';') -notcontains $Value) {
        $newUserPath = ($oldUserPath.TrimEnd(';') + ";" + $Value).Trim(';')

        # レジストリ（ユーザー環境変数）に保存
        [System.Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")

        # システム Path を取得
        $systemPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

        # セッションの Path を ユーザー + システム で再構成
		# 反映されないのでいったんコメントアウト
        $env:Path = "$newUserPath;$systemPath"

        Write-Host "環境変数名 : Path"
        Write-Host "変更前 (User) : $oldUserPath"
        Write-Host "変更後 (User) : $newUserPath"
    }
    else {
        Write-Host "Path に $Value はすでに含まれています。"
    }
}

