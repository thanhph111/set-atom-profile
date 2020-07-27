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
Version 1.0 - initial release of Switch-Package
Version 1.1 - add Strict and SuppressOutput parameters

.EXAMPLE
PS> Switch-Package -ProfileName necessary
The example above enable all packages in `necessary` file

.EXAMPLE
PS> Switch-Package -ProfileName null -SuppressOutput
The example above disable all installed packages in silent mode.

.LINK
<script directory>\README.md
#>

function Switch-Package {
  param(
    [Parameter(Mandatory = $true, HelpMessage = "Profile's name containing list of packages.")]
    [string]$ProfileName,
    [Parameter(HelpMessage = "Strictly enable only packages in profile file.")]
    [switch]$Strict = $false,
    [Parameter(HelpMessage = "Remove reponses from command.")]
    [switch]$SuppressOutput = $false
  )

  #
  $Path = $PSScriptRoot + "\profile\"

  # Get necessary packages
  $NecessaryPackages = Get-Content -Path ($Path + "necessary") | Where-Object { $_.trim() -ne "" }
  # Get all installed packages
  $AllPackages = apm list --bare --installed --packages --no-versions

  # Check parameters
  if ($ProfileName -eq "null") {
    $EnablePackages = ""
    "Disable all packages."
  }
  elseif ($ProfileName -eq "necessary") {
    $EnablePackages = $NecessaryPackages
    "Enable all necessary packages."
  }
  elseif (!(Test-Path ($Path + $ProfileName) -PathType Leaf)) {
    "Profile '$ProfileName' not found in '$Path'."
    return
  }
  else {
    $ProfilePackages = Get-Content -Path ($Path + $ProfileName) | Where-Object { $_.trim() -ne "" }
    if ($Strict) { $EnablePackages = $ProfilePackages }
    else { $EnablePackages = $NecessaryPackages + $ProfilePackages }
  }

  # Get packages disabled
  $DisablePackages = $AllPackages | Where-Object { $_ -notin $EnablePackages }

  # Enable/disable these packages
  foreach ($package in $EnablePackages) {
    if ($SuppressOutput) { apm enable $package 2>&1 | Out-Null }
    else { apm enable $package }
  }

  foreach ($package in $DisablePackages) {
    if ($SuppressOutput) { apm disable $package 2>&1 | Out-Null }
    else { apm disable $package }
  }
}
