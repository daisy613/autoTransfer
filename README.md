# :blossom: AutoTransfer
(from [WH scripts collection](https://github.com/daisy613/wickHunter-scripts))

![success](https://i.imgur.com/Xjx5a3M.png)

![failure](https://i.imgur.com/d751AlK.png)

![re-attempt](https://i.imgur.com/rA4xj5r.png)

![discord](https://i.imgur.com/GcAIelz.png)

## What it does:
- this PowerShell script continuously transfers a percentage of profits automatically on a Binance Futures account, from Futures to Spot wallet, at a predefined interval.
- if the following conditions are true:
  - Current used margin (open orders are taken into account here) is less than the defined maximum (marginUsedPercentMax < maxMarginUsedPercent from the json file)
  - The remaining balance after the transfer is more than the defined minimum remaining balance (($totalBalance - $percentsOfProfit/100 * $profit) is > minRemainingBalance)
  - profit in the past X hours is positive.
- checks for transfers within the past X hours when script starts, and doesn't perform a transfer if found any.
- transfers the defined percentage of the profit ($percentsOfProfit * $profit) to Spot and sends Discord message.
- if any of the conditions are false, then sends discord alert and tries again once an hour.
- sleeps for X $hours and repeats ad infinitum.

## Instructions:
- drop the script file and the json settings file into the same folder with your bot.
- define the following in autoTransfer.json file
  - **profitPercent**: the percentage of the profit of the past X hours you want transferred.
  - **minRemainingBalance**: minimum remaining balance after the transfer.
  - **maxMarginUsedPercent**: maximum used margin above which transfers should not occur (this includes the open orders).
  - **hours**: the period in hours of how often to perform transfers.
  - **proxy**: (optional) IP proxy and port to use (example "http://25.12.124.35:2763"). Leave blank if no proxy used (""). Get proxy IPs [here](https://www.webshare.io/?referral_code=wn3nlqpeqog7).
- submit any issues or enhancement ideas on the [Issues](https://github.com/daisy613/autoTransfer/issues) page.

## Donations/Tips:
- USDT (TRC20): `TWhjv6ita4Y1i2xevTjxgB6g92yZLpkTwv`
- BTC: `13nsGbe7A7K1SR2KpJHRPH9eArKf823T9o`
