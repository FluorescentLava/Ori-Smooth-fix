#requires -Version 7.0
param(
    [Parameter(Mandatory=$true)][string]$GameDirectory,
    [string]$OriginalAssembly='',
    [string]$OutputDirectory=(Join-Path $PSScriptRoot '..\Build\Payload')
)
$ErrorActionPreference='Stop'
$oriGame=(Resolve-Path -LiteralPath $GameDirectory).Path
$oriManaged=Join-Path $oriGame 'ori_Data\Managed'
if(!$OriginalAssembly){$OriginalAssembly=Join-Path $oriManaged 'Assembly-CSharp.dll'}
$OriginalAssembly=(Resolve-Path -LiteralPath $OriginalAssembly).Path
$oriOut=[IO.Path]::GetFullPath($OutputDirectory)
if($oriOut.Equals($oriGame,[StringComparison]::OrdinalIgnoreCase) -or $oriOut.StartsWith($oriGame.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Build output must be outside the game directory.'}
$oriSdks=@(& dotnet --list-sdks)
if($LASTEXITCODE -ne 0 -or !$oriSdks.Count){throw 'Install a .NET SDK (6 or newer).'}
$oriLastSdk=$oriSdks[-1]
if($oriLastSdk -notmatch '^([^ ]+) \[(.+)\]$'){throw 'Cannot locate the .NET SDK.'}
$oriCompiler=Join-Path (Join-Path $Matches[2] $Matches[1]) 'Roslyn\bincore\csc.dll'
if(!(Test-Path -LiteralPath $oriCompiler)){throw 'C# compiler not found'}
$oriOutManaged=Join-Path $oriOut 'ori_Data\Managed'
$oriIntermediate=Join-Path $oriOut '.intermediate'
New-Item -ItemType Directory -Path $oriOutManaged,$oriIntermediate -Force | Out-Null
Add-Type -LiteralPath (Join-Path $PSScriptRoot 'lib\Mono.Cecil.dll')
$oriModule=Join-Path $oriOutManaged 'OriMotionSmoothing.dll'
$oriRefs=@('/nologo','/nostdlib+','/langversion:4','/target:library','/optimize+','/deterministic+',('/reference:'+(Join-Path $oriManaged 'mscorlib.dll')),('/reference:'+(Join-Path $oriManaged 'System.dll')),('/reference:'+(Join-Path $oriManaged 'UnityEngine.dll')),('/reference:'+$OriginalAssembly))
& dotnet $oriCompiler @oriRefs ('/out:'+$oriModule) (Join-Path $PSScriptRoot 'OriMotionSmoothing.cs')
if($LASTEXITCODE -ne 0){throw 'Module compilation failed'}
$oriStage1=Join-Path $oriIntermediate 'Assembly-CSharp.uncapped.dll'
$oriStage2=Join-Path $oriIntermediate 'Assembly-CSharp.motion.dll'
$oriFinal=Join-Path $oriOutManaged 'Assembly-CSharp.dll'
& (Join-Path $PSScriptRoot 'Patches\01-Uncap.ps1') -InputAssembly $OriginalAssembly -ManagedDirectory $oriManaged -OutputAssembly $oriStage1
& (Join-Path $PSScriptRoot 'Patches\02-MotionAndTrail.ps1') -InputAssembly $oriStage1 -ModulePath $oriModule -OutputAssembly $oriStage2
& (Join-Path $PSScriptRoot 'Patches\03-UploadCache.ps1') -InputAssembly $oriStage2 -ModulePath $oriModule -ManagedDirectory $oriManaged -OutputAssembly $oriFinal
foreach($oriFile in @('dxgi.dll','dxgi.ini')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('..\Payload\'+$oriFile)) -Destination $oriOut -Force}
[ordered]@{Version=4;OriginalAssemblySHA256=(Get-FileHash -LiteralPath $OriginalAssembly).Hash;PatchedAssemblySHA256=(Get-FileHash -LiteralPath $oriFinal).Hash;MotionModuleSHA256=(Get-FileHash -LiteralPath $oriModule).Hash;FPSLimit=-1;PhysicsHz=60} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $oriOut 'build-manifest.json')
Write-Output ('Build complete: '+$oriOut)
