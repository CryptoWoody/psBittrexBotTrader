<#

    .SYNOPSIS
    PowerShell functions which wrap the Bittrex API V1.1.

#>

Function Get-Nonce {

    [DateTime] $Now = Get-Date
    [DateTime] $Epoch = Get-Date "1/1/1970 8:00:00 AM"
    
    [TimeSpan] $TimeSinceEpoc = $Now.Subtract($Epoch)
    
    Return $TimeSinceEpoc.TotalSeconds

}

Function Get-BittrexAPIRequestSignature {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)] [String] $Url,
        [Parameter(Mandatory=$true)] [string] $ApiSecret
    )

    $HMACSHA512 = [System.Security.Cryptography.HMACSHA512]::new([System.Text.Encoding]::ASCII.GetBytes($ApiSecret))
    
    [byte[]] $MessageBytes = [System.Text.Encoding]::ASCII.GetBytes($Url)
    [byte[]] $MessageHash = $HMACSHA512.ComputeHash($MessageBytes)
    [String] $Signature = ([System.BitConverter]::ToString($MessageHash)).Replace("-","")

    Return $Signature

}

Function Get-BittrexAPIResponse {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)] [String] $Url,
        [Parameter(Mandatory=$false)] [Switch] $Secure,
        [Parameter(Mandatory=$false)] [string] $ApiKey = $null,
        [Parameter(Mandatory=$false)] [string] $ApiSecret = $null,
        [Parameter(Mandatory=$false)] [Long] $Nonce = $null
    )

    $Request = New-Object -TypeName System.Net.WebClient
    $Request.Headers.Add("Content-Type", "application/x-www-form-urlencoded")

    if ($Secure) {

        $Signature = Get-BittrexAPIRequestSignature -Url $Url -ApiSecret $ApiSecret
        
        $Request.Headers.Add("key", $ApiKey)
        $Request.Headers.Add("apisign", $Signature)

    }

    [byte[]] $ReturnBytes = $Request.UploadData($Url, "post", [System.Text.Encoding]::ASCII.GetBytes(""))
    [string] $ReturnString = [System.Text.Encoding]::ASCII.GetString($ReturnBytes)
    [Object] $Return = $ReturnString | ConvertFrom-Json

    if ($Return.success -ne $true) {

        Write-Error -Message $Return.message

    } else {

        Return $Return.Result

    }
    
}

$BittrexURLs = @{

    #Public
    "GetMarkets" = "https://bittrex.com/api/v1.1/public/getmarkets"
    "GetCurrencies" = "https://api.bittrex.com/api/v1.1/public/getcurrencies"
    "GetTicker" = "https://api.bittrex.com/api/v1.1/public/getticker?market={0}"
    "GetMarketSummaries" = "https://api.bittrex.com/api/v1.1/public/getmarketsummaries"
    "GetMarketSummary" = "https://api.bittrex.com/api/v1.1/public/getmarketsummary?market={0}"
    "GetOrderBook" = "https://api.bittrex.com/api/v1.1/public/getorderbook?market={0}&type={1}"
    "GetMarketHistory" = "https://api.bittrex.com/api/v1.1/public/getmarkethistory?market={0}"
    
    #Market
    "BuyLimit" = "https://api.bittrex.com/api/v1.1/market/buylimit?nonce={0}&apikey={1}&market={2}&quantity={3}&rate={4}&timeInForce={5}"
    "SellLimit" = "https://api.bittrex.com/api/v1.1/market/selllimit?nonce={0}&apikey={1}&market={2}&quantity={3}&rate={4}&timeInForce={5}"
    "Cancel" = "https://api.bittrex.com/api/v1.1/market/cancel?nonce={0}&apikey={1}&uuid={2}"
    "GetOpenOrders" = "https://api.bittrex.com/api/v1.1/market/getopenorders?nonce={0}&apikey={1}&market={2}"
    
    #Account
    "GetBalances" = "https://api.bittrex.com/api/v1.1/account/getbalances?nonce={0}&apikey={1}"
    "GetBalance" = "https://api.bittrex.com/api/v1.1/account/getbalance?nonce={0}&apikey={1}&currency={2}"
    "GetDepositAddress" = "https://api.bittrex.com/api/v1.1/account/getdepositaddress?nonce={0}&apikey={1}&currency={2}"
    "Withdraw" = "https://api.bittrex.com/api/v1.1/account/withdraw?nonce={0}&apikey={1}&currency={2}&quantity={3}&address={4}"
    "GetOrder" = "https://api.bittrex.com/api/v1.1/account/getorder?nonce={0}&apikey={1}&uuid={2}"
    "GetOrderHistory" = "https://api.bittrex.com/api/v1.1/account/getorderhistory?nonce={0}&apikey={1}"
    "GetWithdrawalHistory" = "https://api.bittrex.com/api/v1.1/account/getwithdrawalhistory?nonce={0}&apikey={1}"
    "GetDepositHistory" = "https://api.bittrex.com/api/v1.1/account/getdeposithistory?nonce={0}&apikey={1}&currency={2}"

}

Function Get-BittrexMarkets {

    $Return = Get-BittrexAPIResponse -Url $BittrexURLs.GetMarkets

    Return $Return
}

Function Get-BittrexCurrencies {

    $Return = Get-BittrexAPIResponse -Url $BittrexURLs.GetCurrencies

    Return $Return
}

Function Get-BittrexTicker {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $Market

    )

    $Url = [String]::Format($BittrexURLs.GetTicker, $Market)
    $Return = Get-BittrexAPIResponse -Url $Url

    Return $Return
}

Function Get-BittrexMarketSummaries {

    $Return = Get-BittrexAPIResponse -Url $BittrexURLs.GetMarketSummaries

    Return $Return
}

Function Get-BittrexMarketSummary {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $Market

    )

    $Url = [String]::Format($BittrexURLs.GetMarketSummary, $Market)
    $Return = Get-BittrexAPIResponse -Url $Url

    Return $Return

}

Function Get-BittrexOrderBook {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $Market,
        [Parameter(Mandatory=$true)] [ValidateSet("Buy","Sell","Both")]  [String] $Type

    )

    $Url = [String]::Format($BittrexURLs.GetOrderBook, $Market, $Type)
    $Return = Get-BittrexAPIResponse -Url $Url

    Return $Return

}

Function Get-BittrexMarketHistory {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $Market

    )

    $Url = [String]::Format($BittrexURLs.GetMarketHistory, $Market)
    $Return = Get-BittrexAPIResponse -Url $Url

    Return $Return

}

Function New-BittrexBuyLimitOrder {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $Market,
        [Parameter(Mandatory=$true)] [Float] $Quantity,
        [Parameter(Mandatory=$true)] [Float] $Rate,
        [Parameter(Mandatory=$true)] [String] $TimeInForce,
        [Parameter(Mandatory=$true)] [String] $ApiKey,
        [Parameter(Mandatory=$true)] [String] $ApiSecret


    )

    $Nonce = Get-Nonce
    $Url = [String]::Format($BittrexURLs.BuyLimit, $Nonce, $ApiKey, $Market, $Quantity, $Rate, $TimeInForce)
    $Return = Get-BittrexAPIResponse -Url $Url -Secure -ApiKey $ApiKey -ApiSecret $ApiSecret -Nonce $Nonce

    Return $Return

}

Function New-BittrexSellimitOrder {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $Market,
        [Parameter(Mandatory=$true)] [Float] $Quantity,
        [Parameter(Mandatory=$true)] [Float] $Rate,
        [Parameter(Mandatory=$true)] [String] $TimeInForce,
        [Parameter(Mandatory=$true)] [String] $ApiKey,
        [Parameter(Mandatory=$true)] [String] $ApiSecret

    )

    $Nonce = Get-Nonce
    $Url = [String]::Format($BittrexURLs.SellLimit, $Nonce, $ApiKey, $Market, $Quantity, $Rate, $TimeInForce)
    $Return = Get-BittrexAPIResponse -Url $Url -Secure -ApiKey $ApiKey -ApiSecret $ApiSecret -Nonce $Nonce

    Return $Return

}

Function Stop-BittrexOrder {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $Uuid,
        [Parameter(Mandatory=$true)] [String] $ApiKey,
        [Parameter(Mandatory=$true)] [String] $ApiSecret

    )

    $Nonce = Get-Nonce
    $Url = [String]::Format($BittrexURLs.Cancel, $Nonce, $ApiKey, $Uuid)
    $Return = Get-BittrexAPIResponse -Url $Url -Secure -ApiKey $ApiKey -ApiSecret $ApiSecret -Nonce $Nonce

    Return $Return

}

Function Get-BittrexOpenOrders {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $Market,
        [Parameter(Mandatory=$true)] [String] $ApiKey,
        [Parameter(Mandatory=$true)] [String] $ApiSecret

    )

    $Nonce = Get-Nonce
    $Url = [String]::Format($BittrexURLs.GetOpenOrders, $Nonce, $ApiKey, $Market)
    $Return = Get-BittrexAPIResponse -Url $Url -Secure -ApiKey $ApiKey -ApiSecret $ApiSecret -Nonce $Nonce

    Return $Return

}

Function Get-BittrexBalances {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $ApiKey,
        [Parameter(Mandatory=$true)] [String] $ApiSecret

    )

    $Nonce = Get-Nonce
    $Url = [String]::Format($BittrexURLs.GetBalances, $Nonce, $ApiKey)
    $Return = Get-BittrexAPIResponse -Url $Url -Secure -ApiKey $ApiKey -ApiSecret $ApiSecret -Nonce $Nonce

    Return $Return

}

Function Get-BittrexBalance {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $Currency,
        [Parameter(Mandatory=$true)] [String] $ApiKey,
        [Parameter(Mandatory=$true)] [String] $ApiSecret

    )

    $Nonce = Get-Nonce
    $Url = [String]::Format($BittrexURLs.GetBalance, $Nonce, $ApiKey, $Currency)
    $Return = Get-BittrexAPIResponse -Url $Url -Secure -ApiKey $ApiKey -ApiSecret $ApiSecret -Nonce $Nonce

    Return $Return

}

Function Get-BittrexDepositAddress {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $Currency,
        [Parameter(Mandatory=$true)] [String] $ApiKey,
        [Parameter(Mandatory=$true)] [String] $ApiSecret

    )

    $Nonce = Get-Nonce
    $Url = [String]::Format($BittrexURLs.GetDepositAddress, $Nonce, $ApiKey, $Currency)
    $Return = Get-BittrexAPIResponse -Url $Url -Secure -ApiKey $ApiKey -ApiSecret $ApiSecret -Nonce $Nonce

    Return $Return

}

Function Get-BittrexOrder {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $Uuid,
        [Parameter(Mandatory=$true)] [String] $ApiKey,
        [Parameter(Mandatory=$true)] [String] $ApiSecret

    )

    $Nonce = Get-Nonce
    $Url = [String]::Format($BittrexURLs.GetOrder, $Nonce, $ApiKey, $Uuid)
    $Return = Get-BittrexAPIResponse -Url $Url -Secure -ApiKey $ApiKey -ApiSecret $ApiSecret -Nonce $Nonce

    Return $Return

}

Function Get-BittrexOrderHistory {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $ApiKey,
        [Parameter(Mandatory=$true)] [String] $ApiSecret

    )

    $Nonce = Get-Nonce
    $Url = [String]::Format($BittrexURLs.GetOrderHistory, $Nonce, $ApiKey)
    $Return = Get-BittrexAPIResponse -Url $Url -Secure -ApiKey $ApiKey -ApiSecret $ApiSecret -Nonce $Nonce

    Return $Return

}

Function Get-BittrexWithdrawalHistory {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $ApiKey,
        [Parameter(Mandatory=$true)] [String] $ApiSecret

    )

    $Nonce = Get-Nonce
    $Url = [String]::Format($BittrexURLs.GetWithdrawalHistory, $Nonce, $ApiKey)
    $Return = Get-BittrexAPIResponse -Url $Url -Secure -ApiKey $ApiKey -ApiSecret $ApiSecret -Nonce $Nonce

    Return $Return

}

Function Get-BittrexDepositHistory {

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)] [String] $Currency,
        [Parameter(Mandatory=$true)] [String] $ApiKey,
        [Parameter(Mandatory=$true)] [String] $ApiSecret

    )

    $Nonce = Get-Nonce
    $Url = [String]::Format($BittrexURLs.GetDepositHistory, $Nonce, $ApiKey, $Currency)
    $Return = Get-BittrexAPIResponse -Url $Url -Secure -ApiKey $ApiKey -ApiSecret $ApiSecret -Nonce $Nonce

    Return $Return

}
