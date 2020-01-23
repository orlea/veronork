param (
    $configuration = ".\config.ps1"
)

function Main {
    param (
        $configuration
    )
    # Import config
    . $configuration

    # Exec rclone
    function Send-Source2Distination {
        param (
            $target_filename,
            $source_path_prefix,
            $distination_path_prefix,
            $distination_directory
        )
        $source_path = $source_path_prefix + $target_filename
        $distination_path = $distination_path_prefix + $distination_directory
        rclone --config rclone.conf copy $source_path $distination_path
        $result = $LASTEXITCODE
        Write-Output $result
        return
    }

    # Find files at specified month in source folder
    function Find-SpecifiedMonthFiles {
        param (
            $target_date,
            $source_path_prefix,
            $time_format
        )
        $result = New-Object System.Collections.Generic.List[string]
        $source_file_list = rclone --config rclone.conf lsf --format "tp" $source_path_prefix
        for ($i = 0; $i -lt $source_file_list.Count; $i++) {
            $file_time_stamp_string = $source_file_list[$i].Split(";")[0]
            $file_time_stamp = [DateTime]::ParseExact($file_time_stamp_string, $time_format, $null)
            if ($file_time_stamp.month -eq $target_date.month) {
                $result.Add($source_file_list[$i])
            }
        }
        Write-Output $result
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
    $last_month = $today.AddMonths(-1)
  

    # Failed file list
    $failers = New-Object System.Collections.Generic.List[string]

    Write-Host ("Today is " + $today.ToString("yyyyMMdd"))
    Write-Host ("Target month is " + $last_month.Month)
 
    # Get target file list
    $target_file_list = Find-SpecifiedMonthFiles $last_month $source_path_prefix $time_format

    # Upload
    for ($i = 0; $i -lt $target_file_list.Count; $i++) {
        Write-Host ("Uploading " + $target_file_list[$i])
        $target_time_stamp = [DateTime]::ParseExact($target_file_list[$i].Split(";")[0], $time_format, $null)
        $target_file_name = $target_file_list[$i].Split(";")[1]
        $distination_directory = $target_time_stamp.ToString($distination_format)
        $result = Send-Source2Distination $target_file_name $source_path_prefix $distination_path_prefix  $distination_directory
        if ($result -ne 0) {
            $failers.Add($target_file_list[$i])
            Write-Host ("Upload failed " + $target_file_list[$i])
        }else {
            Write-Host ("Upload success " + $target_file_list[$i])
        }
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
        Send-Message2Webhook $webhook_uri "Successed" "All files uploaded"
    }
}

Start-Transcript ((Get-Date).Tostring("yyyyMMdd")+".log") -Append
Main $configuration
Stop-Transcript