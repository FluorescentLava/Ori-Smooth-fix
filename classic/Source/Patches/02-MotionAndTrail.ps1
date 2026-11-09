param([string]$InputAssembly,[string]$ModulePath,[string]$OutputAssembly)
$ErrorActionPreference='Stop'
$oriAsm=[Mono.Cecil.AssemblyDefinition]::ReadAssembly($InputAssembly)
$oriHelper=[Mono.Cecil.AssemblyDefinition]::ReadAssembly($ModulePath)
$oriHelperType=$oriHelper.MainModule.Types.Where({$_.Name -eq 'OriMotionSmoothing'})[0]
function Import-OriHelper([string]$oriName){$oriAsm.MainModule.ImportReference($oriHelperType.Methods.Where({$_.Name -eq $oriName})[0])}
$oriUpdate=$oriAsm.MainModule.Types.Where({$_.Name -eq 'GameController'}).Methods.Where({$_.Name -eq 'Update'})[0]
$oriIL=$oriUpdate.Body.GetILProcessor()
$oriIL.InsertBefore($oriUpdate.Body.Instructions[0],$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Call,(Import-OriHelper 'Install')))

# Defer only player ghost emission until the render pose is applied.
$oriTrail=$oriAsm.MainModule.Types.Where({$_.Name -eq 'UberGhostTrail'})[0]
$oriMethod=$oriTrail.Methods.Where({$_.Name -eq 'Update'})[0]
$oriIL=$oriMethod.Body.GetILProcessor();$oriFirst=$oriMethod.Body.Instructions[0]
$oriIL.InsertBefore($oriFirst,$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
$oriIL.InsertBefore($oriFirst,$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Call,(Import-OriHelper 'SkipTrailUpdate')))
$oriIL.InsertBefore($oriFirst,$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Brfalse,$oriFirst))
$oriIL.InsertBefore($oriFirst,$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ret))

$oriMesh=$oriAsm.MainModule.Types.Where({$_.Name -eq 'UberGhostTrailMeshUpdate'})[0]
$oriCount=$oriMesh.Fields.Where({$_.Name -eq 'm_updateCount'})[0]
foreach($oriName in @('UpdateQuads','UpdateMeshVertPart')){
    $oriMethod=$oriMesh.Methods.Where({$_.Name -eq $oriName})[0]
    $oriIL=$oriMethod.Body.GetILProcessor();$oriFirst=$oriMethod.Body.Instructions[0]
    $oriStride=[Mono.Cecil.Cil.VariableDefinition]::new($oriAsm.MainModule.TypeSystem.Int32)
    $oriMethod.Body.Variables.Add($oriStride);$oriMethod.Body.InitLocals=$true
    # Original Ori updates one of four quad groups. The other constant four
    # multiplies a quad index into four vertices and must remain unchanged.
    $oriStrideConstants=@($oriMethod.Body.Instructions.Where({$_.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Ldc_I4_4 -and $_.Next.OpCode.Code -in @([Mono.Cecil.Cil.Code]::Rem,[Mono.Cecil.Cil.Code]::Add)}))
    if($oriStrideConstants.Count -ne 2){throw "Unexpected stride constants in $oriName"}
    foreach($oriConstant in $oriStrideConstants){$oriConstant.OpCode=[Mono.Cecil.Cil.OpCodes]::Ldloc;$oriConstant.Operand=$oriStride}
    $oriIL.InsertBefore($oriFirst,$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
    $oriIL.InsertBefore($oriFirst,$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Call,(Import-OriHelper 'TrailStride')))
    $oriIL.InsertBefore($oriFirst,$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Stloc,$oriStride))
    if($oriName -eq 'UpdateQuads'){
        $oriIL.InsertBefore($oriFirst,$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldloc,$oriStride))
        $oriIL.InsertBefore($oriFirst,$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldc_I4_1))
        $oriIL.InsertBefore($oriFirst,$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Bne_Un,$oriFirst))
        $oriIL.InsertBefore($oriFirst,$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
        $oriIL.InsertBefore($oriFirst,$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldc_I4_0))
        $oriIL.InsertBefore($oriFirst,$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Stfld,$oriCount))
        # Original movement/force integration visits 1/4 of quads each frame.
        # Full visits use 1/4 delta to preserve the existing visual drift speed.
        $oriDelta=$oriMethod.Body.Instructions.Where({$_.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Call -and $_.Operand.FullName -eq 'System.Single UnityEngine.Time::get_deltaTime()'})[0]
        if(!$oriDelta){throw 'Missing delta time read'}
        $oriAnchor=$oriDelta
        foreach($oriInstruction in @($oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldloc,$oriStride),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Conv_R4),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldc_R4,[single]4),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Div),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Mul))){$oriIL.InsertAfter($oriAnchor,$oriInstruction);$oriAnchor=$oriInstruction}
    }
}
$oriAsm.Write($OutputAssembly)
$oriAsm.Dispose();$oriHelper.Dispose()
'Scoped player trail build complete'
