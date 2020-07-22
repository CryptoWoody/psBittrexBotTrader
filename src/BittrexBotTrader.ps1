<#

    .SYNOPSIS
    PowerShell script to automatically trade a market on the Bittrex exchange.

#>

#region Param

    Param (

        [Parameter(Mandatory=$true, HelpMessage="Your Bittrex API key.")]
        [String] $ApiKey,

        [Parameter(Mandatory=$true, HelpMessage="Your Bittrex API key.")]
        [String] $ApiSecret,

        [Parameter(Mandatory=$true, HelpMessage="The Bittrex Market to trade.")]
        [ValidateSet("BTC-ETH","BTC-LTC")]
        [String] $Market,

        [Parameter(Mandatory=$true, HelpMessage="The minium duration between cycle starts to ensure the script doesn't run too quickly!")]
        [Int] $MinCycleDuration

    )

#endregion


#region Import Modules

    Import-Module "$($PSScriptRoot)\BittrexApiWrapper.psm1"

#endregion


#region Settings

    [String] $SessionUid = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
    [Bool] $Continue = $true

#endregion


##region Main
    
    $Log = @()

    Do {

        $LogItem = New-Object -TypeName PSObject

        # Log CycleStart
        [DateTime] $CycleStart = Get-Date
        $LogItem | Add-Member -MemberType NoteProperty -TypeName [DateTime] -Name "CycleStart" -Value $CycleStart


        #region Trading Logic

            # Insert Trading Magic Here!
            Write-Host $LogItem.CycleStart

        #endregion


        # Log CycleEnd
        [DateTime] $CycleEnd = Get-Date
        $LogItem | Add-Member -MemberType NoteProperty -TypeName [DateTime] -Name "CycleEnd" -Value $CycleEnd

        # Wait
        [TimeSpan] $CycleDuration = New-TimeSpan -Start $CycleStart -End $CycleEnd
        if ($CycleDuration.TotalSeconds -lt $MinCycleDuration) {

            $WaitSeconds = $MinCycleDuration - $CycleDuration.TotalSeconds
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [DateTime] -Name "WaitSeconds" -Value $WaitSeconds
            Start-Sleep -Seconds $WaitSeconds

        }

        # Save Log
        $LastLogItem = $LogItem
        $Log += $LogItem

    } until ($Continue -eq $false)

    $Log | Export-Csv -Path "$($PSScriptRoot)\Logs\BittrexBottrader-$($SessionUid).csv" -NoTypeInformation

#endregion
