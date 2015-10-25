# use example: .\BenchmarkDrives.ps1 ('c:\','d:\')
param (
    [array]$drives=([System.IO.DriveInfo]::GetDrives() | ? {$_.DriveType -eq "Fixed" -and $_.IsReady -eq $true } | Select -ExpandProperty Name),
    [string]$testSize='1G',
    [int]$durationSec=5 # less than 5sec gave zero results

)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$drives | % {
    & "$scriptDir\BenchmarkDrive.ps1" -drive $_ -testSize $testSize -durationSec $durationSec
}