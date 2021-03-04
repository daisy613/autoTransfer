# AutoTransfer

![success](https://i.imgur.com/anwQJrq.png)

![failure](https://i.imgur.com/7AtDANL.png)

![restart](https://i.imgur.com/H8EUUEw.png)

![discord](https://i.imgur.com/GcAIelz.png)

## What it does:
- this PowerShell script continuously transfers a percentage of profits automatically on a Binance Futures account, from Futures to Spot wallet, at a predefined interval (for multiple accounts, just create a new folder and run a new instance of the script from it, with a new autoTransfer.json file).
- if the following conditions are true:
  - marginUsedPercentCurr is < maxMarginUsedPercent.
  - ($totalBalance - $percentsOfProfit/100 * $profit) is > minRemainingBalance.
  - profit in the past X hours is positive.
- then transfers ($percentsOfProfit * $profit) to Spot and sends Discord message.
- if any of the conditions are false, then sends discord alert and tries again once an hour.
- sleeps for X $hours and repeats ad infinitum.

## Instructions:
- define in autoTransfer.json file the profitPercent you want transferred, minRemainingBalance, maxMarginUsedPercent, and period in hours.
- submit any issues or enhancement ideas on the [Issues](https://github.com/daisy613/autoTransfer/issues) page.

## To do:
- check for transfers within the past X hours when script starts, and don't transfer if found any.

## Tips:
- BTC: 1PV97ppRdWeXw4TBXddAMNmwnknU1m37t5
- ETH  (ERC20): 0x56b2239c6bde5dc1d155b98867e839ac502f01ad
- USDT (TRC20): TNuwZebdZmoDxrJRxUbyqzG48H4KRDR7wB
- USDT (ERC20): 0x56b2239c6bde5dc1d155b98867e839ac502f01ad
