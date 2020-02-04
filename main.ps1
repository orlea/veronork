param (
    $configuration = ".\config.ps1"
)

function Main {
    param (
        $configuration
    )
    # Start main script
    Write-Host "Start script"
    Write-Host "Import configuration..."
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
        rclone --config rclone.conf copy $source_path $distination_path --progress --ignore-existing
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

    # Generate target filename
    function Edit-SpecifiedFileName {
        param (
            $target_date,
            $time_format
        )
        $result = New-Object System.Collections.Generic.List[string]
        $target_month_1st = [DateTime]::ParseExact($target_date.Tostring($time_format).Substring(0, 6) + "01", $time_format, $null)
        $check_date = $target_month_1st
        while ($target_date.Month -eq $check_date.Month) {
            $result.Add($check_date.Tostring($time_format) + ".zip")
            $check_date = $check_date.AddDays(1)
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

  
    Write-Host "Initializing..."

    # Start from this day (1st of last month)
    $today = Get-Date
    $last_month = $today.AddMonths(-1)

    # result file list
    $failers = New-Object System.Collections.Generic.List[string]
    $successes = New-Object System.Collections.Generic.List[string]

    Write-Host ("Today is " + $today.ToString("yyyyMMdd"))
    Write-Host ("Target month is " + $last_month.Month)
 
    # Get target file list.
    # *data format*
    # For a timestamp, the format is "date; file name"
    # For a file name, only the file name is included.
    if ($findscheme -eq "timestamp") {
        $target_file_list = Find-SpecifiedMonthFiles $last_month $source_path_prefix $time_format
    }elseif ($findscheme -eq "filename") {
        $target_file_list = Edit-SpecifiedFileName $last_month $time_format
    }

    # Upload
    for ($i = 0; $i -lt $target_file_list.Count; $i++) {
        Write-Host ("Uploading " + $target_file_list[$i])

        if ($findscheme -eq "timestamp") {
            $target_time_stamp = [DateTime]::ParseExact($target_file_list[$i].Split(";")[0], $time_format, $null)
            $target_file_name = $target_file_list[$i].Split(";")[1]
            $distination_directory = $target_time_stamp.ToString($distination_format)
        }elseif ($findscheme -eq "filename") {
            $target_file_name = $target_file_list[$i]
            $distination_directory = $last_month.ToString($distination_format)
        }
    
        $result = Send-Source2Distination $target_file_name $source_path_prefix $distination_path_prefix  $distination_directory
        if ($result -ne 0) {
            $failers.Add($target_file_list[$i])
            Write-Host ("Upload failed " + $target_file_list[$i])
        }else {
            $successes.Add($target_file_list[$i])
            Write-Host ("Upload success " + $target_file_list[$i])
        }
    }
    
    # Notification
    if ($failers.Count -ne 0) {
        $title = "Failed these " + $failers.Count.ToString() + "files"
        $text = "Please check log file"
        Write-Host $title
        Write-Host $failers
    }else {
        $title = "All files uploaded successfully"
        $text = "Please check distination"
        Write-Host $title
    }
    Write-Host "Successed these " + $successes.Count.ToString() + "files"
    Write-Host $successes

    if($webhook_uri){
        Write-Host "Send webhook notification"
        Send-Message2Webhook $webhook_uri $title $text
    }

    Write-Host "Script finished"
}

Start-Transcript ((Get-Date).Tostring("yyyyMMdd")+".log") -Append
Main $configuration
Stop-Transcript