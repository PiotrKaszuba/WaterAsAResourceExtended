param(
    [string]$ModZip,
    [string]$FactorioBin = $env:FACTORIO_BIN,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$IntegrationArgs
)
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $RepoRoot
try {
    if (-not $ModZip) {
        & "$PSScriptRoot/package-mod.ps1"
        $info = Get-Content info.json -Raw | ConvertFrom-Json
        $ModZip = Join-Path $RepoRoot "releases/$($info.name)_$($info.version).zip"
    }
    $runnerArgs = @("tests/integration/run.py", "--mod-zip", $ModZip)
    if ($FactorioBin) { $runnerArgs += @("--factorio-bin", $FactorioBin) }
    python @runnerArgs @IntegrationArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally { Pop-Location }
