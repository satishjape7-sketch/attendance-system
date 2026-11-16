$ErrorActionPreference = 'Stop'
$mobileRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../mobile'))
Push-Location -LiteralPath $mobileRoot
try {
    flutter create --platforms=android,ios --project-name attendance_app .
    if ($LASTEXITCODE -ne 0) { throw 'Flutter platform generation failed' }

    $manifestPath = Join-Path $mobileRoot 'android/app/src/main/AndroidManifest.xml'
    [xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
    $androidNamespace = 'http://schemas.android.com/apk/res/android'
    $hasInternet = $false
    foreach ($permission in $manifest.manifest.SelectNodes('uses-permission')) {
        if ($permission.GetAttribute('name', $androidNamespace) -eq 'android.permission.INTERNET') {
            $hasInternet = $true
        }
    }
    if (-not $hasInternet) {
        $internet = $manifest.CreateElement('uses-permission')
        $internet.SetAttribute('name', $androidNamespace, 'android.permission.INTERNET')
        [void]$manifest.manifest.AppendChild($internet)
    }
    $manifest.manifest.application.SetAttribute('allowBackup', $androidNamespace, 'false')
    $manifest.Save($manifestPath)

    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency installation failed' }
    Write-Output 'Native runners generated. Configure HTTPS, app IDs and signing before release.'
} finally {
    Pop-Location
}
