### author:  Daisy
### discord: Daisy#2718
### site:    https://github.com/daisy613/autoTransfer
### issues:  https://github.com/daisy613/autoTransfer/issues
### tldr:    This PowerShell script continuously transfers a percentage of profits automatically on a Binance Futures account, from Futures to Spot wallet, at a predefined interval.
### Changelog:
### * added script version to the progress bar
### * added proxy support (please delete your old json settings file and use the new one)
### * added transfer failure reasons

$version = "v1.0.5"
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
$path = Split-Path $MyInvocation.MyCommand.Path
$settings = gc "$($path)\autoTransfer.json" | ConvertFrom-Json
if (!($settings)) { write-host "Cannot find $($path)\autoTransfer.json file!" -foregroundcolor "DarkRed" -backgroundcolor "yellow"; sleep 30 ; exit }
write-host "`n`n`n`n`n`n`n`n`n`n"

function checkLatest () {
    $repo = "daisy613/autoTransfer"
    $releases = "https://api.github.com/repos/$repo/releases"
    $latestTag = [array](Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name
    $youngerVer = ($version, $latestTag | Sort-Object)[-1]
    if ($latestTag -and $version -ne $youngerVer) {
        write-host "Your version of $($repo) [$($version)] is outdated. Newer version [$($latestTag)] is available: https://github.com/$($repo)/releases/tag/$($latestTag)" -b "Red"
    }
}

Function write-log {
    Param ([string]$string,$color)
    $Logfile = "$($path)\autoTransfer.log"
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$date] $string" -ForegroundColor $color
    Add-Content $Logfile -Value "[$date] $string"
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

function getAccountFut () {
    $TimeStamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $QueryString = "recvWindow=5000&timestamp=$TimeStamp"
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.key = [Text.Encoding]::ASCII.GetBytes($settings.secret)
    $signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($QueryString))
    $signature = [System.BitConverter]::ToString($signature).Replace('-', '').ToLower()
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("X-MBX-APIKEY", $settings.key)
    $request = 'Invoke-RestMethod -Uri "https://fapi.binance.com/fapi/v1/account?$QueryString&signature=$signature" -Method Get -Headers $headers' + $proxyString
    $accountInformation = Invoke-Expression $request
    return $accountInformation
}

function getAccountSpt () {
    # /api/v3/account
    $TimeStamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $QueryString = "recvWindow=5000&timestamp=$TimeStamp"
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.key = [Text.Encoding]::ASCII.GetBytes($settings.secret)
    $signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($QueryString))
    $signature = [System.BitConverter]::ToString($signature).Replace('-', '').ToLower()
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("X-MBX-APIKEY", $settings.key)
    $request = 'Invoke-RestMethod -Uri "https://api.binance.com/api/v3/account?$QueryString&signature=$signature" -Method Get -Headers $headers' + $proxyString
    $accountInformation = Invoke-Expression $request
    return $accountInformation
}

function getProfit () {
    Param ($hours)
    # https://binance-docs.github.io/apidocs/futures/en/#get-income-history-user_data
    $start = (Get-Date).AddHours(-$hours)
    $startTime = ([DateTimeOffset]$start).ToUnixTimeMilliseconds()
    $limit = "1000"    # max 1000
    $results = @()
    $thing = [PSCustomObject]@{
        lastTransTime = $null
        profit       = $null
    }
    while ($true) {
        $TimeStamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $QueryString = "recvWindow=5000&limit=$limit&timestamp=$TimeStamp&startTime=$startTime"
        $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
        $hmacsha.key = [Text.Encoding]::ASCII.GetBytes($settings.secret)
        $signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($QueryString))
        $signature = [System.BitConverter]::ToString($signature).Replace('-', '').ToLower()
        $uri =
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("X-MBX-APIKEY", $settings.key)
        $result = @()
        $request = 'Invoke-RestMethod -Uri "https://fapi.binance.com/fapi/v1/income?$QueryString&signature=$signature" -Method Get -Headers $headers' + $proxyString
        $result = Invoke-Expression $request
        $results += $result
        if ($result.length -lt 1000) { break }
        $startTime = [int64]($result.time | sort)[-1] + 1
    }
    $sum = 0
    $results | ? { $_.incomeType -ne "TRANSFER" } | % { $sum += $_.income }
    $thing.lastTransTime = try { ($results | ? { $_.incomeType -eq "TRANSFER" } | sort time).time[-1] } catch { $null }
    $thing.profit = $sum
    return $thing
}

# https://binance-docs.github.io/apidocs/spot/en/#new-future-account-transfer-user_data
function transferFunds () {
    Param ($transferAmount)
    $type = 2
    $asset = "USDT"
    $amount = $transferAmount
    $TimeStamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $QueryString = "type=$($type)&asset=$($asset)&amount=$($amount)&recvWindow=5000&timestamp=$($TimeStamp)"
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.key = [Text.Encoding]::ASCII.GetBytes($settings.secret)
    $signature = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($QueryString))
    $signature = [System.BitConverter]::ToString($signature).Replace('-', '').ToLower()
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("X-MBX-APIKEY", $settings.key)
    $request = 'Invoke-RestMethod -Uri "https://api.binance.com/sapi/v1/futures/transfer?$QueryString&signature=$signature" -Method Post -Headers $headers' + $proxyString
    $tranId = (Invoke-Expression $request).tranId
    return $tranId
}

function sendDiscord () {
    Param($webHook,$message)
    $hookUrl = $webHook
    if ($hookUrl) {
        $content = $message
        $payload = [PSCustomObject]@{
            content = $content
        }
        Invoke-RestMethod -Uri $hookUrl -Method Post -Body ($payload | ConvertTo-Json) -ContentType 'Application/Json'
    }
}

while ($true) {
    checkLatest
    if ($settings.proxy -ne "http://PROXYIP:PROXYPORT" -and $settings.proxy -ne "") {
        $proxyString = " -proxy $($settings.proxy)"
        write-host "[$date] Using proxy $($settings.proxy)" -f "Cyan"
    } else { $proxyString = "" }
    ### Get current account info and profit
    $profitQuery = getProfit $settings.hours
    $profit = $profitQuery.profit
    $accountInformation = getAccountFut
    $totalWalletBalance = [math]::Round(($accountInformation.totalWalletBalance), 2)
    try { $marginUsedPercentMax = (([decimal] $accountInformation.totalInitialMargin + [decimal] $accountInformation.totalMaintMargin) / $accountInformation.totalWalletBalance) * 100 }
	catch { $marginUsedPercentMax = 100 }
	try { $marginUsedPercentCurr = (([decimal] $accountInformation.totalMaintMargin) / $accountInformation.totalWalletBalance) * 100 }
    catch { $marginUsedPercentCurr = 100 }
    $transferAmount = $settings.profitPercent * $($profit) / 100
    write-log -string "current settings: maxMarginUsedPercent[$($settings.maxMarginUsedPercent)] minRemainingBalance[$($settings.minRemainingBalance)] profitPercent[$($settings.profitPercent)] periodInHours[$($settings.hours)]" -color "Cyan"
    ### check if used margin percentage is less than defined, and total remaining balance is more than defined. if conditions don't apply, retry once an hour
    while (($marginUsedPercentMax -gt $settings.maxMarginUsedPercent) -or ($settings.minRemainingBalance -gt ($totalWalletBalance - $transferAmount)) -or $profit -le 0) {
        $failureReasons = @()
        if ($marginUsedPercentMax -gt $settings.maxMarginUsedPercent) {
            $reason = "MAX_MARGIN_EXCEEDED, threshold: $($settings.maxMarginUsedPercent)"
            $failureReasons += $reason
        }
        elseif ($settings.minRemainingBalance -gt ($totalWalletBalance - $transferAmount)) {
            $reason = "MIN_BALANCE_EXCEEDED, threshold: $($settings.minRemainingBalance)"
            $failureReasons += $reason
        }
        elseif ($profit -le 0) {
            $reason = "NO_PROFIT"
            $failureReasons += $reason
        }
        # if ($failureReasons.length -gt 1) { $failureReasons = $failureReasons -join ' ,' }
        $ofs = ', '
        $failureReasons = [string]$failureReasons
        write-log -string "account[$($settings.name)] totalBalance[$($totalWalletBalance)] maxUsedMargin[$([math]::Round(($marginUsedPercentMax), 2))%] currentUsedMargin[$([math]::Round(($marginUsedPercentCurr), 2))%] $($settings.hours)-hourProfit[$([math]::Round(($profit), 2))]" -color "Yellow"
        write-log -string "Conditions not fulfilled [$($failureReasons)]. Waiting 1 hr to retry..." -color "Yellow"
        $message = "**TRANSFER**: FAILURE  **account**: $($settings.name)  **maxUsedMargin**: $([math]::Round(($marginUsedPercentMax), 2))  **currentUsedMargin**: $([math]::Round(($marginUsedPercentCurr), 2))  **totalBalance**: $($totalWalletBalance)  **$($settings.hours)-hourProfit**: $([math]::Round(($profit), 2)) **failureReason**: $($failureReasons)"
        sendDiscord $settings.discord $message
        betterSleep 3600 "AutoTransfer $($version) (path: $($path)) - reattempting in 1hr (conditions not fulfilled)"
        ### Get current account info and profit
        $profitQuery = getProfit $settings.hours
        $profit = $profitQuery.profit
        $accountInformation = getAccountFut
        $totalWalletBalance = [math]::Round(($accountInformation.totalWalletBalance), 2)
        try { $marginUsedPercentMax = (([decimal] $accountInformation.totalInitialMargin + [decimal] $accountInformation.totalMaintMargin) / $accountInformation.totalWalletBalance) * 100 }
		catch { $marginUsedPercentMax = 100 }
		try { $marginUsedPercentCurr = (([decimal] $accountInformation.totalMaintMargin) / $accountInformation.totalWalletBalance) * 100 }
        catch { $marginUsedPercentCurr = 100 }
        $transferAmount = $settings.profitPercent * $($profit) / 100
    }
    ### perform the transfer of ($percentsOfProfit * $profit) to Spot
    if (!($profitQuery.lastTransTime)) {
        $tranId = transferFunds $transferAmount
    }
    else {
        $delay  = ($settings.hours * 3600000) - ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - $profitQuery.lastTransTime)
        $hrsAgo = [math]::Round((($settings.hours * 3600000) - $delay) / 3600000, 2)
        write-log "A transfer has been performed $($hrsAgo) hours ago. Scheduling the next transfer to run in $([math]::Round(($delay / 3600000), 2)) hours ..." -color "Magenta"
        betterSleep ($delay / 1000) "AutoTransfer $($version) (path: $($path))"
    }
    $spotBalance = [math]::Round(((getAccountSpt).balances | ? { $_.asset -eq "USDT" }).free, 2)
    write-log -string "Transfer Successful!" -color "Green"
    write-log -string "account[$($settings.name)] totalBalance[$($totalWalletBalance)] currUsedMargin[$([math]::Round($marginUsedPercentCurr,1))%] $($settings.hours)-hourProfit[$([math]::Round(($profit), 2))] transferred[$([math]::Round(($transferAmount),2))] spotBalance[$($spotBalance)]" -color "Green"
    ### send discord message
    $message = "**TRANSFER**: SUCCESS  **account**: $($settings.name)  **maxUsedMargin**: $([math]::Round(($marginUsedPercentMax), 2))  **currentUsedMargin**: $([math]::Round(($marginUsedPercentCurr), 2))  **totalBalance**: $($totalWalletBalance)  **$($settings.hours)-hourProfit**: $([math]::Round(($profit), 2))  **transferred**: $([math]::Round(($transferAmount),2)) ($($settings.profitPercent)%)  **spotBalance**: $($spotBalance)"
    sendDiscord $settings.discord $message
    ### sleep for X $hours
    betterSleep ($settings.hours * 3600) "AutoTransfer $($version) (path: $($path))"
}
