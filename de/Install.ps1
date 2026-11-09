param(
    [string]$GameDirectory='',
    [string]$SteamDirectory='',
    [string]$PlayerDataDirectory=(Join-Path $env:LOCALAPPDATA 'Ori and the Blind Forest DE'),
    [switch]$Elevated
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Install-Core.ps1')

try {
    if(!$GameDirectory -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'oriDE.exe'))){$GameDirectory=$PSScriptRoot}
    if(!$GameDirectory) {
        if(!$SteamDirectory) {
            $candidates=@()
            foreach($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
                $reg=Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
                if($reg){foreach($property in @('SteamPath','InstallPath')){if($reg.$property){$candidates+=[string]$reg.$property}}}
            }
            foreach($candidate in $candidates){if(Test-Path -LiteralPath (Join-Path $candidate 'steam.exe')){$SteamDirectory=$candidate;break}}
        }
        if($SteamDirectory) {
            $SteamDirectory=(Resolve-Path -LiteralPath $SteamDirectory).Path
            $libraries=@($SteamDirectory)
            $libraryFile=Join-Path $SteamDirectory 'steamapps\libraryfolders.vdf'
            if(Test-Path -LiteralPath $libraryFile) {
                foreach($match in [regex]::Matches([IO.File]::ReadAllText($libraryFile),'"path"\s+"((?:\\.|[^"\\])*)"')){$libraries+=$match.Groups[1].Value.Replace('\\','\')}
            }
            foreach($library in ($libraries | Select-Object -Unique)) {
                $appManifest=Join-Path $library 'steamapps\appmanifest_387290.acf'
                if(!(Test-Path -LiteralPath $appManifest)){continue}
                $match=[regex]::Match([IO.File]::ReadAllText($appManifest),'"installdir"\s+"((?:\\.|[^"\\])*)"')
                if($match.Success){$GameDirectory=Join-Path (Join-Path $library 'steamapps\common') $match.Groups[1].Value.Replace('\\','\');break}
            }
        }
    }
    if(!$GameDirectory){throw 'Ori DE was not found. Put this package beside oriDE.exe and run Install.cmd, or run Install.cmd -GameDirectory "your Ori DE folder".'}
    $GameDirectory=(Resolve-Path -LiteralPath $GameDirectory).Path

    # Request Windows elevation only when the destination is not writable.
    $probe=Join-Path $GameDirectory ('.ori-smooth-'+[Guid]::NewGuid().ToString('N')+'.tmp')
    try{[IO.File]::WriteAllText($probe,'');[IO.File]::Delete($probe)}
    catch [UnauthorizedAccessException] {
        if($Elevated){throw}
        $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$PSCommandPath+'"'),'-GameDirectory',('"'+$GameDirectory+'"'),'-PlayerDataDirectory',('"'+$PlayerDataDirectory+'"'),'-Elevated')
        $child=Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $args -Verb RunAs -Wait -PassThru
        exit $child.ExitCode
    }

    Write-Output 'Installing Ori Smooth...'
    foreach($process in @(Get-Process oriDE -ErrorAction SilentlyContinue)) {
        $null=$process.CloseMainWindow()
        for($i=0;$i -lt 40 -and (Get-Process -Id $process.Id -ErrorAction SilentlyContinue);$i++){Start-Sleep -Milliseconds 250}
        if(Get-Process -Id $process.Id -ErrorAction SilentlyContinue){throw 'Exit Ori, then run Install.cmd again.'}
    }
    Copy-OriRuntime -PayloadDirectory (Join-Path $PSScriptRoot 'Payload') -GameDirectory $GameDirectory
    Disable-OriVsync -PlayerDataDirectory $PlayerDataDirectory
    Write-Output 'Installed. Launch Ori normally.'
}
catch {Write-Error $_;exit 1}
