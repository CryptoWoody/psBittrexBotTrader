# PSBittrexBotTrader

## VSCode Launch.json
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "PowerShell: BittrexBotTrader.ps1",
            "type": "PowerShell",
            "request": "launch",
            "script": "${workspaceFolder}/src/BittrexBotTrader.ps1",
            "args":["-ApiKey 'xxx' -ApiSecret 'xxx' -Market 'BTC-ETH' -MinCycleDuration 10 -EMAShortCount 8 -EMALongCount 21 -EMADiffBuyTrigger 3 -EMADiffSellTrigger -1"],
            "cwd": "${workspaceFolder}"
        },
        {
            "name": "PowerShell: BittrexBotTrader.ps1 (Telegram Updates)",
            "type": "PowerShell",
            "request": "launch",
            "script": "${workspaceFolder}/src/BittrexBotTrader.ps1",
            "args":["-ApiKey 'xxx' -ApiSecret 'xxx' -Market 'BTC-ETH' -MinCycleDuration 10 -EMAShortCount 8 -EMALongCount 21 -EMADiffBuyTrigger 3 -EMADiffSellTrigger -1 -PostToTelegram -TelegramBotToken 'aaa:aaa' -TelegramChatId '-000'"],
            "cwd": "${workspaceFolder}"
        }
    ]
}
```