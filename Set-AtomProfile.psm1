$Path = $PSScriptRoot + "\Profiles\"

$Tab = " " * 3
$ColorForNewEnabled = "Green"
$ColorForAlreadyEnabled = "DarkGreen"
$ColorForNewDisabled = "Red"
$ColorForAlreadyDisabled = "DarkRed"


function Write-Table {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Table
    )

    # Get the maximum item length
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
    $ProfileNames = (Get-ChildItem $Path).Name | Where-Object { $_ -like "$wordToComplete*" }
    return $ProfileNames
}


function Get-UniqueContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ProfileName
    )
    return Get-Content -Path ($Path + $ProfileName) |
        ForEach-Object { $_.trim() } | Where-Object { $_ -ne "" } | Select-Object -Unique
}


function Get-Subsets {
    param(
        [Parameter(Mandatory = $true)]
        [array]
        $Elements
    )
    $Subsets = @()
    for ($SubsetIndex = 1; $SubsetIndex -lt [math]::Pow(2, $Elements.length); $SubsetIndex++) {
        $Subset = @()
        for ($ElementIndex = 0; $ElementIndex -lt $Elements.length; $ElementIndex++) {
            if (($SubsetIndex -band (1 -shl ($Elements.length - $ElementIndex - 1))) -ne 0) {
                $Subset += $Elements[$ElementIndex]
            }
        }
        $Subsets += , $Subset
    }
    return $Subsets | Group-Object -Property Length | ForEach-Object { $_.Group | Sort-Object }
}


function Get-AtomProfileStatus {
    $ProfileNames = GetProfiles

    # Create a hashtable of packages
    $Packages = @{}
    foreach ($ProfileName in $ProfileNames) {
        $Packages.$ProfileName = Get-UniqueContent -ProfileName $ProfileName
    }

    # Get all combinations of the profiles
    $Subsets = Get-Subsets ($ProfileNames)

    # Get enabled and disabled packages
    $EnabledPackages = apm list --bare --installed --packages --enabled --no-versions
    $DisabledPackages = apm list --bare --installed --packages --disabled --no-versions
    $AllPackages = $EnabledPackages + $DisabledPackages

    # Check if no profile is set
    if (!($EnabledPackages)) {
        Write-Host "No package is enabled" -ForegroundColor Red
        return
    }

    # Check if all profiles are set
    if (!($DisabledPackages)) {
        Write-Host "All package are enabled" -ForegroundColor Green
        return
    }

    # Check if any combination is set
    foreach ($Subset in $Subsets) {
        $PackagesToEnable = @()
        foreach ($ProfileName in $Subset) { $PackagesToEnable += $Packages.$ProfileName }
        $PackagesToDisable = $AllPackages | Where-Object { $_ -notin $PackagesToEnable }

        $NewEnablePackages = @()
        $NewDisablePackages = @()
        foreach ($Package in $PackagesToEnable) {
            if ($Package -notin $EnabledPackages) {
                $NewEnablePackages += "$Package"
            }
        }
        foreach ($Package in $PackagesToDisable) {
            if ($Package -notin $DisabledPackages) {
                $NewDisablePackages += "$Package"
            }
        }

        if (!$NewEnablePackages -and !$NewDisablePackages) {
            $CurrentProfile = $Subset -join " + "
            break
        }
    }

    # Conclusion
    if ($CurrentProfile) {
        Write-Host "You are on " -NoNewline
        Write-Host $CurrentProfile -ForegroundColor Green
        return
    }
    Write-Host "You are on " -NoNewline
    Write-Host "no profile set" -ForegroundColor Red
    return
}


function Set-AtomProfile {
    <#
    .SYNOPSIS
    Set specific Atom profile(s).

    .DESCRIPTION
    Users should create a file containing a list of expected packages to be enabled in
    the 'Profiles' folder (in script root folder).
    The script will enable all packages in the file.
    All the remaining packages will be disabled.

    .PARAMETER ProfileNames
    'All', 'Nothing' or list of profile name.

    .PARAMETER OutputMode
    'Everything', 'BriefOnly' or 'Nothing'.

    .INPUTS
    System.String
        'All', 'Nothing' or list of profile name.

    .OUTPUTS
    None.

    .NOTES
    Author: thanhph111
    License: MIT

    .EXAMPLE
    PS> Set-AtomProfile -ProfileNames necessary, python -OutputMode Nothing
    The example above enables all packages listed in 'necessary' and 'python' file silently.

    .EXAMPLE
    PS> Set-AtomProfile -ProfileNames Nothing
    The example above disable all installed packages.

    .LINK
    README.md
    #>

    param(
        [Parameter(Mandatory = $true, HelpMessage = "Profile's name containing list of packages.")]
        [string[]]
        $ProfileNames,

        [Parameter(HelpMessage = "Choose the way you like for output messages.")]
        [ValidateSet("Everything", "BriefOnly", "Nothing")]
        [string]
        $OutputMode = "Everything"
    )

    # Get all installed packages
    $EnabledPackages = apm list --bare --installed --packages --enabled --no-versions
    $DisabledPackages = apm list --bare --installed --packages --disabled --no-versions
    $AllPackages = $EnabledPackages + $DisabledPackages

    # Get packages to enable
    $PackagesToEnable = @()
    if (($ProfileNames.length -eq 1) -and ($ProfileNames -eq "Nothing")) {
        $PackagesToEnable = $null
        Write-Output "Disable all packages.`n"
    } elseif (($ProfileNames.length -eq 1) -and ($ProfileNames -eq "All")) {
        $PackagesToEnable = $AllPackages
        Write-Output "Enable all packages.`n"
    } else {
        foreach ($ProfileName in $ProfileNames) {
            if (!(Test-Path ($Path + $ProfileName) -PathType Leaf)) {
                Write-Warning "Profile '$ProfileName' is not found in '$Path', ignored."
            } else {
                $PackagesToEnable += Get-UniqueContent -ProfileName $ProfileName
            }
        }
        if (!($PackagesToEnable)) {
            Write-Output "Nothing to process."
            return
        }
    }

    # Verify packages
    foreach ($Package in $PackagesToEnable) {
        if ($Package -notin $AllPackages) {
            Write-Warning "$Package is not found, ignored. Check the name again."
            $PackagesToEnable = @($PackagesToEnable | Where-Object { $_ -ne $Package })
        }
    }

    # Get packages to disable
    $PackagesToDisable = $AllPackages | Where-Object { $_ -notin $PackagesToEnable }

    if ($OutputMode -eq "BriefOnly") {
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

    # Enable/disable these packages
    foreach ($Package in $PackagesToEnable) {
        if ($OutputMode -eq "Everything") {
            Write-Output $Package
        }
        if ($Package -in $EnabledPackages) {
            if ($OutputMode -eq "Everything") {
                Write-Host "$Tab Already enabled`n" -ForegroundColor $ColorForAlreadyEnabled
            }
        } else {
            apm enable $Package 2>&1 | Out-Null
            if ($OutputMode -eq "Everything") {
                Write-Host "$Tab Enabled`n" -ForegroundColor $ColorForNewEnabled
            }
        }
    }
    foreach ($Package in $PackagesToDisable) {
        if ($OutputMode -eq "Everything") {
            Write-Output $Package
        }
        if ($Package -in $DisabledPackages) {
            if ($OutputMode -eq "Everything") {
                Write-Host "$Tab Already disabled`n" -ForegroundColor $ColorForAlreadyDisabled
            }
        } else {
            apm disable $Package 2>&1 | Out-Null
            if ($OutputMode -eq "Everything") {
                Write-Host "$Tab Disabled`n" -ForegroundColor $ColorForNewDisabled
            }
        }
    }

    # Write brief table
    if ($OutputMode -ne "Nothing") {
        Write-Output "Result:"
        Write-Table -Table $Output
    }
}


$RegisterArgumentCompleterParams = @{
    CommandName   = "Set-AtomProfile"
    ParameterName = "ProfileNames"
    ScriptBlock   = $function:GetProfiles
}
Register-ArgumentCompleter @RegisterArgumentCompleterParams

Export-ModuleMember -Function Get-AtomProfileStatus, Set-AtomProfile
