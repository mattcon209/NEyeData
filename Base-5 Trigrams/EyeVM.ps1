# ================================
# EyeVM.ps1 — Unified, operand-aware VM
# ================================

# --- Dictionaries -------------------------------------------------

$Types = @{
    224="T_D1"; 21="T_E1"; 110="T_E2"; 130="T_E3"; 232="T_E4"; 242="T_E5";
    310="T_F1"; 311="T_F2"
}

$Modifiers = @{
    20="M_LOW1"; 23="M_LOW2"; 101="M_PROP1"; 113="M_PROP2";
    123="M_PROP3"; 140="M_PROP4"; 201="M_INT1"; 242="M_INT2"
}

$Actions = @{
    1="A_PRIM1"; 42="A_REL1"; 101="A_CORE1"; 131="A_CORE2";
    204="A_ACT1"; 222="A_ACT2"; 234="A_ACT3"; 243="A_MULTI1"
}

$Targets = @{
    2="X_SIMPLE1"; 12="X_SIMPLE2"; 13="X_SIMPLE3"; 20="X_MID1"; 41="X_MID2";
    202="X_OBJ1"; 211="X_OBJ2"; 233="X_OBJ3"; 243="X_MULTI1"
}

$Outcomes = @{
    10="R_SIMPLE1"; 11="R_SIMPLE2"; 14="R_SIMPLE3"; 133="R_STATE1";
    140="R_STATE2"; 210="R_STATE3"; 221="R_STATE4"; 231="R_STATE5"; 243="R_MULTI1"
}

# --- Operand field indices in the 25-trigram payload (0-based) ---

$OperandFields = @{
    C1  = 5
    C2  = 13
    C3  = 11
    C9  = 16
    C10 = 24
}

function Get-OperandsFromPayload {
    param([int[]] $Payload)

    [pscustomobject]@{
        C1  = $Payload[$OperandFields.C1]
        C2  = $Payload[$OperandFields.C2]
        C3  = $Payload[$OperandFields.C3]
        C9  = $Payload[$OperandFields.C9]
        C10 = $Payload[$OperandFields.C10]
    }
}

# --- State ranking for monotonicity checks ------------------------

$StateRank = @{
    "R_SIMPLE1" = 1
    "R_SIMPLE2" = 1
    "R_SIMPLE3" = 1
    "R_STATE1"  = 2
    "R_STATE2"  = 3
    "R_STATE3"  = 4
    "R_STATE4"  = 5
    "R_STATE5"  = 6
    "R_MULTI1"  = 99
}

# --- Instruction set with payloads -------------------------------

$Instructions = @(
    @{
        Msg=2;  C4=242; C5=113; C6=131; C7=41;  C8=10;
        Payload = @(242,111,10,44,3,133,214,232,113,144,131,220,41,101,110,10,100,40,241,21,244,211,4,244,34)
    },
    @{
        Msg=6;  C4=224; C5=242; C6=1;   C7=243; C8=11;
        Payload = @(134,101,214,302,224,133,304,103,242,224,1,110,243,43,232,11,113,100,224,311,233,141,32,121,23)
    },
    @{
        Msg=11; C4=224; C5=140; C6=101; C7=20;  C8=221;
        Payload = @(224,223,11,144,111,23,31,20,140,44,101,302,20,220,311,221,114,204,240,41,30,4,231,302,132)
    },
    @{
        Msg=16; C4=310; C5=20;  C6=222; C7=202; C8=231;
        Payload = @(310,302,142,303,114,100,222,33,20,144,222,224,202,311,21,231,222,23,142,32,202,240,101,43,112)
    },
    @{
        Msg=21; C4=130; C5=23;  C6=42;  C7=2;   C8=14;
        Payload = @(130,230,140,300,210,124,220,132,23,3,42,212,2,11,213,14,240,1,213,211,223,233,100,304,12)
    },
    @{
        Msg=27; C4=110; C5=201; C6=234; C7=13;  C8=133;
        Payload = @(110,122,101,103,131,233,212,114,201,20,234,240,13,11,141,133,33,124,142,133,30,23,113,110,120)
    },
    @{
        Msg=32; C4=21;  C5=123; C6=243; C7=233; C8=140;
        Payload = @(21,142,140,213,233,234,304,100,123,140,243,142,233,200,114,140,303,101,304,212,4,211,42,220,33)
    },
    @{
        Msg=37; C4=311; C5=101; C6=204; C7=211; C8=243;
        Payload = @(311,43,44,200,212,110,241,300,101,233,204,212,211,200,241,243,24,41,13,112,101,223,10,122,34)
    },
    @{
        Msg=42; C4=232; C5=101; C6=131; C7=12;  C8=210;
        Payload = @(232,203,12,114,112,110,111,34,101,13,114,141,12,110,241,210,114,300,204,14,11,220,10,43,100)
    }
)

# --- Decode one instruction --------------------------------------

function Decode-Instruction {
    param($inst)

    [pscustomobject]@{
        Msg      = $inst.Msg
        Type     = $Types[$inst.C4]
        Modifier = $Modifiers[$inst.C5]
        Action   = $Actions[$inst.C6]
        Target   = $Targets[$inst.C7]
        Outcome  = $Outcomes[$inst.C8]
        Payload  = $inst.Payload
    }
}

# --- Pretty semantic line ----------------------------------------

function Format-InstructionSemantic {
    param($dec)

    "Msg {0}: {1} ({2}) performs {3} on {4} → {5}" -f `
        $dec.Msg, $dec.Type, $dec.Modifier, $dec.Action, $dec.Target, $dec.Outcome
}

# --- VM: apply a sequence and track state + operands --------------

function Invoke-EyeVM {
    param(
        [int[]] $MessageOrder
    )

    $state        = "INIT"
    $log          = @()
    $prevOperands = $null

    foreach ($msgId in $MessageOrder) {

        $inst = $Instructions | Where-Object { $_.Msg -eq $msgId }
        if (-not $inst) { throw "Unknown Msg $msgId" }

        $dec = Decode-Instruction $inst

        if (-not $dec.Payload) {
            throw "Instruction Msg $($dec.Msg) has no Payload attached."
        }

        $payload  = $dec.Payload
        $operands = Get-OperandsFromPayload $payload

        $compatible = $true
        $note       = ""

        if ($null -ne $prevOperands) {
            if ( ($prevOperands.C9  -ne $operands.C1) -or
                 ($prevOperands.C10 -ne $operands.C2) ) {

                $compatible = $false
                $note = "Operand mismatch: prev(C9,C10)=$($prevOperands.C9),$($prevOperands.C10) vs curr(C1,C2)=$($operands.C1),$($operands.C2)"
            }
        }

        $log += [pscustomobject]@{
            Msg        = $dec.Msg
            Before     = $state
            After      = $dec.Outcome
            Text       = (Format-InstructionSemantic $dec)
            Payload    = ($payload -join " ")
            C1         = $operands.C1
            C2         = $operands.C2
            C3         = $operands.C3
            C9         = $operands.C9
            C10        = $operands.C10
            Compatible = $compatible
            Note       = $note
        }

        $state        = $dec.Outcome
        $prevOperands = $operands
    }

    return $log
}

# --- Random path tester (optional) -------------------------------

function Test-AllPaths {
    param([int] $Samples = 2000)

    $results = @()

    for ($s = 0; $s -lt $Samples; $s++) {

        $perm = ($Instructions.Msg | Get-Random -Count 9)
        $log  = Invoke-EyeVM -MessageOrder $perm
        $valid = $true

        $states = $log.After
        for ($i=1; $i -lt $states.Count; $i++) {

            $prev = $StateRank[$states[$i-1]]
            $curr = $StateRank[$states[$i]]

            if ($curr -lt $prev -and $states[$i] -ne "R_MULTI1") {
                $valid = $false
                break
            }
        }

        if ($valid) {
            $results += [pscustomobject]@{
                Path       = ($perm -join ",")
                FinalState = $states[-1]
            }
        }
    }

    return $results
}

"EyeVM loaded (operand-aware)."

# --- Exhaustive valid path + trace generator ----------------------

function Get-AllValidPathsAndTraces {

    $allPaths  = @()
    $allTraces = @()

    # Nested recursive walker
    function Walk {
        param(
            [int[]] $Path,
            [int[]] $Remaining,
            [string] $State,
            $PrevOperands
        )

        if ($Remaining.Count -eq 0) {
            $allPaths += ,$Path
            return
        }

        foreach ($msgId in $Remaining) {

            $inst = $Instructions | Where-Object { $_.Msg -eq $msgId }
            if (-not $inst) { continue }

            $dec      = Decode-Instruction $inst
            $outcome  = $dec.Outcome
            $payload  = $dec.Payload
            $operands = Get-OperandsFromPayload $payload

            # State monotonicity check
            $prevRank = ($StateRank[$State]  | ForEach-Object { $_ }) # handle INIT
            if (-not $prevRank) { $prevRank = 0 }
            $currRank = $StateRank[$outcome]

            if ($currRank -lt $prevRank -and $outcome -ne "R_MULTI1") {
                continue
            }

            # Operand compatibility check
            if ($null -ne $PrevOperands) {
                if ( ($PrevOperands.C9  -ne $operands.C1) -or
                     ($PrevOperands.C10 -ne $operands.C2) ) {
                    continue
                }
            }

            $newPath      = $Path + $msgId
            $newRemaining = $Remaining | Where-Object { $_ -ne $msgId }

            Walk -Path $newPath -Remaining $newRemaining -State $outcome -PrevOperands $operands
        }
    }

    # Kick off from INIT with all 9 messages available
    $allMsgIds = $Instructions.Msg
    Walk -Path @() -Remaining $allMsgIds -State "INIT" -PrevOperands $null

    Write-Host "Found $($allPaths.Count) valid paths."

    # Run VM on each valid path and collect traces
    $pathIndex = 0
    foreach ($path in $allPaths) {
        $pathIndex++
        $log = Invoke-EyeVM -MessageOrder $path

        $step = 0
        foreach ($entry in $log) {
            $step++
            $allTraces += [pscustomobject]@{
                PathId    = $pathIndex
                Step      = $step
                Msg       = $entry.Msg
                Before    = $entry.Before
                After     = $entry.After
                Text      = $entry.Text
                Payload   = $entry.Payload
                C1        = $entry.C1
                C2        = $entry.C2
                C3        = $entry.C3
                C9        = $entry.C9
                C10       = $entry.C10
                Compatible= $entry.Compatible
                Note      = $entry.Note
            }
        }
    }

    Write-Host "Collected $($allTraces.Count) trace rows."

    $allTraces | Export-Csv -Path ".\EyeVM_traces.csv" -NoTypeInformation -Encoding UTF8

    return @{
        Paths  = $allPaths
        Traces = $allTraces
    }
}

"Exhaustive path generator loaded. Call Get-AllValidPathsAndTraces to build dataset."

function Get-AllValidPathsAndTraces {
    param([int] $MaxDepth = 9)

    $script:allPaths  = @()
    $script:allTraces = @()

    function Walk {
        param(
            [int[]] $Path,
            [int] $Depth
        )

        if ($Depth -ge $MaxDepth) {
            if ($Path.Count -ge 2) {
                $script:allPaths += ,$Path
            }
            return
        }

        foreach ($inst in $Instructions) {
            Walk -Path ($Path + $inst.Msg) -Depth ($Depth + 1)
        }
    }

    Walk -Path @() -Depth 0

    Write-Host "Found $($script:allPaths.Count) raw paths."

    $pathIndex = 0
    foreach ($path in $script:allPaths) {
        $pathIndex++
        $log = Invoke-EyeVM -MessageOrder $path

        $step = 0
        foreach ($entry in $log) {
            $step++
            $script:allTraces += [pscustomobject]@{
                PathId     = $pathIndex
                Step       = $step
                Msg        = $entry.Msg
                Before     = $entry.Before
                After      = $entry.After
                Text       = $entry.Text
                Payload    = $entry.Payload
                C1         = $entry.C1
                C2         = $entry.C2
                C3         = $entry.C3
                C9         = $entry.C9
                C10        = $entry.C10
                Compatible = $entry.Compatible
                Note       = $entry.Note
            }
        }
    }

    Write-Host "Collected $($script:allTraces.Count) trace rows."

    $script:allTraces | Export-Csv -Path ".\EyeVM_traces.csv" -NoTypeInformation -Encoding UTF8

    return @{
        Paths  = $script:allPaths
        Traces = $script:allTraces
    }
}
