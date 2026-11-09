$ErrorActionPreference='Stop'

function Invoke-OriClassicPatch([string]$AssemblyPath,[string]$ManagedDirectory) {
    if(!('Mono.Cecil.AssemblyDefinition' -as [type])){
        Add-Type -LiteralPath (Join-Path $PSScriptRoot 'lib\Mono.Cecil.dll')
    }
    $oriInput=[IO.MemoryStream]::new([IO.File]::ReadAllBytes($AssemblyPath))
    $oriAssembly=$null;$oriUnity=$null;$oriOutput=[IO.MemoryStream]::new()
    try {
        $oriAssembly=[Mono.Cecil.AssemblyDefinition]::ReadAssembly($oriInput)
        $oriUnity=[Mono.Cecil.AssemblyDefinition]::ReadAssembly((Join-Path $ManagedDirectory 'UnityEngine.dll'))
        $oriModule=$oriAssembly.MainModule
        $oriController=@($oriModule.Types | Where-Object {$_.Name -eq 'GameController'})
        if($oriController.Count -ne 1){throw 'GameController is missing; the assembly was not written.'}
        $oriController=$oriController[0]
        $oriApplication=@($oriUnity.MainModule.Types | Where-Object {$_.FullName -eq 'UnityEngine.Application'})[0]
        $oriQuality=@($oriUnity.MainModule.Types | Where-Object {$_.FullName -eq 'UnityEngine.QualitySettings'})[0]
        function Import-OriClassicMethod($Type,[string]$Name) {
            $oriMatches=@($Type.Methods | Where-Object {$_.Name -eq $Name -and $_.IsStatic})
            if($oriMatches.Count -ne 1){throw ('Unity method is missing: '+$Name)}
            return $oriModule.ImportReference($oriMatches[0])
        }
        $oriGetTarget=Import-OriClassicMethod $oriApplication 'get_targetFrameRate'
        $oriSetTarget=Import-OriClassicMethod $oriApplication 'set_targetFrameRate'
        $oriGetVsync=Import-OriClassicMethod $oriQuality 'get_vSyncCount'
        $oriSetVsync=Import-OriClassicMethod $oriQuality 'set_vSyncCount'
        $oriPolicyName='OriSmoothFix_ApplyFramePolicy'
        $oriPolicy=@($oriController.Methods | Where-Object {$_.Name -eq $oriPolicyName})
        if($oriPolicy.Count -gt 1){throw 'Ambiguous frame policy method; the assembly was not written.'}
        if($oriPolicy.Count){$oriPolicy=$oriPolicy[0]}else{
            $oriAttributes=[Enum]::Parse([Mono.Cecil.MethodAttributes],'Private, Static, HideBySig')
            $oriPolicy=[Mono.Cecil.MethodDefinition]::new($oriPolicyName,$oriAttributes,$oriModule.TypeSystem.Void)
            $oriController.Methods.Add($oriPolicy)
        }
        $oriPolicy.Body=[Mono.Cecil.Cil.MethodBody]::new($oriPolicy)
        $oriPolicy.Body.MaxStackSize=2
        $oriIl=$oriPolicy.Body.GetILProcessor()
        $oriFpsLabel=$oriIl.Create([Mono.Cecil.Cil.OpCodes]::Nop)
        $oriDone=$oriIl.Create([Mono.Cecil.Cil.OpCodes]::Ret)
        foreach($oriInstruction in @(
            $oriIl.Create([Mono.Cecil.Cil.OpCodes]::Call,$oriGetVsync),
            $oriIl.Create([Mono.Cecil.Cil.OpCodes]::Brfalse,$oriFpsLabel),
            $oriIl.Create([Mono.Cecil.Cil.OpCodes]::Ldc_I4_0),
            $oriIl.Create([Mono.Cecil.Cil.OpCodes]::Call,$oriSetVsync),
            $oriFpsLabel,
            $oriIl.Create([Mono.Cecil.Cil.OpCodes]::Call,$oriGetTarget),
            $oriIl.Create([Mono.Cecil.Cil.OpCodes]::Ldc_I4_M1),
            $oriIl.Create([Mono.Cecil.Cil.OpCodes]::Beq,$oriDone),
            $oriIl.Create([Mono.Cecil.Cil.OpCodes]::Ldc_I4_M1),
            $oriIl.Create([Mono.Cecil.Cil.OpCodes]::Call,$oriSetTarget),
            $oriDone
        )){$oriIl.Append($oriInstruction)}

        $oriHookedMethods=[Collections.Generic.List[string]]::new()
        foreach($oriMethodName in @('Awake','Update')) {
            $oriMethods=@($oriController.Methods | Where-Object {$_.Name -eq $oriMethodName -and $_.Parameters.Count -eq 0 -and $_.ReturnType.FullName -eq 'System.Void' -and $_.HasBody})
            if($oriMethods.Count -ne 1){throw ('GameController.'+$oriMethodName+' is missing; the assembly was not written.')}
            $oriMethod=$oriMethods[0]
            $oriReturns=@($oriMethod.Body.Instructions | Where-Object {$_.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Ret})
            if(!$oriReturns.Count){throw ('No return paths in '+$oriMethodName)}
            $oriIl=$oriMethod.Body.GetILProcessor()
            foreach($oriReturn in $oriReturns) {
                # Replacing the existing ret preserves branches that target it.
                # Repeated installation reuses the existing policy call.
                if($oriReturn.Previous -and $oriReturn.Previous.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Call -and $oriReturn.Previous.Operand -is [Mono.Cecil.MethodReference] -and $oriReturn.Previous.Operand.FullName -eq $oriPolicy.FullName){continue}
                $oriReturn.OpCode=[Mono.Cecil.Cil.OpCodes]::Call
                $oriReturn.Operand=$oriPolicy
                $oriIl.InsertAfter($oriReturn,$oriIl.Create([Mono.Cecil.Cil.OpCodes]::Ret))
            }
            $oriHookedMethods.Add($oriMethod.FullName)
        }
        $oriAssembly.Write($oriOutput)
        $oriResultBytes=$oriOutput.ToArray()
    }
    finally {
        if($oriAssembly){$oriAssembly.Dispose()}
        if($oriUnity){$oriUnity.Dispose()}
        $oriInput.Dispose();$oriOutput.Dispose()
    }
    # Single final write: no backup, staged DLL or persistent patcher files.
    [IO.File]::WriteAllBytes($AssemblyPath,$oriResultBytes)
    [pscustomobject]@{HookedMethods=@($oriHookedMethods);RenderingFPSLimit=-1;Vsync=0;MotionInterpolationIncluded=$false;TrailInterpolationIncluded=$false}
}
