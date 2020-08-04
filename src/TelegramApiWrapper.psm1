<#

    .SYNOPSIS
    PowerShell functions which wrap the Telegram API. Needs much work.

#>

Function Send-TelegramChatMessage {

    Param (

        [Parameter(Mandatory=$true)]
        [String] $Token,

        [Parameter(Mandatory=$true)]
        [Long] $ChatId,

        [Parameter(Mandatory=$true)]
        [String] $Message
    
    )

    $Request = "https://api.telegram.org/bot$($Token)/sendMessage?chat_id=$($ChatId)&text=$($Message)"
    $Response = Invoke-RestMethod -Uri $Request

}