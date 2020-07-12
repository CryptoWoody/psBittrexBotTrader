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
            "args":["-ApiKey 'xxx' -ApiSecret 'xxx'"],
            "cwd": "${workspaceFolder}"
        }
    ]
}
```