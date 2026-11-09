param([string]$PackageDirectory=(Join-Path $PSScriptRoot '..\..'))
$ErrorActionPreference='Stop'
$PackageDirectory=(Resolve-Path -LiteralPath $PackageDirectory).Path
$oriFixture=Join-Path ([IO.Path]::GetTempPath()) ('Ori-Classic-fixture-'+[Guid]::NewGuid().ToString('N'))
$oriManaged=Join-Path $oriFixture 'ori_Data\Managed'
New-Item -ItemType Directory -Path $oriManaged -Force | Out-Null
$oriCompiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
$oriUnitySource=@'
namespace UnityEngine {
  public static class Application {
    private static int value;
    public static int Writes;
    public static int targetFrameRate { get { return value; } set { Application.value=value; Writes++; } }
  }
  public static class QualitySettings {
    private static int value;
    public static int Writes;
    public static int vSyncCount { get { return value; } set { QualitySettings.value=value; Writes++; } }
  }
}
'@
$oriGameSource=@'
using UnityEngine;
public class GameController {
  public static bool Branch;
  public static int Executions;
  public void Awake() {
    Executions++;
    Application.targetFrameRate=60;
    QualitySettings.vSyncCount=1;
    if (Branch) return;
    Executions+=2;
  }
  public void Update() {
    Executions++;
    if (Branch) {
      Application.targetFrameRate=90;
      QualitySettings.vSyncCount=2;
      return;
    }
    Executions+=2;
  }
  public int Untouched(int x) { return x*7+3; }
}
'@
$oriUnityPath=Join-Path $oriFixture 'UnityEngine.cs';$oriGamePath=Join-Path $oriFixture 'GameController.cs'
[IO.File]::WriteAllText($oriUnityPath,$oriUnitySource)
[IO.File]::WriteAllText($oriGamePath,$oriGameSource)
& $oriCompiler /nologo /target:library /optimize+ ('/out:'+(Join-Path $oriManaged 'UnityEngine.dll')) $oriUnityPath
if($LASTEXITCODE){throw 'Fixture engine compilation failed'}
& $oriCompiler /nologo /target:library /optimize+ ('/reference:'+(Join-Path $oriManaged 'UnityEngine.dll')) ('/out:'+(Join-Path $oriManaged 'Assembly-CSharp.dll')) $oriGamePath
if($LASTEXITCODE){throw 'Fixture game compilation failed'}
$script:oriAssertions=0
function Assert-OriClassic([bool]$Condition,[string]$Message){if(!$Condition){throw $Message};$script:oriAssertions++}
foreach($oriFile in Get-ChildItem -LiteralPath $PackageDirectory -Recurse -File -Filter '*.ps1') {
  $oriTokens=$null;$oriErrors=$null
  $null=[Management.Automation.Language.Parser]::ParseFile($oriFile.FullName,[ref]$oriTokens,[ref]$oriErrors)
  Assert-OriClassic (!$oriErrors) ('Parse failed: '+$oriFile.Name)
}
# Fixture installer can never start or stop real programs or inspect the registry.
function Get-Process {param($Name,$ErrorAction);return}
function Start-Process {throw 'Fixture attempted process launch'}
function Get-ItemProperty {throw 'Explicit path unexpectedly read Steam registry'}
& (Join-Path $PackageDirectory 'Install.ps1') -GameDirectory $oriFixture
$oriFirstHash=(Get-FileHash -LiteralPath (Join-Path $oriManaged 'Assembly-CSharp.dll')).Hash
& (Join-Path $PackageDirectory 'Install.ps1') -GameDirectory $oriFixture
$oriSecondHash=(Get-FileHash -LiteralPath (Join-Path $oriManaged 'Assembly-CSharp.dll')).Hash
Assert-OriClassic ($oriFirstHash -eq $oriSecondHash) 'Repeated installation changed the patched assembly'
foreach($oriName in @('dxgi.dll','dxgi.ini')) {
  Assert-OriClassic ((Get-FileHash -LiteralPath (Join-Path $oriFixture $oriName)).Hash -eq (Get-FileHash -LiteralPath (Join-Path $PackageDirectory ('Payload\'+$oriName))).Hash) ('Plugin copy failed: '+$oriName)
}
Assert-OriClassic (@(Get-ChildItem -LiteralPath $oriFixture -Recurse -Force | Where-Object {$_.Name -match '(?i)backup|\.bak$|\.tmp$'}).Count -eq 0) 'Installer left a backup or temporary file'
Add-Type -LiteralPath (Join-Path $oriManaged 'UnityEngine.dll')
Add-Type -LiteralPath (Join-Path $oriManaged 'Assembly-CSharp.dll')
$oriInstance=[GameController]::new()
foreach($oriBranch in @($false,$true)) {
  [GameController]::Branch=$oriBranch
  $oriBefore=[GameController]::Executions
  $oriInstance.Awake()
  Assert-OriClassic ([UnityEngine.Application]::targetFrameRate -eq -1) 'Awake failed to uncap rendering'
  Assert-OriClassic ([UnityEngine.QualitySettings]::vSyncCount -eq 0) 'Awake failed to disable Vsync'
  $oriExpected=if($oriBranch){1}else{3}
  Assert-OriClassic ([GameController]::Executions-$oriBefore -eq $oriExpected) 'Awake original side effects changed'
  $oriInstance.Update()
  Assert-OriClassic ([UnityEngine.Application]::targetFrameRate -eq -1) 'Update failed after game frame policy change'
  Assert-OriClassic ([UnityEngine.QualitySettings]::vSyncCount -eq 0) 'Update failed after game Vsync change'
}
[GameController]::Branch=$false
[UnityEngine.Application]::Writes=0;[UnityEngine.QualitySettings]::Writes=0
foreach($oriFrame in 1..1000){$oriInstance.Update()}
Assert-OriClassic ([UnityEngine.Application]::Writes -eq 0) 'Unchanged frame policy caused redundant FPS writes'
Assert-OriClassic ([UnityEngine.QualitySettings]::Writes -eq 0) 'Unchanged frame policy caused redundant Vsync writes'
Assert-OriClassic ($oriInstance.Untouched(5) -eq 38) 'Unrelated method behavior changed'
$oriResult=[ordered]@{
  PowerShellVersion=$PSVersionTable.PSVersion.ToString()
  Assertions=$script:oriAssertions
  OfficialMonoCecilNet40Loaded=$true
  PatchedSyntheticAssemblyExecuted=$true
  AwakeAndUpdatePoliciesApplied=$true
  BranchReturnPathsPreserved=$true
  UnrelatedMethodBehaviorPreserved=$true
  RepeatedInstallationByteIdentical=$true
  NoRedundantSetterCallsOver1000Frames=$true
  NoBackupOrTemporaryFiles=$true
  ActualClassicGameTested=$false
  DEInterpolationIncluded=$false
}
$oriResult | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PackageDirectory 'Docs\synthetic-test-results.json') -Encoding UTF8
$oriResult | ConvertTo-Json
