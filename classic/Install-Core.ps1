$ErrorActionPreference='Stop'

function Copy-OriRuntime([string]$PayloadDirectory,[string]$GameDirectory) {
    $PayloadDirectory=(Resolve-Path -LiteralPath $PayloadDirectory).Path.TrimEnd('\')
    foreach($oriItem in Get-ChildItem -LiteralPath $PayloadDirectory -File -Recurse) {
        $oriRelative=$oriItem.FullName.Substring($PayloadDirectory.Length).TrimStart('\')
        $oriDestination=Join-Path $GameDirectory $oriRelative
        New-Item -ItemType Directory -Path (Split-Path -Parent $oriDestination) -Force | Out-Null
        Copy-Item -LiteralPath $oriItem.FullName -Destination $oriDestination -Force
    }
}
