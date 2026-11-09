$ErrorActionPreference='Stop'

function Copy-OriRuntime([string]$PayloadDirectory,[string]$GameDirectory) {
    $PayloadDirectory=(Resolve-Path -LiteralPath $PayloadDirectory).Path.TrimEnd('\')
    foreach($item in Get-ChildItem -LiteralPath $PayloadDirectory -File -Recurse) {
        $relative=$item.FullName.Substring($PayloadDirectory.Length).TrimStart('\')
        $destination=Join-Path $GameDirectory $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $item.FullName -Destination $destination -Force
    }
}

function Disable-OriVsync([string]$PlayerDataDirectory) {
    $settings=Join-Path $PlayerDataDirectory 'settings.bin'
    if(Test-Path -LiteralPath $settings) {
        $bytes=[IO.File]::ReadAllBytes($settings)
        if($bytes.Length -gt 22) {
            $bytes[22]=0
            [IO.File]::WriteAllBytes($settings,$bytes)
        }
    }
}
