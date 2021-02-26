# AutoTransfer

![success](https://i.imgur.com/RrG82RK.png)

![failure](https://i.imgur.com/7AtDANL.png)

![discord](https://i.imgur.com/GcAIelz.png)

## What it does:
- transfers profits automatically on a single binance futures accounts (for multiple accounts, just create a new folder and run a new instance of the script from it).
- if the following conditions are true:
  - marginUsedPercentCurr is < maxMarginUsedPercent
  - ($totalBalance - $percentsOfProfit/100 * $profit) is > minRemainingBalance
  - profit in the past X hours is positive
- then transfers ($percentsOfProfit * $profit) to Spot and sends Discord message
- if any of the conditions are false, then sends discord alert and tries again once an hour
- sleeps for X $hours and repeats ad infinitum

## Instructions:
- define in autoTransfer.json file the profitPercent you want transferred, minRemainingBalance, maxMarginUsedPercent, and period in hours

## To do:
- check for transfers within the past X hours when script starts, and don't transfer if found any.
