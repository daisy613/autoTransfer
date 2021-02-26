# AutoTransfer

![success](https://i.imgur.com/9onjx6s.png)
![failure](https://i.imgur.com/Jue4pgc.png)

## What it does:
- transfers profits automatically on multiple binance futures accounts
- if the following conditions are true:
  - marginUsedPercentCurr is < maxMarginUsedPercent
  - ($totalBalance - $percentsOfProfit/100 * $profit) is > minRemainingBalance
  - profit in the past X hours is positive
- then transfers ($percentsOfProfit * $profit) to Spot and sends Discord message
- if any of the conditions are false, then sends discord alert and tries again once an hour
- sleeps for X $hours and repeats ad infinitum

## Instructions:
- define in autoTransfer.json file the profitPercent you want transferred, minRemainingBalance, maxMarginUsedPercent, and period in hours
