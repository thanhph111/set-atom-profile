$Path = $PSScriptRoot + "\Profiles\"


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
    Write-Output "Result:"
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


function Get-Subsets {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Elements
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


function Get-AtomProfile {
    $Subsets = Get-Subsets (GetProfiles)

    $EnabledPackages = apm list --bare --installed --packages --enabled --no-versions
    $DisabledPackages = apm list --bare --installed --packages --disabled --no-versions
    $AllPackages = $EnabledPackages + $DisabledPackages

    if (!($EnabledPackages)) {
        Write-Output "Nothing"
        return
    }
    if (!($DisabledPackages)) {
        Write-Output "All"
        return
    }

    foreach ($ProfileNames in $Subsets) {
        $PackagesToEnable = @()
        foreach ($ProfileName in $ProfileNames) {
            $PackagesToEnable += Get-Content -Path ($Path + $ProfileName) | Where-Object { $_.trim() -ne "" }
        }
        $PackagesToDisable = $AllPackages | Where-Object { $_ -notin $PackagesToEnable }

        $Output = [ordered]@{
            "New Enable"  = @()
            "New Disable" = @()
        }
        foreach ($Package in $PackagesToEnable) {
            if ($Package -notin $EnabledPackages) {
                $Output["New Enable"] += "$Package"
            }
        }
        foreach ($Package in $PackagesToDisable) {
            if ($Package -notin $DisabledPackages) {
                $Output["New Disable"] += "$Package"
            }
        }

        if (!($Output["New Enable"]) -and !($Output["New Disable"])) {
            Write-Output ($ProfileNames -join " + ")
            return
        }
    }

    Write-Output "Cannot detect profile"
    return
}


function Switch-AtomProfile {
    <#
    .SYNOPSIS
    Set specific Atom profile.

    .DESCRIPTION
    User should reate a <profile> file containing list of expected packages to be enable in 'profile'
    folder (in script root folder).
    The script will enable all packages in <profile> file and 'necessary' file.
    All the remaining packages will be disabled.

    .PARAMETER ProfileNames
    'All', 'Nothing' or list of <profile> names.

    .PARAMETER OutputMode
    'Everything', 'BriefOnly' or 'Nothing'.

    .INPUTS
    System.String
        'All', 'Nothing' or list of <profile> names.

    .OUTPUTS
    None.

    .NOTES
    Author: thanhph111
    Last Edit: 2020-09-28

    .EXAMPLE
    PS> Switch-AtomProfile -ProfileNames necessary, python
    The example above enable all packages listed in 'necessary' and 'python' file.

    .EXAMPLE
    PS> Switch-AtomProfile -ProfileNames Nothing
    The example above disable all installed packages.

    .LINK
    <script directory>\README.md
    #>

    param(
        [Parameter(Mandatory = $true, HelpMessage = "Profile's name containing list of packages.")]
        [string[]]$ProfileNames,
        [Parameter(HelpMessage = "Choose the way you like for output messages.")]
        [ValidateSet("Everything", "BriefOnly", "Nothing")]
        [string]$OutputMode = "Everything"
    )

    $Tab = " " * 3
    $ColorForEnabled = "Green"
    $ColorForAlreadyEnabled = "DarkGreen"
    $ColorForDisabled = "Red"
    $ColorForAlreadyDisabled = "DarkRed"

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
                $PackagesToEnable += Get-Content -Path ($Path + $ProfileName) | Where-Object { $_.trim() -ne "" }
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
                Write-Host "$Tab Enabled`n" -ForegroundColor $ColorForEnabled
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
                Write-Host "$Tab Disabled`n" -ForegroundColor $ColorForDisabled
            }
        }
    }

    # Write brief table
    if ($OutputMode -ne "Nothing") {
        Write-Table -Table $Output
    }
}


Register-ArgumentCompleter -CommandName Switch-AtomProfile -ParameterName ProfileNames -ScriptBlock $function:GetProfiles

Export-ModuleMember -Function Get-AtomProfile, Switch-AtomProfile
