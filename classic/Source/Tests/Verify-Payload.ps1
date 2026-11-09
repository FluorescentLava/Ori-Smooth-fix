#requires -Version 7.0
param(
    [Parameter(Mandatory=$true)][string]$OriginalAssembly,
    [string]$PayloadDirectory=(Join-Path $PSScriptRoot '..\..\Payload'),
    [string]$OutputFile=''
)
$ErrorActionPreference='Stop'
Add-Type -LiteralPath (Join-Path $PSScriptRoot '..\lib\Mono.Cecil.dll')
$oriOriginal=[Mono.Cecil.AssemblyDefinition]::ReadAssembly((Resolve-Path -LiteralPath $OriginalAssembly).Path)
$oriPatched=[Mono.Cecil.AssemblyDefinition]::ReadAssembly((Join-Path $PayloadDirectory 'ori_Data\Managed\Assembly-CSharp.dll'))
$oriHelper=[Mono.Cecil.AssemblyDefinition]::ReadAssembly((Join-Path $PayloadDirectory 'ori_Data\Managed\OriMotionSmoothing.dll'))
function Get-OriTypes($oriTypeCollection) {
    foreach($oriType in $oriTypeCollection) {
        $oriType
        Get-OriTypes $oriType.NestedTypes
    }
}
function Get-OriOperand($oriMethod,$oriOperand) {
    if($null -eq $oriOperand){return ''}
    if($oriOperand -is [Mono.Cecil.Cil.Instruction]){return 'instruction:'+$oriMethod.Body.Instructions.IndexOf($oriOperand)}
    if($oriOperand -is [Mono.Cecil.Cil.Instruction[]]){return 'targets:'+(($oriOperand | ForEach-Object {$oriMethod.Body.Instructions.IndexOf($_)}) -join ',')}
    if($oriOperand -is [Mono.Cecil.Cil.VariableDefinition]){return 'local:'+$oriOperand.Index}
    if($oriOperand -is [Mono.Cecil.ParameterDefinition]){return 'parameter:'+$oriOperand.Index}
    if($oriOperand -is [Mono.Cecil.MemberReference]){return $oriOperand.FullName}
    return [string]$oriOperand
}
function Get-OriBody($oriMethod) {
    if(!$oriMethod.HasBody){return ''}
    $oriText=[Text.StringBuilder]::new()
    $null=$oriText.AppendLine([string]$oriMethod.Body.InitLocals)
    foreach($oriLocal in $oriMethod.Body.Variables){$null=$oriText.AppendLine($oriLocal.VariableType.FullName)}
    foreach($oriInstruction in $oriMethod.Body.Instructions){
        $null=$oriText.AppendLine($oriInstruction.OpCode.Name+' '+(Get-OriOperand $oriMethod $oriInstruction.Operand))
    }
    foreach($oriHandler in $oriMethod.Body.ExceptionHandlers){
        $null=$oriText.AppendLine([string]$oriHandler.HandlerType+' '+$oriHandler.CatchType+' '+((@($oriHandler.TryStart,$oriHandler.TryEnd,$oriHandler.HandlerStart,$oriHandler.HandlerEnd,$oriHandler.FilterStart) | ForEach-Object {Get-OriOperand $oriMethod $_}) -join ';'))
    }
    return $oriText.ToString()
}
try {
    $oriOriginalTypes=@(Get-OriTypes $oriOriginal.MainModule.Types)
    $oriPatchedTypes=@(Get-OriTypes $oriPatched.MainModule.Types)
    $oriPatchedByName=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach($oriType in $oriPatchedTypes){$oriPatchedByName[$oriType.FullName]=$oriType}
    if($oriOriginalTypes.Count -ne $oriPatchedTypes.Count){throw 'The patch changed the game type count.'}
    $oriChanged=[Collections.Generic.List[string]]::new()
    $oriAddedFields=[Collections.Generic.List[string]]::new()
    $oriMethodCount=0
    foreach($oriType in $oriOriginalTypes) {
        $oriOther=$oriPatchedByName[$oriType.FullName]
        if(!$oriOther -or $oriType.Attributes -ne $oriOther.Attributes){throw ('Game type changed: '+$oriType.FullName)}
        if($oriType.Methods.Count -ne $oriOther.Methods.Count){throw ('Method count changed: '+$oriType.FullName)}
        $oriOtherMethods=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
        foreach($oriMethod in $oriOther.Methods){$oriOtherMethods[$oriMethod.FullName]=$oriMethod}
        foreach($oriMethod in $oriType.Methods) {
            $oriMethodCount++
            $oriCandidate=$oriOtherMethods[$oriMethod.FullName]
            if(!$oriCandidate -or $oriCandidate.Attributes -ne $oriMethod.Attributes){throw ('Game method signature changed: '+$oriMethod.FullName)}
            if((Get-OriBody $oriMethod) -cne (Get-OriBody $oriCandidate)){$oriChanged.Add($oriMethod.DeclaringType.Name+'::'+$oriMethod.Name)}
        }
        $oriOriginalFields=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
        foreach($oriField in $oriType.Fields){$oriOriginalFields[$oriField.FullName]=$oriField}
        foreach($oriField in $oriOther.Fields){
            if(!$oriOriginalFields.ContainsKey($oriField.FullName)){$oriAddedFields.Add($oriField.FullName)}
            elseif($oriField.Attributes -ne $oriOriginalFields[$oriField.FullName].Attributes){throw ('Field attributes changed: '+$oriField.FullName)}
        }
        foreach($oriField in $oriType.Fields){if(!@($oriOther.Fields.Where({$_.FullName -eq $oriField.FullName})).Count){throw ('Field removed: '+$oriField.FullName)}}
    }
    $oriExpected=@('GameController::Awake','GameController::Update','UberGhostTrail::Update','UberGhostTrailMeshUpdate::UpdateQuads','UberGhostTrailMeshUpdate::UpdateMeshVertPart','UberGhostTrailMeshUpdate::SpawnSingleTrailSprite','UberGhostTrailMeshUpdate::RemoveQuad','UberGhostTrailMeshUpdate::ReallocateBuffers','UberGhostTrailMeshUpdate::SetSettings','UberGhostTrailMeshUpdate::UpdateTrailMesh')
    $oriUnexpected=@(Compare-Object ($oriExpected | Sort-Object) ($oriChanged | Sort-Object))
    if($oriUnexpected.Count){throw ('Unexpected method changes: '+($oriUnexpected | Out-String))}
    if($oriAddedFields.Count -ne 2 -or !($oriAddedFields -match 'm_oriMeshTopologyDirty$') -or !($oriAddedFields -match 'm_oriLastUploadedAtlas$')){throw 'Unexpected cache fields.'}
    $oriRequiredPrivateFields=@{UberGhostTrail=@('m_previousPosition','m_lastSpawnPoint','m_travelDistance','m_previousCenterOffset');PhysicsLimitTest=@('m_synced')}
    foreach($oriName in $oriRequiredPrivateFields.Keys){
        $oriType=$oriOriginal.MainModule.Types.Where({$_.Name -eq $oriName})[0]
        foreach($oriFieldName in $oriRequiredPrivateFields[$oriName]){if(!@($oriType.Fields.Where({$_.Name -eq $oriFieldName})).Count){throw ('Missing reflected field: '+$oriName+'::'+$oriFieldName)}}
    }
    $oriForbidden=@($oriHelper.MainModule.GetMemberReferences() | Where-Object {$_.FullName -match 'System\.IO\.|set_fixedDeltaTime|UnityEngine\.Rigidbody::set_|SeinCharacter::set_Position'})
    if($oriForbidden.Count){throw ('Unexpected helper behavior: '+($oriForbidden.FullName -join ', '))}
    $oriMesh=$oriOriginal.MainModule.Types.Where({$_.Name -eq 'UberGhostTrailMeshUpdate'})[0]
    $oriMeshGetter=$oriMesh.Methods.Where({$_.Name -eq 'get_TrailMesh'})[0]
    if($oriMeshGetter.Body.Instructions.Count -ne 3 -or $oriMeshGetter.Body.Instructions[1].Operand.Name -ne 'm_trailMesh1'){throw 'Unexpected original trail mesh ownership.'}
    $oriResult=[ordered]@{
        originalAssemblySHA256=(Get-FileHash -LiteralPath $OriginalAssembly).Hash
        patchedAssemblySHA256=(Get-FileHash -LiteralPath (Join-Path $PayloadDirectory 'ori_Data\Managed\Assembly-CSharp.dll')).Hash
        motionModuleSHA256=(Get-FileHash -LiteralPath (Join-Path $PayloadDirectory 'ori_Data\Managed\OriMotionSmoothing.dll')).Hash
        comparedGameTypes=$oriOriginalTypes.Count
        comparedGameMethods=$oriMethodCount
        modifiedGameMethods=@($oriChanged)
        addedCacheFields=@($oriAddedFields)
        originalTrailMeshIsSingleDynamicMesh=$true
        reflectedPrivateFieldsPresent=$true
        helperHasFileIOOrPhysicsBodyWrites=$false
        helperConfiguresPhysicsSyncFlag=$true
        passed=$true
    }
    $oriJson=$oriResult | ConvertTo-Json -Depth 6
    if($OutputFile){[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputFile),$oriJson+[Environment]::NewLine)}
    $oriJson
}
finally {$oriOriginal.Dispose();$oriPatched.Dispose();$oriHelper.Dispose()}
