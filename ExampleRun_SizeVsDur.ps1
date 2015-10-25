# .\RunBenchmarks.ps1 -drives ('e:\')
param (
    [array]$drives

)

# run several benchmarks
.\BenchmarkDrives.ps1 -drives $drives -testSize 1G -durationSec 20
.\BenchmarkDrives.ps1 -drives $drives -testSize 1G -durationSec 10
.\BenchmarkDrives.ps1 -drives $drives -testSize 1G -durationSec 5
.\BenchmarkDrives.ps1 -drives $drives -testSize 2G -durationSec 20
.\BenchmarkDrives.ps1 -drives $drives -testSize 2G -durationSec 10
.\BenchmarkDrives.ps1 -drives $drives -testSize 2G -durationSec 5
.\BenchmarkDrives.ps1 -drives $drives -testSize 4G -durationSec 20
.\BenchmarkDrives.ps1 -drives $drives -testSize 4G -durationSec 10
.\BenchmarkDrives.ps1 -drives $drives -testSize 4G -durationSec 5
.\BenchmarkDrives.ps1 -drives $drives -testSize 10G -durationSec 20
.\BenchmarkDrives.ps1 -drives $drives -testSize 10G -durationSec 10
.\BenchmarkDrives.ps1 -drives $drives -testSize 10G -durationSec 5
.\BenchmarkDrives.ps1 -drives $drives -testSize 20G -durationSec 20
.\BenchmarkDrives.ps1 -drives $drives -testSize 20G -durationSec 10
.\BenchmarkDrives.ps1 -drives $drives -testSize 20G -durationSec 5