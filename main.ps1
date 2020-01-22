function main {
    # Import config
    . ".\config.ps1"

    # Exec rclone
    function Send-Source2Distination {
        param (
            $target_filename,
            $distination_directory,
            $source_path_prefix,
            $distination_path_prefix
        )
        $source_path = $source_path_prefix + $target_filename
        $distination_path = $distination_path_prefix + $distination_directory
        rclone --config rclone.conf copy $source_path $distination_path
        $result = $LASTEXITCODE
        Write-Output $result
        return
    }

    # Webhook notification
    function Send-Message2Webhook {
        param (
            $webhook_uri,
            $title,
            $text
        )
        $body = ConvertTo-Json @{
            title = $title
            text = $text
        }
        Invoke-RestMethod -Uri $webhook_uri -Method Post -Body $body -ContentType 'application/json'
    }

    # Start main script
    Write-Host "Start script"
    Write-Host "Initializing..."

    # Start from this day (1st of last month)
    $today = Get-Date
    $lastmonth = $today.AddMonths(-1)
    $target_month_string = $lastmonth.ToString("yyyyMMdd").Substring(0, 6)
    $target_date_string = $target_month_string + "01"
    $target_date = [DateTime]::ParseExact($target_date_string, "yyyyMMdd", $null)
    $distination_directory = $lastmonth.ToString("yyyy") + "/" + $lastmonth.ToString("MM") + "/"

    # Continue downloading to less than this day (end of last month)
    $this_month_1st_string = $today.ToString("yyyyMMdd").Substring(0, 6) + "01"
    $this_month_1st = [DateTime]::ParseExact($this_month_1st_string, "yyyyMMdd", $null)

    # Failed file list
    $failers = New-Object System.Collections.Generic.List[string]

    Write-Host ("Today is " + $today.ToString("yyyyMMdd"))
    Write-Host ("Target month is " + $target_month_string)
 
    # Upload
    while ($target_date -lt $this_month_1st) {
        $target_filename = $target_date.ToString("yyyyMMdd") + ".zip"
        Write-Host ("Uploading " + $target_filename)
        $result = Send-Source2Distination $target_filename $distination_directory $source_path_prefix $distination_path_prefix
        if ($result -ne 0) {
            $failers.Add($target_filename)
            Write-Host ("Upload failed " + $target_filename)
        }else {
            Write-Host ("Upload success " + $target_filename)
        }
        $target_date = $target_date.AddDays(1)
    }

    # Notification
    if ($failers.Count -ne 0) {
        $title = $failers.Count.ToString() + " files failed."
        $text = $failers[0]
        for ($i = 1; $i -lt $failers.Count; $i++) {
            $text = $text + ", " + $failers[$i]
        }
        if($webhook_uri){
            Send-Message2Webhook $webhook_uri $title $text
        }
        Write-Host "Uploading of these files failed"
        Write-Host $text
    }else {
        Write-Host "All files uploaded successfully"
    }
}

Start-Transcript ((Get-Date).Tostring("yyyyMMdd")+".log") -Append
main
Stop-Transcript