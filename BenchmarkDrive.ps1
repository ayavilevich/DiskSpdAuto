param (
    [Parameter(Mandatory = $true)][string]$drive,
    [string]$batchId=(Get-Date -format "yyyy-MM-dd_hh-mm-ss"), # 'u' and 's' will have colons, which is bad for filenames
    [string]$testSize='1G',
    [int]$durationSec=5, # less than 5sec gave zero results
    [int]$warmupSec=0,
    [int]$cooldownSec=0,
    [int]$restSec=1,
    [string]$diskspd='C:\prog\Diskspd-v2.0.15\x86fre\diskspd.exe'

)

# get test summary object
# assume one target and one timespan
function sum-test {
    param ( $test, $xmlFilePath, $driveObj )
    $x = [xml](Get-Content $xmlFilePath)
    $o = New-Object psobject
    # test meta data
    Add-Member -InputObject $o -MemberType noteproperty -Name 'ComputerName' -Value $x.Results.System.ComputerName
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Drive' -Value $driveObj.name
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Drive VolumeLabel' -Value $driveObj.VolumeLabel
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Batch' -Value $batchId
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Test Time' -Value (Get-Date)
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Test Name' -Value $test.name
    # io meta data
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Test File Size' -Value $testSize
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Duration [s]' -Value $durationSec
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Warmup [s]' -Value $warmupSec
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Cooldown [s]' -Value $cooldownSec
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Test Params' -Value $test.params
    # io metrics
    Add-Member -InputObject $o -MemberType noteproperty -Name 'TestTimeSeconds' -Value $x.Results.TimeSpan.TestTimeSeconds
    Add-Member -InputObject $o -MemberType noteproperty -Name 'WriteRatio' -Value ($x.Results.Profile.TimeSpans.TimeSpan.Targets.Target.WriteRatio | select -first 1)
    Add-Member -InputObject $o -MemberType noteproperty -Name 'ThreadCount' -Value $x.Results.TimeSpan.ThreadCount
    Add-Member -InputObject $o -MemberType noteproperty -Name 'RequestCount' -Value ($x.Results.Profile.TimeSpans.TimeSpan.Targets.Target.RequestCount | select -first 1)
    Add-Member -InputObject $o -MemberType noteproperty -Name 'BlockSize' -Value ($x.Results.Profile.TimeSpans.TimeSpan.Targets.Target.BlockSize | select -first 1)

    # sum read and write iops across all threads and targets
    $ri = ($x.Results.TimeSpan.Thread.Target |
            measure -sum -Property ReadCount).Sum
    $wi = ($x.Results.TimeSpan.Thread.Target |
            measure -sum -Property WriteCount).Sum
    $rb = ($x.Results.TimeSpan.Thread.Target |
            measure -sum -Property ReadBytes).Sum
    $wb = ($x.Results.TimeSpan.Thread.Target |
            measure -sum -Property WriteBytes).Sum
    Add-Member -InputObject $o -MemberType noteproperty -Name 'ReadCount' -Value $ri
    Add-Member -InputObject $o -MemberType noteproperty -Name 'WriteCount' -Value $wi
    Add-Member -InputObject $o -MemberType noteproperty -Name 'ReadBytes' -Value $rb
    Add-Member -InputObject $o -MemberType noteproperty -Name 'WriteBytes' -Value $wb

    # latency
    $l = @(); foreach ($i in 25,50,75,90,95,99,99.9,100) { $l += ,[string]$i }
    $h = @{}; $x.Results.TimeSpan.Latency.Bucket |% { $h[$_.Percentile] = $_ } # AY, hash all percentiles in $h
    $l |% {
        $b = $h[$_];
        Add-Member -InputObject $o -MemberType noteproperty -Name ('{0}% r' -f $_) -Value $b.ReadMilliseconds
        Add-Member -InputObject $o -MemberType noteproperty -Name ('{0}% w' -f $_) -Value $b.WriteMilliseconds
    }

    return $o
}

function sum-tests {
    param ( $tests )

    $o = New-Object psobject

    # drive meta data
    Add-Member -InputObject $o -MemberType noteproperty -Name 'ComputerName' -Value $tests[0].ComputerName
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Drive' -Value $tests[0].Drive
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Drive VolumeLabel' -Value $tests[0].'Drive VolumeLabel'
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Batch' -Value $tests[0].Batch
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Test Time' -Value $tests[0].'Test Time'

    Add-Member -InputObject $o -MemberType noteproperty -Name 'Test File Size' -Value $tests[0].'Test File Size'
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Test Duration [s]' -Value $tests[0].'Duration [s]'

    # io
    $t_sr=$tests |? {$_.'Test Name' -eq 'Sequential read'}
    $v=$t_sr.ReadBytes/$t_sr.TestTimeSeconds/1024/1024
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Sequential Read 1MB [MB/s]' -Value $v

    $t_sw=$tests |? {$_.'Test Name' -eq 'Sequential write'}
    $v=$t_sw.WriteBytes/$t_sw.TestTimeSeconds/1024/1024
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Sequential Write 1MB [MB/s]' -Value $v

    $t_rr=$tests |? {$_.'Test Name' -eq 'Random read'}
    $v=$t_rr.ReadBytes/$t_rr.TestTimeSeconds/1024/1024
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Random Read 4KB (QD=1) [MB/s]' -Value $v

    $t_rw=$tests |? {$_.'Test Name' -eq 'Random write'}
    $v=$t_rw.WriteBytes/$t_rw.TestTimeSeconds/1024/1024
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Random Write 4KB (QD=1) [MB/s]' -Value $v

    $t_r2r=$tests |? {$_.'Test Name' -eq 'Random QD32 read'}
    $v=$t_r2r.ReadBytes/$t_r2r.TestTimeSeconds/1024/1024
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Random Read 4KB (QD=32) [MB/s]' -Value $v

    $t_r2w=$tests |? {$_.'Test Name' -eq 'Random QD32 write'}
    $v=$t_r2w.WriteBytes/$t_r2w.TestTimeSeconds/1024/1024
    Add-Member -InputObject $o -MemberType noteproperty -Name 'Random Write 4KB (QD=32) [MB/s]' -Value $v

    return $o
}

# initialize test file
# best to do one per drive and not each test. also, had effect on "test duration" when was part of the test.
$testFileParams='{0}benchmark.tmp' -f $drive
$xmlFile=('{0}-Generation.xml' -f $batchId);
$params=( ('-Rxml -d1 -c{0}' -f $testSize) ,$testFileParams) -join ' ';
Write-Host $params
Write-Host $xmlFile
& $diskspd ($params -split ' ') > $xmlFile

# fixed params
$fixedParams='-L -S -Rxml'

# batch auto params
#$batchAutoParam='-d{0} -W{1} -C{2} -c{3}' -f $durationSec, $warmupSec, $cooldownSec, $testSize
$batchAutoParam='-d{0} -W{1} -C{2}' -f $durationSec, $warmupSec, $cooldownSec

# iterate over tests
$tests=@()
foreach ($test in @{name='Sequential read'; params='-b1M -o1 -t1 -w0 -Z1M'},
    @{name='Sequential write'; params='-b1M -o1 -t1 -w100 -Z1M'},
    @{name='Random read'; params='-b4K -o1 -t1 -r -w0 -Z1M'},
    @{name='Random write'; params='-b4K -o1 -t1 -r -w100 -Z1M'},
    @{name='Random QD32 read'; params='-b4K -o32 -t1 -r -w0 -Z1M'},
    @{name='Random QD32 write'; params='-b4K -o32 -t1 -r -w100 -Z1M'},
    @{name='Random T32 read'; params='-b4k -o1 -t32 -r -w0 -Z1M'},
    @{name='Random T32 write'; params='-b4k -o1 -t32 -r -w100 -Z1M'}) {
        # run test
        $params=($fixedParams,$batchAutoParam,$test.params,$testFileParams) -join ' ';
        $xmlFile=('{0}-{1}.xml' -f $batchId, $test.name);
        Write-Host $params
        Write-Host $xmlFile
        Start-Sleep $restSec # sleep a sec to calm down IO
        & $diskspd ($params -split ' ') > $xmlFile

        # read result and write to batch file
        $driveObj=[System.IO.DriveInfo]::GetDrives() | ? {$_.Name -eq $drive }
        $testResult=sum-test $test $xmlFile $driveObj 
        $testResult | Export-Csv ('{0}.csv' -f $batchId) -NoTypeInformation -Append
        $tests+=$testResult
}

# sum drive tests to a single row
$testsSum = sum-tests $tests
$testsSum 

$date=(Get-Date -format "yyyy-MM-dd")
$testsSum | Export-Csv ('{0}.csv' -f $date) -NoTypeInformation -Append