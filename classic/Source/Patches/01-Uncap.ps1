param([string]$InputAssembly,[string]$ManagedDirectory,[string]$OutputAssembly)
$ErrorActionPreference='Stop'
$oriAsm=[Mono.Cecil.AssemblyDefinition]::ReadAssembly($InputAssembly)
$oriAwake=$oriAsm.MainModule.Types.Where({$_.Name -eq 'GameController'})[0].Methods.Where({$_.Name -eq 'Awake'})[0]
$oriUnity=[Mono.Cecil.AssemblyDefinition]::ReadAssembly((Join-Path $ManagedDirectory 'UnityEngine.dll'))
$oriTarget=$oriAsm.MainModule.ImportReference($oriUnity.MainModule.Types.Where({$_.FullName -eq 'UnityEngine.Application'})[0].Methods.Where({$_.Name -eq 'set_targetFrameRate'})[0])
$oriVsync=$oriAsm.MainModule.ImportReference($oriUnity.MainModule.Types.Where({$_.FullName -eq 'UnityEngine.QualitySettings'})[0].Methods.Where({$_.Name -eq 'set_vSyncCount'})[0])
# The original 2015 build has no targetFrameRate assignment to replace.
# Apply the same rendering policy on each original Awake return path.
$oriReturns=@($oriAwake.Body.Instructions.Where({$_.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Ret}))
if(!$oriReturns.Count){throw 'Missing GameController.Awake return'}
$oriIL=$oriAwake.Body.GetILProcessor()
foreach($oriReturn in $oriReturns){
    $oriReturn.OpCode=[Mono.Cecil.Cil.OpCodes]::Ldc_I4_M1;$oriReturn.Operand=$null
    $oriAnchor=$oriReturn
    foreach($oriIns in @($oriIL.Create([Mono.Cecil.Cil.OpCodes]::Call,$oriTarget),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldc_I4_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Call,$oriVsync),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ret))){$oriIL.InsertAfter($oriAnchor,$oriIns);$oriAnchor=$oriIns}
}
$oriAsm.Write($OutputAssembly)
$oriAsm.Dispose();$oriUnity.Dispose()
