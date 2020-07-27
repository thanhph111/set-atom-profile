# [PSCustomObject] @{
#     Date     = Get-Date -Format d
#     Computer = [System.Environment]::MachineName
#     Username = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name
# } | Format-List


# $properties = @{
#     Date     = Get-Date -Format d
#     Computer = [System.Environment]::MachineName
#     Username = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name
# }
# New-Object -TypeName PSCustomObject -Property $properties | Format-List


# New-Object -TypeName PSObject -Property @{
#     Date     = Get-Date -Format d
#     Computer = [System.Environment]::MachineName
#     Username = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name
# } | Format-List


# $date = Get-Date -Format d
# $computer = [System.Environment]::MachineName
# $username = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name
# $result = New-Object -TypeName PSObject
# $result | Add-Member -MemberType Noteproperty -Name Date -Value $($date)
# $result | Add-Member -MemberType Noteproperty -Name Computer -Value $($computer)
# $result | Add-Member -MemberType Noteproperty -Name Username -Value $($username)
# $result | Format-List


# $Servers = "training01.us", "training02.us", "training03.us"
# $OFS = "`n"
# $table = @(@{ColumnA="$Servers";ColumnB='online'})
# $table.ForEach({[PSCustomObject]$_}) | Format-Table -AutoSize -Wrap


# $Array1 = "Data1A","Data2A","Data3A"
# $Array2 = "Data1B","Data2B","Data3B","Data4B"
# $Array3 = "Data1C","Data2C","Data3C"
#
# function Transpose-Data {
#   param(
#     [Parameter(Mandatory = $True)]
#     [string[]]$ArrayNames,
#     [switch]$NoWarnings = $False
#   )
#   $ValidArrays,$ItemCounts = @(),@()
#   $VariableLookup = @{}
#   foreach ($Array in $ArrayNames) {
#     try {
#       $VariableData = Get-Variable -Name $Array -ErrorAction Stop
#       $VariableLookup[$Array] = $VariableData.Value
#       $ValidArrays += $Array
#       $ItemCounts += ($VariableData.Value | Measure-Object).Count
#     }
#     catch {
#       if (!$NoWarnings) { Write-Warning -Message "No variable found for [$Array]" }
#     }
#   }
#
#   $MaxItemCount = ($ItemCounts | Measure-Object -Maximum).Maximum
#   $FinalArray = @()
#   for ($Inc = 0; $Inc -lt $MaxItemCount; $Inc++) {
#     $FinalObj = New-Object PsObject
#     foreach ($Item in $ValidArrays) {
#       $FinalObj | Add-Member -MemberType NoteProperty -Name $Item -Value $VariableLookup[$Item][$Inc]
#     }
#     $FinalArray += $FinalObj
#   }
#   $FinalArray
# }
#
# Transpose-Data -ArrayNames "Array1","Array2","Array3"

# https://stackoverflow.com/questions/22723954/powershell-autosize-and-specific-column-width

class Package {
  [string]$Name
  [switch]$Enable = $false
}

function foo {
  $Packages = [Package]::new()
  $Packages.Name = "minimap"
  $Packages.Enable = $true

  $Packages
}

foo
