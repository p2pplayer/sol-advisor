$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
. (Join-Path $PSScriptRoot 'prepare-reviewed-install.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $tempBase ('sol-advisor-fix1-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot
$script:Fault = ''; $script:Actions = @(); $script:Config = ''; $script:ArgsForTest = @{}
function Assert-Fixture($Condition, $Message) { if (-not $Condition) { throw $Message } }
function Fixture-Git {
    $global:LASTEXITCODE = 0
    if ($args -contains 'rev-parse') {
        if ($script:Fault -eq 'git-head') { $global:LASTEXITCODE = 7 }
        return ('1' * 40)
    }
    if ($script:Fault -eq 'git-status') { $global:LASTEXITCODE = 8 }
}
function Fixture-Codex {
    $global:LASTEXITCODE = 0
    if ($args -contains '--version') {
        if ($script:Fault -eq 'codex-version') { $global:LASTEXITCODE = 9 }
        return 'fixture-codex'
    }
    if ($args -contains 'list') {
        if ($script:Fault -eq 'codex-query') { $global:LASTEXITCODE = 10 }
        if ($script:Fault -eq 'codex-json') { return 'not JSON' }
        return (@{installed=@(@{pluginId='sol-advisor@sol-advisor';source=@{path=$fixtureRoot}})} | ConvertTo-Json -Depth 5 -Compress)
    }
    $script:Actions += ('codex ' + ($args -join ' '))
}
function Fixture-Python {
    $global:LASTEXITCODE = 0
    if ($script:Fault -eq 'roles-backup-exit') { $global:LASTEXITCODE = 11; return }
    if ($script:Fault -eq 'roles-backup-missing') { return }
    $target = $args[[Array]::IndexOf($args, '--target-dir') + 1]
    $backup = $args[[Array]::IndexOf($args, '--backup-dir') + 1]
    $source = Split-Path -Parent (Split-Path -Parent $args[0])
    $files = @{}
    foreach ($role in Get-ChildItem -LiteralPath (Join-Path $source 'agents') -Filter '*.toml') {
        $files[$role.Name] = @{before=$null;before_sha256=$null;candidate_sha256=(Get-FileHash -LiteralPath $role.FullName -Algorithm SHA256).Hash}
    }
    if ($script:Fault -eq 'roles-backup-tamper') { $files['sol-advisor-sol-reviewer.toml'].candidate_sha256 = 'bad' }
    $null = New-Item -ItemType Directory -Path $backup
    @{schema=1;target=$target;group='all';files=$files} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backup 'roles.json') -Encoding UTF8
}
function Copy-Item {
    [CmdletBinding()] param([string]$LiteralPath, [string]$Destination)
    if ($script:Fault -eq 'config-backup') { Write-Error 'fixture non-terminating backup error'; return }
    Microsoft.PowerShell.Management\Copy-Item -LiteralPath $LiteralPath -Destination $Destination -ErrorAction Stop
    if ($script:Fault -eq 'config-backup-hash') { Add-Content -LiteralPath $Destination -Value 'changed' }
}
function Get-Item {
    [CmdletBinding()] param([string]$LiteralPath)
    if ($script:Fault -eq 'config-access' -and $LiteralPath -eq $script:Config) {
        Write-Error 'fixture access denied (not legal missing config)'; return
    }
    Microsoft.PowerShell.Management\Get-Item -LiteralPath $LiteralPath -ErrorAction Stop
}
function Fixture-Install {
    $script:Actions += 'roles install'
    Set-Content -LiteralPath (Join-Path $script:ArgsForTest.AgentsPath 'deployment-marker') -Value 'stub only'
}
try {
    $cases = @('zip-sha-missing','zip-sha-wrong','manifest-missing','manifest-empty','payload-hash',
               'required-member','extra-source','git-head','git-status','codex-version','codex-query',
               'codex-json','config-backup','config-backup-hash','config-access','roles-backup-exit',
               'roles-backup-missing','roles-backup-tamper','success','config-absent')
    foreach ($case in $cases) {
        $script:Fault = $case; $script:Actions = @(); $global:LASTEXITCODE = 0
        $caseRoot = Join-Path $fixtureRoot $case; $review = Join-Path $caseRoot 'review'
        $source = Join-Path $review 'source'; $plugin = Join-Path $source 'plugins/sol-advisor'
        $null = New-Item -ItemType Directory -Path (Join-Path $plugin 'agents') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $plugin 'scripts') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $plugin '.codex-plugin') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $source '.agents/plugins') -Force
        foreach ($name in @('00_交付摘要.md','01_改动与原路由保持说明.md','02_验证结果.md',
                             '03_原任务接续验证.md','04_审核通过后安装与原任务启用.md','changes.patch','changes-fix1.patch')) {
            Set-Content -LiteralPath (Join-Path $review $name) -Value 'fixture' -Encoding UTF8
        }
        Set-Content -LiteralPath (Join-Path $source 'LICENSE') -Value 'fixture'
        Set-Content -LiteralPath (Join-Path $source '.agents/plugins/marketplace.json') -Value '{}'
        @{candidate_commit=('1'*40);plugin_candidate_version='0.7.0-rc.2'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $review 'receipt.json') -Encoding UTF8
        @{name='sol-advisor';version='0.7.0-rc.2'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $plugin '.codex-plugin/plugin.json') -Encoding UTF8
        foreach ($name in @('prepare-reviewed-install.ps1','backup-roles.py','install-agents.sh')) {
            Microsoft.PowerShell.Management\Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $plugin ('scripts/' + $name)) -ErrorAction Stop
        }
        Get-ChildItem -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'agents') -Filter '*.toml' | ForEach-Object {
            Microsoft.PowerShell.Management\Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $plugin ('agents/' + $_.Name)) -ErrorAction Stop
        }
        if ($case -eq 'required-member') { Remove-Item -LiteralPath (Join-Path $source 'LICENSE') -ErrorAction Stop }
        $lines = @(Get-ChildItem -LiteralPath $review -Recurse -File -Force | ForEach-Object {
            (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.FullName.Substring($review.Length+1).Replace('\','/')
        })
        Set-Content -LiteralPath (Join-Path $review 'manifest.sha256') -Value $lines -Encoding UTF8
        $fixtureZip = [IO.Compression.ZipFile]::Open(($review + '.zip'), [IO.Compression.ZipArchiveMode]::Create)
        try {
            Get-ChildItem -LiteralPath $review -Recurse -File -Force | ForEach-Object {
                $name = $_.FullName.Substring($review.Length + 1).Replace('\', '/')
                $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($fixtureZip, $_.FullName, $name)
            }
        } finally { $fixtureZip.Dispose() }
        $expected = (Get-FileHash -LiteralPath ($review + '.zip') -Algorithm SHA256).Hash
        if ($case -eq 'zip-sha-missing') { $expected = '' }
        if ($case -eq 'zip-sha-wrong') { $expected = '0'*64 }
        if ($case -eq 'manifest-missing') { Remove-Item -LiteralPath (Join-Path $review 'manifest.sha256') -ErrorAction Stop }
        if ($case -eq 'manifest-empty') { Set-Content -LiteralPath (Join-Path $review 'manifest.sha256') -Value '' -NoNewline }
        if ($case -eq 'payload-hash') { Add-Content -LiteralPath (Join-Path $source 'LICENSE') -Value 'bad' }
        if ($case -eq 'extra-source') { Set-Content -LiteralPath (Join-Path $source 'extra.txt') -Value 'unlisted' }
        $script:Config = Join-Path $caseRoot 'config.toml'
        if ($case -ne 'config-absent') { Set-Content -LiteralPath $script:Config -Value 'fixture config (no credentials)' }
        $agents = Join-Path $caseRoot 'shared-agents-fixture'; $null = New-Item -ItemType Directory -Path $agents
        $script:ArgsForTest = @{ReviewRoot=$review;ExpectedZipSha256=$expected;CandidateRoot=$source;
            ExpectedCommit=('1'*40);ExpectedVersion='0.7.0-rc.2';ConfigPath=$script:Config;
            AgentsPath=$agents;BackupRoot=(Join-Path $caseRoot 'backup');GitCommand='Fixture-Git';
            CodexCommand='Fixture-Codex';PythonCommand='Fixture-Python';Deploy={
                param($prepared)
                Fixture-Codex plugin remove sol-advisor@sol-advisor
                Fixture-Codex plugin marketplace remove sol-advisor
                Fixture-Codex plugin marketplace add $prepared.Source
                Fixture-Codex plugin add sol-advisor@sol-advisor
                Fixture-Install
            }}
        $failed = $false; $reason = ''
        try { Invoke-ReviewedInstall @script:ArgsForTest }
        catch { $failed = $true; $reason = $_.Exception.Message }
        $success = $case -in @('success','config-absent')
        Assert-Fixture ($failed -ne $success) ("Unexpected result: $case / $reason")
        if ($success) {
            Assert-Fixture ($script:Actions.Count -eq 5) "Success did not reach all stubs: $case"
            if ($case -eq 'config-absent') {
                Assert-Fixture (-not (Test-Path -LiteralPath $script:Config)) 'Missing config was wrongly created'
                Assert-Fixture ((Get-Content -LiteralPath (Join-Path $script:ArgsForTest.BackupRoot 'config-state.txt')).Trim() -eq 'ABSENT_BEFORE_INSTALL') 'Missing config state not recorded'
            }
        } else {
            Assert-Fixture ($script:Actions.Count -eq 0) "Deployment ran after failure: $case"
            Assert-Fixture (@(Get-ChildItem -LiteralPath $agents -Force).Count -eq 0) "Shared fixture written after failure: $case"
            $expectedReason = switch ($case) {
                'zip-sha-missing' { 'External expected ZIP' }
                'zip-sha-wrong' { 'ZIP SHA-256 differs' }
                'manifest-missing' { 'manifest.sha256' }
                'manifest-empty' { 'Manifest empty' }
                'payload-hash' { 'Payload hash mismatch' }
                'required-member' { 'Required member missing' }
                'extra-source' { 'Unlisted source payload' }
                'git-head' { 'Fixture-Git (7)' }
                'git-status' { 'Fixture-Git (8)' }
                'codex-version' { 'Fixture-Codex (9)' }
                'codex-query' { 'Fixture-Codex (10)' }
                'codex-json' { 'JSON' }
                'config-backup' { 'fixture non-terminating backup error' }
                'config-backup-hash' { 'Config backup verification failed' }
                'config-access' { 'fixture access denied' }
                'roles-backup-exit' { 'Fixture-Python (11)' }
                'roles-backup-missing' { 'roles.json' }
                'roles-backup-tamper' { 'Role candidate backup mismatch' }
            }
            Assert-Fixture ($reason.Contains($expectedReason)) "Fault path not reached: $case / $reason"
        }
        Write-Output ("PASS F2: $case; deployment_calls=$($script:Actions.Count); $reason")
    }
    Write-Output ("F2 WINDOWS PREFLIGHT PASSED: $($cases.Count) cases; PowerShell $($PSVersionTable.PSVersion)")
} finally {
    $resolved = [IO.Path]::GetFullPath($fixtureRoot)
    if (-not $resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $resolved) -notlike 'sol-advisor-fix1-*') { throw 'Unsafe fixture cleanup target' }
    Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
}
