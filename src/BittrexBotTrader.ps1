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

    [Int] $EMAShortCount = 8
    [Int] $EMALongCount = 21
    [Int] $EMADiffIncreaseTriggerCount = 3

    [Int] $EMADiffIncreaseCount = 0
    [Int] $CycleCount = 0
    
    [Bool] $OpenPosition = $false

    [Bool] $Continue = $true

#endregion


##region Main
    
    $Log = @()

    $LastLogItem = New-Object -TypeName PSObject

    $MarketInfo = Get-BittrexMarkets | Where-Object {$_.MarketName -eq $Market}

    Do {

        $LogItem = New-Object -TypeName PSObject
        ++$CycleCount
        $LogItem | Add-Member -MemberType NoteProperty -TypeName [DateTime] -Name "CycleCount" -Value $CycleCount

        # Log CycleStart
        [DateTime] $CycleStart = Get-Date
        $LogItem | Add-Member -MemberType NoteProperty -TypeName [DateTime] -Name "CycleStart" -Value $CycleStart


        #region Trading Logic
            
            # Get Balances
            $BaseCurrenyBalance = Get-BittrexBalance -ApiKey $ApiKey -ApiSecret $ApiSecret -Currency $MarketInfo.BaseCurrency
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [Object] -Name "BaseCurrenyBalance" -Value $BaseCurrenyBalance.Balance
            
            $MarketCurrencyBalance = Get-BittrexBalance -ApiKey $ApiKey -ApiSecret $ApiSecret -Currency $MarketInfo.MarketCurrency
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [Object] -Name "MarketCurrencyBalance" -Value $MarketCurrencyBalance.Balance
        
            # Get Ticker
            $MarketTicker = Get-BittrexTicker -Market $Market
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [Object] -Name "Bid" -Value $MarketTicker.Bid
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [Object] -Name "Ask" -Value $MarketTicker.Ask
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [Object] -Name "Last" -Value $MarketTicker.Last
        
            # Get Market History
            $MarketHistory = Get-BittrexMarketHistory -Market $Market | Where-Object {$_.OrderType -eq "SELL"}
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [Object] -Name "MarketHistory" -Value $MarketHistory

            # Generate EMAShort
            [Decimal] $EMAShort = ($MarketHistory | Sort-Object -Property TimeStamp -Descending | Select-Object -First $EMAShortCount | Measure-Object -Property Price -Average).Average
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [Decimal] -Name "EMAShort" -Value $EMAShort

            # Generate EMALong
            [Decimal] $EMALong = ($MarketHistory | Sort-Object -Property TimeStamp -Descending | Select-Object -First $EMALongCount | Measure-Object -Property Price -Average).Average
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [Decimal] -Name "EMALong" -Value $EMALong

            # Generate EMADiff
            [Decimal] $EMADiff = $EMAShort - $EMALong
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [Decimal] -Name "EMADiff" -Value $EMADiff

            # Compare EMADiff to $LastLogItem.EMADiff
            if ($CycleCount -gt 1) {
                if ($EMADiff -gt $LastLogItem.EMADiff -and $EMADiff -gt 0) {

                    ++$EMADiffIncreaseCount
    
                } elseif ($EMADiff -lt $LastLogItem.EMADiff -and $EMADiffIncreaseCount -gt 0) {
    
                    --$EMADiffIncreaseCount
    
                } elseif ($EMADiff -lt 0 -and $EMADiffIncreaseCount -gt 0) {
    
                    --$EMADiffIncreaseCount
    
                }
            }
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [Int] -Name "EMADiffIncreaseCount" -Value $EMADiffIncreaseCount

            # Buy, Sell or Hold
            [String] $Action = $null
            if ($EMADiffIncreaseCount -ge $EMADiffIncreaseTriggerCount -and $OpenPosition -eq $false) {

                # Buy
                $Action = "BUY"
                $OpenPosition = $true

            } elseif ($EMADiffIncreaseCount -ge $EMADiffIncreaseTriggerCount -and $OpenPosition -eq $true) {

                # Hold
                $Action = "HODL"
        
            } elseif ($EMADiffIncreaseCount -lt $EMADiffIncreaseTriggerCount -and $OpenPosition -eq $true -or $EMADiffIncreaseCount -lt $LastLogItem.EMADiffIncreaseCount -and $OpenPosition -eq $true) {

                # Sell
                $Action = "SELL"
                $OpenPosition = $false

            } else {

                # Wait
                $Action = "WAIT"
                $OpenPosition = $false

            }
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [Int] -Name "Action" -Value $Action
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [Int] -Name "OpenPosition" -Value $OpenPosition

        #endregion


        # Log CycleEnd
        [DateTime] $CycleEnd = Get-Date
        $LogItem | Add-Member -MemberType NoteProperty -TypeName [DateTime] -Name "CycleEnd" -Value $CycleEnd

        # Wait
        [TimeSpan] $CycleDuration = New-TimeSpan -Start $CycleStart -End $CycleEnd
        $LogItem | Add-Member -MemberType NoteProperty -TypeName [DateTime] -Name "CycleDurationTotalSeconds" -Value $CycleDuration.TotalSeconds

        if ($CycleDuration.TotalSeconds -lt $MinCycleDuration) {

            $WaitSeconds = $MinCycleDuration - $CycleDuration.TotalSeconds
            
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [DateTime] -Name "WaitSeconds" -Value $WaitSeconds
            Start-Sleep -Seconds $WaitSeconds

        }

        # Save Log
        $LastLogItem = $LogItem
        $Log += $LogItem

        # Output LogItem
        $LogItem | Select-Object -Property CycleStart, CycleDurationTotalSeconds, CycleEnd, BaseCurrenyBalance, MarketCurrenyBalance, Bid, Ask, Last, EMALong, EMAShort, EMADiff, EMADiffIncreaseCount, Action
        $LogItem | Export-Csv -Path "$($PSScriptRoot)\Logs\BittrexBottrader-$($SessionUid).csv" -NoTypeInformation -Append

    } until ($Continue -eq $false)

    

#endregion
