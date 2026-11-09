param(
    [string]$PackageDirectory=(Join-Path $PSScriptRoot '..\..'),
    [string]$OutputFile=''
)
$ErrorActionPreference='Stop'
$PackageDirectory=(Resolve-Path -LiteralPath $PackageDirectory).Path
. (Join-Path $PackageDirectory 'Install-Core.ps1')
$oriFixture=[IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('Ori-Classic-installer-'+[Guid]::NewGuid().ToString('N'))))
$oriTestGame=Join-Path $oriFixture 'Ori'
$oriTestManaged=Join-Path $oriTestGame 'ori_Data\Managed'
try {
    New-Item -ItemType Directory -Path $oriTestManaged -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $oriTestManaged 'Assembly-CSharp.dll'),'unrecognized old assembly, intentionally overwritten')
    [IO.File]::WriteAllText((Join-Path $oriTestGame 'keep.txt'),'unrelated existing file')
    [IO.File]::WriteAllBytes((Join-Path $oriTestGame 'settings.bin'),[byte[]](0..50))
    $oriSettingsHash=(Get-FileHash -LiteralPath (Join-Path $oriTestGame 'settings.bin')).Hash
    $oriPayload=Join-Path $PackageDirectory 'Payload'
    $oriExpected=@('dxgi.dll','dxgi.ini','ori_Data\Managed\Assembly-CSharp.dll','ori_Data\Managed\OriMotionSmoothing.dll')
    for($oriPass=0;$oriPass -lt 2;$oriPass++) {
        Copy-OriRuntime -PayloadDirectory $oriPayload -GameDirectory $oriTestGame
        foreach($oriRelative in $oriExpected) {
            $oriSourceHash=(Get-FileHash -LiteralPath (Join-Path $oriPayload $oriRelative)).Hash
            $oriTargetHash=(Get-FileHash -LiteralPath (Join-Path $oriTestGame $oriRelative)).Hash
            if($oriSourceHash -ne $oriTargetHash){throw ('Payload mismatch: '+$oriRelative)}
        }
    }
    if((Get-FileHash -LiteralPath (Join-Path $oriTestGame 'settings.bin')).Hash -ne $oriSettingsHash){throw 'Installer altered settings.bin.'}
    if([IO.File]::ReadAllText((Join-Path $oriTestGame 'keep.txt')) -cne 'unrelated existing file'){throw 'Installer altered an unrelated file.'}
    if(@(Get-ChildItem -LiteralPath $oriTestGame -File -Recurse).Count -ne 6){throw 'Installer created unexpected files or backups.'}
    foreach($oriScript in Get-ChildItem -LiteralPath $PackageDirectory -Filter '*.ps1' -File -Recurse) {
        $oriTokens=$null;$oriErrors=$null
        $null=[Management.Automation.Language.Parser]::ParseFile($oriScript.FullName,[ref]$oriTokens,[ref]$oriErrors)
        if($oriErrors){throw ('PowerShell syntax error: '+$oriScript.FullName+' '+$oriErrors.Message)}
    }
    $oriResult=[ordered]@{
        testedPowerShellVersion=$PSVersionTable.PSVersion.ToString()
        filesCopied=$oriExpected
        unrecognizedExistingAssemblyOverwritten=$true
        repeatedInstallPassed=$true
        generatedBackupsOrTemporaryFiles=$false
        settingsAndUnrelatedFilePreserved=$true
        packagePowerShellSyntaxPassed=$true
        passed=$true
    }
    $oriJson=$oriResult | ConvertTo-Json -Depth 5
    if($OutputFile){[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputFile),$oriJson+[Environment]::NewLine)}
    $oriJson
}
finally {
    $oriTemp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if(!$oriFixture.StartsWith($oriTemp,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $oriFixture) -notlike 'Ori-Classic-installer-*'){throw 'Unsafe test cleanup path.'}
    if(Test-Path -LiteralPath $oriFixture){Remove-Item -LiteralPath $oriFixture -Recurse -Force}
}
