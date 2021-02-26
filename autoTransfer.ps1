# - works with multiple binance accounts
# - define in autoTrasnfer.json file the profitPercent you want transferred, minRemainingBalance, maxMarginUsedPercent, and period in hours
# - if the following conditions are true:
#   - marginUsedPercentCurr is < maxMarginUsedPercent
#   - ($totalBalance - $percentsOfProfit/100 * $profit) is > minRemainingBalance
#   - profit in the past X hours is positive
# - then transfer ($percentsOfProfit * $profit) to Spot and send Discord message
# - if any of the conditions are false, then send discord alert and try again once an hour
# - sleep for X $hours and repeat ad infinitum

$version = "v1.0.0"
$path = Split-Path $MyInvocation.MyCommand.Path
$accounts = (gc "$($path)\autoTransfer.json" | ConvertFrom-Json) | ? { $_.enabled -eq "true" }
if (!($accounts)) { write-log "Cannot find autoTransfer.json file!" ; sleep 30 ; exit }
write-host "`n`n`n`n`n`n`n`n`n`n"

function checkLatest () {
    $repo = "daisy613/autoTransfer"
    $releases = "https://api.github.com/repos/$repo/releases"
    $latestTag = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name
    $youngerVer = ($version, $latestTag | Sort-Object)[-1]
    if ($latestTag -and $version -ne $youngerVer) {
        write-host "Your version of AutoTransfer [$($version)] is outdated. Newer version [$($latestTag)] is available here: https://github.com/$($repo)/releases/tag/$($latestTag)" -ForegroundColor Green
    }
}

Function write-log {
    Param ([string]$logstring)
    $Logfile = "$($path)\accountData.log"
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$date] $logstring" -ForegroundColor Yellow
    # Add-Content $Logfile -Value "[$date] $logstring"
}

function betterSleep () {
    Param ($seconds,$message)
    $doneDT = (Get-Date).AddSeconds($seconds)
    while($doneDT -gt (Get-Date)) {
        $hours = [math]::Round(($seconds / 3600),2)
        $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
        $percent = ($seconds - $secondsLeft) / $seconds * 100
        Write-Progress -Activity "$($message)" -Status "Sleeping $($hours) hour(s)..." -SecondsRemaining $secondsLeft -PercentComplete $percent
        [System.Threading.Thread]::Sleep(500)
    }
    Write-Progress -Activity "$($message)" -Status "Sleeping $($hours) hour(s)..." -SecondsRemaining 0 -Completed
}

function getAccount () {
    Param ($accountNum)
    $key = ($accounts | Where-Object { $_.number -eq $accountNum }).key
    $secret = ($accounts | Where-Object { $_.number -eq $accountNum }).secret
    $TimeStamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $QueryString = "&recvWindow=5000&timestamp=$TimeStamp"
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.key = [Text.Encoding]::ASCII.GetBytes($secret)
    $signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($QueryString))
    $signature = [System.BitConverter]::ToString($signature).Replace('-', '').ToLower()
    $uri = "https://fapi.binance.com/fapi/v1/account?$QueryString&signature=$signature"
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("X-MBX-APIKEY", $key)
    $accountInformation = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    return $accountInformation
}
# getaccount 3

function getProfit () {
    Param ($accountNum,$hours)
    # https://binance-docs.github.io/apidocs/futures/en/#get-income-history-user_data
    $key = ($accounts | Where-Object { $_.number -eq $accountNum }).key
    $secret = ($accounts | Where-Object { $_.number -eq $accountNum }).secret
    $start = (Get-Date).AddHours(-$hours)
    $startTime = ([DateTimeOffset]$start).ToUnixTimeMilliseconds()
    $limit = "1000"    # max 1000
    $results = @()
    while ($true) {
        $TimeStamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $QueryString = "&recvWindow=5000&limit=$limit&timestamp=$TimeStamp&startTime=$startTime"
        $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
        $hmacsha.key = [Text.Encoding]::ASCII.GetBytes($secret)
        $signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($QueryString))
        $signature = [System.BitConverter]::ToString($signature).Replace('-', '').ToLower()
        $uri = "https://fapi.binance.com/fapi/v1/income?$QueryString&signature=$signature"
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("X-MBX-APIKEY", $key)
        $result = @()
        $result = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        $results += $result
        if ($result.length -lt 1000) { break }
        $startTime = [int64]($result.time | sort)[-1] + 1
    }
    $results = $results | ? { $_.incomeType -ne "TRANSFER" }
    $sum = 0
    $results | % { $sum += $_.income }
    return $sum
}

# https://binance-docs.github.io/apidocs/spot/en/#new-future-account-transfer-user_data
function transferFunds () {
    Param ($accountNum,$transferAmount)
    $key = ($accounts | Where-Object { $_.number -eq $accountNum }).key
    $secret = ($accounts | Where-Object { $_.number -eq $accountNum }).secret
    $hours = ($accounts | Where-Object { $_.number -eq $accountNum }).hours
    $type = 2
    $asset = "USDT"
    $amount = $transferAmount
    $TimeStamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $QueryString = "&type=$($type)&asset=$($asset)&amount=$($amount)&recvWindow=5000&timestamp=$($TimeStamp)"
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.key = [Text.Encoding]::ASCII.GetBytes($secret)
    $signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($QueryString))
    $signature = [System.BitConverter]::ToString($signature).Replace('-', '').ToLower()
    $uriopenorders = "https://api.binance.com/sapi/v1/futures/transfer?$QueryString&signature=$signature"
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("X-MBX-APIKEY", $key)
    $tranId = (Invoke-RestMethod -Uri $uriopenorders -Headers $headers -Method Post).tranId
    write-log "Transfer Successful!"
    write-log "account[$($accountNum)]  totalBalance[$($totalWalletBalance)]  CurrentUsedMargin[$([math]::Round($marginUsedPercentCurr,1))%]  $($hours)hoursProfit[$([math]::Round(($profit), 2))]  transferred[$([math]::Round(($transferAmount),2))]  tranId[$($tranId)]"
    ### send discord message
    $message = "**TRANSFER**: SUCCESS  **account**: $($accountNum)  **totalBalance**: $($totalWalletBalance)  **$($hours)hoursProfit**: $([math]::Round(($profit), 2))  **transferred**: $([math]::Round(($transferAmount),2))  **tranId**: $($tranId)"
    sendDiscord $accountNum $message
}

function sendDiscord () {
    Param($accountNum,$message)
    $hookUrl = ($accounts | Where-Object { $_.number -eq $accountNum }).discord
    if ($hookUrl) {
        $content = $message
        $payload = [PSCustomObject]@{
            content = $content
        }
        Invoke-RestMethod -Uri $hookUrl -Method Post -Body ($payload | ConvertTo-Json) -ContentType 'Application/Json'
    }
}

while ($true) {
    foreach ($account in $accounts) {
        if ($account.enabled = "true") {
            ### Get current account info and profit
            $profit = getProfit $account.number $account.hours
            $accountInformation = getAccount $account.number
            $totalWalletBalance = [math]::Round(($accountInformation.totalWalletBalance), 2)
            try { $marginUsedPercentCurr = (([decimal] $accountInformation.totalInitialMargin + [decimal] $accountInformation.totalMaintMargin) / $accountInformation.totalWalletBalance) * 100 }
            catch { $marginUsedPercentCurr = 100 }
            $transferAmount = $account.profitPercent * $($profit) / 100

            ### check if used margin percentage is less than defined, and total remaining balance is more than defined. if conditions don't apply, retry once an hour
            while (($marginUsedPercentCurr -gt $account.maxMarginUsedPercent) -or ($account.minRemainingBalance -gt ($totalWalletBalance - $transferAmount)) -or $profit -lt 0) {
                write-log "account[$($account.number)] totalBalance[$($totalWalletBalance)] currentUsedMargin[$([math]::Round(($marginUsedPercentCurr), 1))%] $($account.hours)hoursProfit[$([math]::Round(($profit), 2))]"
                write-log "Conditions not fulfilled. Waiting 1 hr to retry..."
                $message = "**TRANSFER**: FAILURE  **account**: $($account.number)  **totalBalance**: $($totalWalletBalance)  **$($account.hours)hoursProfit**: $($profit)"
                sendDiscord $account.number $message
                betterSleep 3600 "AutoTransfer Reattempt (conditions not fulfilled)"
                ### Get current account info and profit
                $profit = getProfit $account.number $account.hours
                $accountInformation = getAccount
                $totalWalletBalance = [math]::Round(($accountInformation.totalWalletBalance), 2)
                try { $marginUsedPercentCurr = (([decimal] $accountInformation.totalInitialMargin + [decimal] $accountInformation.totalMaintMargin) / $accountInformation.totalWalletBalance) * 100 }
                catch { $marginUsedPercentCurr = 100 }
                $transferAmount = $account.profitPercent * $($profit) / 100
            }

            ### perform the transfer of ($percentsOfProfit * $profit) to Spot
            transferFunds $account.number $transferAmount

            ### sleep for $hours
            betterSleep ($account.hours * 3600) "AutoTransfer"
        }
    }
}
