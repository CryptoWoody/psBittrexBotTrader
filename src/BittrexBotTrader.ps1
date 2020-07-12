<#

    .SYNOPSIS
    PowerShell script to automatically trade a market on the Bittrex exchange.

#>

Param (

    [Parameter(Mandatory=$true)]
    [String] $ApiKey,

    [Parameter(Mandatory=$true)]
    [String] $ApiSecret

)
    
Import-Module "./src/BittrexApiWrapper.psm1"

$MinCycleDuration = 10
$Continue = $true

Do {

    [DateTime] $CycleStart = Get-Date

    # Insert Trading Logic Here...

    [DateTime] $CycleEnd = Get-Date
    [TimeSpan] $CycleDuration = New-TimeSpan -Start $CycleStart -End $CycleEnd
    if ($CycleDuration.TotalSeconds -lt $MinCycleDuration) {

        $SleepSeconds = $MinCycleDuration - $CycleDuration.TotalSeconds
        Start-Sleep -Seconds $SleepSeconds

    }

} until ($Continue -eq $false)
