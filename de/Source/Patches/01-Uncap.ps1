param([string]$InputAssembly,[string]$OutputAssembly)
$ErrorActionPreference='Stop'
$oriAsm=[Mono.Cecil.AssemblyDefinition]::ReadAssembly($InputAssembly)
$oriAwake=$oriAsm.MainModule.Types.Where({$_.Name -eq 'GameController'})[0].Methods.Where({$_.Name -eq 'Awake'})[0]
$oriSet=@($oriAwake.Body.Instructions.Where({$_.Operand -is [Mono.Cecil.MethodReference] -and $_.Operand.FullName -eq 'System.Void UnityEngine.Application::set_targetFrameRate(System.Int32)'}))
if($oriSet.Count -ne 1 -or $oriSet[0].Previous.OpCode.Code -ne [Mono.Cecil.Cil.Code]::Ldc_I4_S -or [int]$oriSet[0].Previous.Operand -ne 60){throw 'Unexpected FPS setter'}
$oriSet[0].Previous.OpCode=[Mono.Cecil.Cil.OpCodes]::Ldc_I4_M1
$oriSet[0].Previous.Operand=$null
$oriAsm.Write($OutputAssembly)
$oriAsm.Dispose()
