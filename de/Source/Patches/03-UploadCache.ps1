param([string]$InputAssembly,[string]$ModulePath,[string]$ManagedDirectory,[string]$OutputAssembly)
$ErrorActionPreference='Stop'
$oriAsm=[Mono.Cecil.AssemblyDefinition]::ReadAssembly($InputAssembly)
$oriHelper=[Mono.Cecil.AssemblyDefinition]::ReadAssembly($ModulePath)
$oriUnity=[Mono.Cecil.AssemblyDefinition]::ReadAssembly((Join-Path $ManagedDirectory 'UnityEngine.dll'))
$oriMesh=$oriAsm.MainModule.Types.Where({$_.Name -eq 'UberGhostTrailMeshUpdate'})[0]
$oriDirty=[Mono.Cecil.FieldDefinition]::new('m_oriMeshTopologyDirty',[Mono.Cecil.FieldAttributes]::Private,$oriAsm.MainModule.TypeSystem.Boolean)
$oriLastAtlas=[Mono.Cecil.FieldDefinition]::new('m_oriLastUploadedAtlas',[Mono.Cecil.FieldAttributes]::Private,$oriMesh.Fields.Where({$_.Name -eq 'm_atlasSettings'})[0].FieldType)
$oriMesh.Fields.Add($oriDirty);$oriMesh.Fields.Add($oriLastAtlas)
foreach($oriName in @('SpawnSingleTrailSprite','RemoveQuad','ReallocateBuffers','SetSettings')){
    $oriM=$oriMesh.Methods.Where({$_.Name -eq $oriName})[0];$oriIL=$oriM.Body.GetILProcessor();$oriFirst=$oriM.Body.Instructions[0]
    foreach($oriIns in @($oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldc_I4_1),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Stfld,$oriDirty))){$oriIL.InsertBefore($oriFirst,$oriIns)}
}
$oriM=$oriMesh.Methods.Where({$_.Name -eq 'UpdateTrailMesh'})[0];$oriIL=$oriM.Body.GetILProcessor()
$oriAnchor=$oriM.Body.Instructions.Where({$_.Operand -is [Mono.Cecil.MethodReference] -and $_.Operand.Name -eq 'UpdateMeshVertPart'})[0]
$oriOriginalNext=$oriAnchor.Next
$oriReuse=$oriAsm.MainModule.ImportReference($oriHelper.MainModule.Types.Where({$_.Name -eq 'OriMotionSmoothing'})[0].Methods.Where({$_.Name -eq 'CanReuseTrailMesh'})[0])
$oriGetMesh=$oriMesh.Methods.Where({$_.Name -eq 'get_TrailMesh'})[0]
$oriSetVerts=$oriM.Body.Instructions.Where({$_.Operand -is [Mono.Cecil.MethodReference] -and $_.Operand.Name -eq 'set_vertices'})[0].Operand
$oriSetColors=$oriM.Body.Instructions.Where({$_.Operand -is [Mono.Cecil.MethodReference] -and $_.Operand.Name -eq 'set_colors32'})[0].Operand
$oriEqual=$oriAsm.MainModule.ImportReference($oriUnity.MainModule.Types.Where({$_.FullName -eq 'UnityEngine.Vector4'})[0].Methods.Where({$_.Name -eq 'op_Equality'})[0])
$oriGetShared=$oriAsm.MainModule.ImportReference($oriUnity.MainModule.Types.Where({$_.FullName -eq 'UnityEngine.MeshFilter'})[0].Methods.Where({$_.Name -eq 'get_sharedMesh'})[0])
$oriNotEqual=$oriAsm.MainModule.ImportReference($oriUnity.MainModule.Types.Where({$_.FullName -eq 'UnityEngine.Object'})[0].Methods.Where({$_.Name -eq 'op_Inequality'})[0])
$oriVerts=$oriMesh.Fields.Where({$_.Name -eq 'm_vertices'})[0];$oriColors=$oriMesh.Fields.Where({$_.Name -eq 'm_colors'})[0];$oriAtlas=$oriMesh.Fields.Where({$_.Name -eq 'm_atlasSettings'})[0];$oriFilter=$oriMesh.Fields.Where({$_.Name -eq 'm_meshFilter'})[0]
$oriFast=@(
    $oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Call,$oriReuse),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Brfalse,$oriOriginalNext),
    $oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldfld,$oriDirty),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Brtrue,$oriOriginalNext),
    $oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldfld,$oriAtlas),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldfld,$oriLastAtlas),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Call,$oriEqual),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Brfalse,$oriOriginalNext),
    $oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldfld,$oriFilter),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Callvirt,$oriGetShared),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Call,$oriGetMesh),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Call,$oriNotEqual),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Brtrue,$oriOriginalNext),
    $oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Call,$oriGetMesh),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldfld,$oriVerts),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Callvirt,$oriSetVerts),
    $oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Call,$oriGetMesh),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldfld,$oriColors),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Callvirt,$oriSetColors),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ret)
)
foreach($oriIns in $oriFast){$oriIL.InsertAfter($oriAnchor,$oriIns);$oriAnchor=$oriIns}
# Clear dirty state only after the original full upload has completed.
$oriRet=$oriM.Body.Instructions[-1]
foreach($oriIns in @($oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldc_I4_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Stfld,$oriDirty),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Ldfld,$oriAtlas),$oriIL.Create([Mono.Cecil.Cil.OpCodes]::Stfld,$oriLastAtlas))){$oriIL.InsertBefore($oriRet,$oriIns)}
$oriAsm.Write($OutputAssembly)
$oriAsm.Dispose();$oriHelper.Dispose();$oriUnity.Dispose()
'Player trail upload cache built'
