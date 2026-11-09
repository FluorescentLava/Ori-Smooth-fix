param([string]$GameDirectory='',[string]$SteamDirectory='',[switch]$Elevated)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Install-Core.ps1')
try {
    if(!$GameDirectory -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'ori.exe'))){$GameDirectory=$PSScriptRoot}
    if(!$GameDirectory) {
        if(!$SteamDirectory) {
            foreach($oriKey in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
                $oriRegistry=Get-ItemProperty -LiteralPath $oriKey -ErrorAction SilentlyContinue
                foreach($oriProperty in @('SteamPath','InstallPath')) {
                    if($oriRegistry -and $oriRegistry.$oriProperty -and (Test-Path -LiteralPath (Join-Path $oriRegistry.$oriProperty 'steam.exe'))){$SteamDirectory=$oriRegistry.$oriProperty;break}
                }
                if($SteamDirectory){break}
            }
        }
        if($SteamDirectory) {
            $oriLibraries=@($SteamDirectory)
            $oriLibraryFile=Join-Path $SteamDirectory 'steamapps\libraryfolders.vdf'
            if(Test-Path -LiteralPath $oriLibraryFile){foreach($oriMatch in [regex]::Matches([IO.File]::ReadAllText($oriLibraryFile),'"path"\s+"((?:\\.|[^"\\])*)"')){$oriLibraries+=$oriMatch.Groups[1].Value.Replace('\\','\')}}
            foreach($oriLibrary in ($oriLibraries | Select-Object -Unique)) {
                $oriManifest=Join-Path $oriLibrary 'steamapps\appmanifest_261570.acf'
                if(!(Test-Path -LiteralPath $oriManifest)){continue}
                $oriMatch=[regex]::Match([IO.File]::ReadAllText($oriManifest),'"installdir"\s+"((?:\\.|[^"\\])*)"')
                if($oriMatch.Success){$GameDirectory=Join-Path (Join-Path $oriLibrary 'steamapps\common') $oriMatch.Groups[1].Value.Replace('\\','\');break}
            }
        }
    }
    if(!$GameDirectory){throw 'Ori Classic was not found. Put this package beside ori.exe, or run Install.cmd -GameDirectory "your Ori folder".'}
    $GameDirectory=(Resolve-Path -LiteralPath $GameDirectory).Path
    $oriProbe=Join-Path $GameDirectory ('.ori-smooth-'+[Guid]::NewGuid().ToString('N')+'.tmp')
    try{[IO.File]::WriteAllText($oriProbe,'');[IO.File]::Delete($oriProbe)}
    catch [UnauthorizedAccessException] {
        if($Elevated){throw}
        $oriElevationArguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$PSCommandPath+'"'),'-GameDirectory',('"'+$GameDirectory+'"'),'-Elevated')
        $oriChild=Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $oriElevationArguments -Verb RunAs -WindowStyle Hidden -Wait -PassThru
        exit $oriChild.ExitCode
    }
    foreach($oriProcess in @(Get-Process ori -ErrorAction SilentlyContinue)) {
        $null=$oriProcess.CloseMainWindow()
        if(!$oriProcess.WaitForExit(10000)){throw 'Exit Ori, then run Install.cmd again.'}
    }
    Copy-OriRuntime -PayloadDirectory (Join-Path $PSScriptRoot 'Payload') -GameDirectory $GameDirectory
    Write-Output 'Installed Ori Smooth for the original 2015 game. Launch Ori normally.'
}
catch {Write-Error ($_.Exception.Message+"`n"+$_.ScriptStackTrace);exit 1}
