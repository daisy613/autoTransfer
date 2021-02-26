# autoTransfer

![](https://i.imgur.com/Jue4pgc.png)

- transfers profits automatically on multiple binance futures accounts
- define in autoTrasnfer.json file the profitPercent you want transferred, minRemainingBalance, maxMarginUsedPercent, and period in hours
- if the following conditions are true:
  - marginUsedPercentCurr is < maxMarginUsedPercent
  - ($totalBalance - $percentsOfProfit/100 * $profit) is > minRemainingBalance
  - profit in the past X hours is positive
- then transfer ($percentsOfProfit * $profit) to Spot and send Discord message
- if any of the conditions are false, then send discord alert and try again once an hour
- sleep for X $hours and repeat ad infinitum
