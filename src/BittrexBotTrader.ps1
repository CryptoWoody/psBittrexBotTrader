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
        [Int] $MinCycleDuration,

        [Parameter(Mandatory=$true, HelpMessage="The number of prices to include in the average to get the short EMA.")]
        [Int] $EMAShortCount,

        [Parameter(Mandatory=$true, HelpMessage="The number of prices to include in the average to get the long EMA.")]
        [Int] $EMALongCount,

        [Parameter(Mandatory=$true, HelpMessage="The number of EMADiff increases to trigger a buy.")]
        [Int] $EMADiffBuyTrigger,

        [Parameter(Mandatory=$true, HelpMessage="The number of EMADiff decreases to trigger a sell.")]
        [Int] $EMADiffSellTrigger

    )

#endregion


#region Import Modules

    Import-Module "$($PSScriptRoot)\BittrexApiWrapper.psm1"

#endregion


#region Settings

    [Int] $BittrexBotTraderVersion = 0

    [String] $SessionUid = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"

    [Int] $EMADiffProgress = 0
    [Int] $CycleCount = 0
    
    [Bool] $OpenPosition = $false

    [Bool] $Continue = $true

#endregion


##region Main
    
    $Log = @()
    $Positions = @()

    $LastLogItem = New-Object -TypeName PSObject
    $Position = New-Object -TypeName PSObject

    $MarketInfo = Get-BittrexMarkets | Where-Object {$_.MarketName -eq $Market}

    $SessionConfig = New-Object -TypeName PSObject
    $SessionConfig | Add-Member -MemberType NoteProperty -TypeName [Int] -Name "BittrexBotTraderVersion" -Value $BittrexBotTraderVersion
    $SessionConfig | Add-Member -MemberType NoteProperty -TypeName [String] -Name "Market" -Value $Market
    $SessionConfig | Add-Member -MemberType NoteProperty -TypeName [String] -Name "MinCycleDuration" -Value $MinCycleDuration
    $SessionConfig | Add-Member -MemberType NoteProperty -TypeName [String] -Name "EMAShortCount" -Value $EMAShortCount
    $SessionConfig | Add-Member -MemberType NoteProperty -TypeName [String] -Name "EMALongCount" -Value $EMALongCount
    $SessionConfig | Add-Member -MemberType NoteProperty -TypeName [String] -Name "EMADiffBuyTrigger" -Value $EMADiffBuyTrigger
    $SessionConfig | Add-Member -MemberType NoteProperty -TypeName [String] -Name "EMADiffSellTrigger" -Value $EMADiffSellTrigger
    $SessionConfig | Add-Member -MemberType NoteProperty -TypeName [Object] -Name "MarketInfo" -Value $MarketInfo
    $SessionConfig | ConvertTo-JSON | Out-File -FilePath "$($PSScriptRoot)\Logs\BittrexBottrader-$($SessionUid).json" -Force

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

            # Calculate EMADiffProgress
            if ($CycleCount -gt 1) {

                if ($EMADiff -gt $LastLogItem.EMADiff) {

                    # Up
                    if ($EMADiffProgress -gt 0) {

                        ++$EMADiffProgress

                    } else {

                        $EMADiffProgress = 1

                    }

                } elseif ($EMADiff -lt $LastLogItem.EMADiff) {

                    # Down
                    if ($EMADiffProgress -lt 0) {

                        --$EMADiffProgress

                    } else {

                        $EMADiffProgress = -1

                    }

                }
            }
            $LogItem | Add-Member -MemberType NoteProperty -TypeName [Int] -Name "EMADiffProgress" -Value $EMADiffProgress

            # Buy, Sell or Hold
            [String] $Action = $null
            if ($OpenPosition -eq $false) {

                # No Open Position
                if ($EMADiffProgress -ge $EMADiffBuyTrigger) {

                    # Buy
                    $Action = "BUY"
                    $OpenPosition = $true

                    $Position = New-Object -TypeName PSObject
                    $Position | Add-Member -MemberType NoteProperty -TypeName [Int] -Name "BuyTime" -Value $CycleStart
                    $Position | Add-Member -MemberType NoteProperty -TypeName [Int] -Name "BuyPrice" -Value $MarketTicker.Bid

                } else {

                    # Hold
                    $Action = "WAIT"

                }
        
            } else {

                #Open Position
                if ($EMADiffProgress -le $EMADiffSellTrigger) {

                    # Sell
                    $Action = "SELL"
                    $OpenPosition = $false

                    $Position | Add-Member -MemberType NoteProperty -TypeName [Int] -Name "SellTime" -Value $CycleStart
                    $Position | Add-Member -MemberType NoteProperty -TypeName [Int] -Name "SellPrice" -Value $MarketTicker.Ask
                    $Position | Add-Member -MemberType NoteProperty -TypeName [Int] -Name "PriceDiff" -Value ($Position.SellPrice - $Position.BuyPrice)
                    $Positions += $Position

                    $Position | Select-Object -Property BuyTime, BuyPrice, SellTime, SellPrice, PriceDiff
                    $Position | Export-Csv -Path "$($PSScriptRoot)\Logs\BittrexBottrader-Posotions-$($SessionUid).csv" -NoTypeInformation -Append

                } else {

                    # Hold
                    $Action = "HODL"

                }

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
        $LogItem | Select-Object -Property CycleStart, CycleDurationTotalSeconds, CycleEnd, BaseCurrenyBalance, MarketCurrenyBalance, Bid, Ask, Last, EMALong, EMAShort, EMADiff, EMADiffProgress, Action
        $LogItem | Export-Csv -Path "$($PSScriptRoot)\Logs\BittrexBottrader-$($SessionUid).csv" -NoTypeInformation -Append

    } until ($Continue -eq $false)

#endregion
