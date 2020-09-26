$Path = $PSScriptRoot + "\profiles\"


function Write-Table {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Table
    )

    # Get the maximum item lenghth
    $ItemCounts = @()
    foreach ($item in $Table.values) {
        $ItemCounts += $item.length
    }
    $MaxItemCount = ($ItemCounts | Measure-Object -Maximum).Maximum

    $FinalArray = @()
    for ($Inc = 0; $Inc -lt $MaxItemCount; $Inc++) {
        $FinalObj = New-Object -TypeName PSCustomObject
        foreach ($Item in $Table.keys) {
            $FinalObj | Add-Member -MemberType NoteProperty -Name $Item -Value $Table[$Item][$Inc]
        }
        $FinalArray += $FinalObj
    }
    Write-Output $FinalArray
}


function GetProfiles {
    param(
        $commandName,
        $parameterName,
        $wordToComplete
    )
    $profiles = (Get-ChildItem $Path).Name | Where-Object { $_ -like "$wordToComplete*" }
    return $profiles
}


function Switch-AtomProfile {
    <#
    .SYNOPSIS
    Set specific Atom profile.

    .DESCRIPTION
    User should reate a <profile> file containing list of expected packages to be enable in `profile`
    folder (in script root folder).
    The script will enable all packages in <profile> file and `necessary` file.
    All the remaining packages will be disabled.

    .PARAMETER ProfileName
    'null' or <profile> file containing list of packages.

    .PARAMETER Strict
    Only enable packages in profile file.

    .PARAMETER SuppressOutput
    Quite mode - suppress all output.

    .INPUTS
    System.String
        'null' or <profile>

    .OUTPUTS
    None.

    .NOTES
    Author: thanhph111
    Last Edit: 2020-07-19
    Version 1.0 - initial release of Switch-AtomProfile
    Version 1.1 - add Strict parameters

    .EXAMPLE
    PS> Switch-AtomProfile -ProfileName necessary
    The example above enable all packages in `necessary` file

    .EXAMPLE
    PS> Switch-AtomProfile -ProfileName null
    The example above disable all installed packages.

    .LINK
    <script directory>\README.md
    #>

    param(
        [Parameter(Mandatory = $true, HelpMessage = "Profile's name containing list of packages.")]
        [string]$ProfileName,
        [Parameter(HelpMessage = "Strictly enable only packages in profile file.")]
        [switch]$Strict = $false,
        [Parameter(HelpMessage = "Choose the way you like for output messages.")]
        [ValidateSet("Everything", "BriefOnly", "Nothing")]
        [string]$OutputMode = $Everything
    )

    $Tab = " " * 3
    $ColorForEnabled = "Green"
    $ColorForAlreadyEnabled = "DarkGreen"
    $ColorForDisabled = "Red"
    $ColorForAlreadyDisabled = "DarkRed"

    # Get necessary packages
    $NecessaryPackages = Get-Content -Path ($Path + "necessary") | Where-Object { $_.trim() -ne "" }

    # Get all installed packages
    $EnabledPackages = apm list --bare --installed --packages --enabled --no-versions
    $DisabledPackages = apm list --bare --installed --packages --disabled --no-versions
    $AllPackages = $EnabledPackages + $DisabledPackages

    # Get packages to enable
    if ($ProfileName -eq "null") {
        $PackagesToEnable = ""
        "Disable all packages."
    } elseif ($ProfileName -eq "necessary") {
        $PackagesToEnable = $NecessaryPackages
        "Enable all necessary packages."
    } elseif (!(Test-Path ($Path + $ProfileName) -PathType Leaf)) {
        "Profile '$ProfileName' not found in '$Path'."
        return
    } else {
        $ProfilePackages = Get-Content -Path ($Path + $ProfileName) | Where-Object { $_.trim() -ne "" }
        if ($Strict) { $PackagesToEnable = $ProfilePackages }
        else { $PackagesToEnable = $NecessaryPackages + $ProfilePackages }
    }

    # Verify packages
    foreach ($Package in $PackagesToEnable) {
        if ($Package -notin $AllPackages) {
            Write-Warning "$Package is not found, ignored. Check the name again.`n"
            $PackagesToEnable = @($PackagesToEnable | Where-Object { $_ -ne $Package })
        }
    }

    # Get packages to disable
    $PackagesToDisable = $AllPackages | Where-Object { $_ -notin $PackagesToEnable }

    if ($OutputMode -ne "Nothing") {
        Write-Output "Processing...`n"
    }

    # Classify packages
    $Output = [ordered]@{
        "Already Enable"  = @()
        "New Enable"      = @()
        "Already Disable" = @()
        "New Disable"     = @()
    }
    foreach ($Package in $PackagesToEnable) {
        if ($Package -in $EnabledPackages) {
            $Output["Already Enable"] += "$Package"
        } else {
            $Output["New Enable"] += "$Package"
        }
    }
    foreach ($Package in $PackagesToDisable) {
        if ($Package -in $DisabledPackages) {
            $Output["Already Disable"] += "$Package"
        } else {
            $Output["New Disable"] += "$Package"
        }
    }

    # Write log
    if ($OutputMode -eq "Everything") {
        foreach ($Package in $PackagesToEnable) {
            Write-Output $Package
            if ($Package -in $EnabledPackages) {
                Write-Host "$Tab Already enabled`n" -ForegroundColor $ColorForAlreadyEnabled
            } else {
                Write-Host "$Tab Enabled`n" -ForegroundColor $ColorForEnabled
            }
        }
        foreach ($Package in $PackagesToDisable) {
            Write-Output $Package
            if ($Package -in $DisabledPackages) {
                Write-Host "$Tab Already disabled`n" -ForegroundColor $ColorForAlreadyDisabled
            } else {
                Write-Host "$Tab Disabled`n" -ForegroundColor $ColorForDisabled
            }
        }
    }

    # Enable/disable these packages
    foreach ($Package in $PackagesToEnable) {
        if ($Package -notin $EnabledPackages) {
            apm enable $Package 2>&1 | Out-Null
        }
    }
    foreach ($Package in $PackagesToDisable) {
        if ($Package -notin $DisabledPackages) {
            apm disable $Package 2>&1 | Out-Null
        }
    }

    # Write brief table
    if ($OutputMode -ne "Nothing") {
        Write-Table -Table $Output
    }
}


Register-ArgumentCompleter -CommandName Switch-AtomProfile -ParameterName ProfileName -ScriptBlock $function:GetProfiles
