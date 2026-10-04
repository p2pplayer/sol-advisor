# A bounded gate for the review package's installation instructions, not an installer.
# Dot-source from the reviewed source; no action occurs until the function is called.
function Invoke-ReviewedInstall {
    [CmdletBinding()]
    param(
        [string]$ReviewRoot, [string]$ExpectedZipSha256,
        [string]$CandidateRoot, [string]$ExpectedCommit, [string]$ExpectedVersion,
        [string]$ConfigPath, [string]$AgentsPath, [string]$BackupRoot,
        [string]$GitCommand = 'git', [string]$CodexCommand = 'codex',
        [string]$PythonCommand = 'python3', [scriptblock]$Deploy
    )
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version 3.0
    foreach ($value in @($ReviewRoot, $CandidateRoot, $ExpectedCommit, $ExpectedVersion,
                         $ConfigPath, $AgentsPath, $BackupRoot)) {
        if ([string]::IsNullOrWhiteSpace($value)) { throw 'Required installation input missing' }
    }
    if ($ExpectedZipSha256 -notmatch '^[0-9a-fA-F]{64}$') { throw 'External expected ZIP SHA-256 required' }
    if ($null -eq $Deploy) { throw 'Deployment continuation required' }
    $ReviewRoot = [IO.Path]::GetFullPath($ReviewRoot)
    $source = Join-Path $ReviewRoot 'source'
    $zipPath = $ReviewRoot + '.zip'
    if ((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256 -ErrorAction Stop).Hash -ne $ExpectedZipSha256) {
        throw 'ZIP SHA-256 differs from external review receipt/input'
    }
    $manifestPath = Join-Path $ReviewRoot 'manifest.sha256'
    $manifestLines = @(Get-Content -LiteralPath $manifestPath -Encoding UTF8 -ErrorAction Stop)
    if ($manifestLines.Count -eq 0) { throw 'Manifest empty' }
    $files = @{}
    foreach ($line in $manifestLines) {
        if ($line -notmatch '^([0-9a-f]{64})  (.+)$') { throw 'Invalid manifest entry' }
        $name = $Matches[2]; $hash = $Matches[1]
        if ($name.Contains('\') -or $name.StartsWith('/') -or $name.Contains(':') -or
            @($name.Split('/') | Where-Object { $_ -eq '..' -or $_ -eq '.' -or $_ -eq '' }).Count) {
            throw 'Unsafe manifest path'
        }
        if ($files.ContainsKey($name)) { throw 'Duplicate manifest member' }
        $item = [IO.Path]::GetFullPath((Join-Path $ReviewRoot $name))
        if (-not $item.StartsWith($ReviewRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Manifest path escapes review directory'
        }
        if ((Get-FileHash -LiteralPath $item -Algorithm SHA256 -ErrorAction Stop).Hash -ne $hash) {
            throw ('Payload hash mismatch: ' + $name)
        }
        $files[$name] = $hash
    }
    $required = @('00_交付摘要.md', '01_改动与原路由保持说明.md', '02_验证结果.md',
                  '03_原任务接续验证.md', '04_审核通过后安装与原任务启用.md',
                  'receipt.json', 'changes.patch', 'changes-fix1.patch',
                  'source/.agents/plugins/marketplace.json', 'source/LICENSE',
                  'source/plugins/sol-advisor/.codex-plugin/plugin.json',
                  'source/plugins/sol-advisor/scripts/prepare-reviewed-install.ps1',
                  'source/plugins/sol-advisor/scripts/backup-roles.py',
                  'source/plugins/sol-advisor/scripts/install-agents.sh')
    $roles = @('sol-advisor-luna-implementer.toml', 'sol-advisor-terra-implementer.toml',
               'sol-advisor-sol-reviewer.toml', 'sol-advisor-current-routine-implementer.toml',
               'sol-advisor-current-complex-implementer.toml', 'sol-advisor-current-reviewer.toml')
    $required += @($roles | ForEach-Object { 'source/plugins/sol-advisor/agents/' + $_ })
    foreach ($name in $required) { if (-not $files.ContainsKey($name)) { throw ('Required member missing: ' + $name) } }
    # Bind the extracted manifest/payload to the externally authenticated ZIP too.
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    $archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $entries = @($archive.Entries | Where-Object { $_.Name -ne '' })
        if ($entries.Count -ne $files.Count + 1) { throw 'ZIP/manifest coverage mismatch' }
        $seen = @{}
        foreach ($entry in $entries) {
            if ($seen.ContainsKey($entry.FullName)) { throw 'Duplicate ZIP member' }
            $seen[$entry.FullName] = $true
            $expected = if ($entry.FullName -eq 'manifest.sha256') {
                (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256 -ErrorAction Stop).Hash
            } elseif ($files.ContainsKey($entry.FullName)) { $files[$entry.FullName] } else { throw 'Unlisted ZIP member' }
            $stream = $entry.Open(); $algorithm = [Security.Cryptography.SHA256]::Create()
            try { $actual = [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '') }
            finally { $stream.Dispose(); $algorithm.Dispose() }
            if ($actual -ne $expected) { throw 'ZIP/extracted payload mismatch' }
        }
    } finally { $archive.Dispose() }
    $sourceItems = @(Get-ChildItem -LiteralPath $source -Recurse -Force -ErrorAction Stop)
    if (@($sourceItems | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'Linked source refused' }
    $sourceFiles = @($sourceItems | Where-Object { -not $_.PSIsContainer })
    $listedSource = @($files.Keys | Where-Object { $_.StartsWith('source/') })
    if ($sourceFiles.Count -ne $listedSource.Count) { throw 'Unlisted source payload' }
    foreach ($file in $sourceFiles) {
        $relative = $file.FullName.Substring($ReviewRoot.Length + 1).Replace('\', '/')
        if (-not $files.ContainsKey($relative)) { throw 'Unlisted source file' }
    }
    $receipt = Get-Content -LiteralPath (Join-Path $ReviewRoot 'receipt.json') -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $plugin = Get-Content -LiteralPath (Join-Path $source 'plugins/sol-advisor/.codex-plugin/plugin.json') -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($receipt.candidate_commit -ne $ExpectedCommit -or $receipt.plugin_candidate_version -ne $ExpectedVersion -or
        $plugin.name -ne 'sol-advisor' -or $plugin.version -ne $ExpectedVersion) { throw 'Candidate receipt/version mismatch' }
    function Invoke-CheckedNative([string]$Command, [string[]]$Arguments) {
        $result = & $Command @Arguments
        if ($LASTEXITCODE -ne 0) { throw ('Native command failed: ' + $Command + ' (' + $LASTEXITCODE + ')') }
        return $result
    }
    $head = @(Invoke-CheckedNative $GitCommand @('-C', $CandidateRoot, 'rev-parse', 'HEAD'))
    if ($head.Count -ne 1 -or $head[0] -ne $ExpectedCommit) { throw 'Candidate HEAD mismatch' }
    $dirty = @(Invoke-CheckedNative $GitCommand @('-C', $CandidateRoot, 'status', '--porcelain', '--untracked-files=no'))
    if ($dirty.Count) { throw 'Candidate tracked worktree dirty' }
    $null = Invoke-CheckedNative $CodexCommand @('--version')
    $query = @(Invoke-CheckedNative $CodexCommand @('plugin', 'list', '--json')) -join "`n"
    $installed = @((ConvertFrom-Json -InputObject $query -ErrorAction Stop).installed | Where-Object { $_.pluginId -eq 'sol-advisor@sol-advisor' })
    if ($installed.Count -ne 1 -or [string]::IsNullOrWhiteSpace($installed[0].source.path)) { throw 'Installed source missing or ambiguous' }
    $null = Get-Item -LiteralPath $installed[0].source.path -ErrorAction Stop
    # Every backup must be completed and verified before invoking any deployment.
    if (Test-Path -LiteralPath $BackupRoot -ErrorAction Stop) { throw 'Backup destination already exists' }
    $null = New-Item -ItemType Directory -Path $BackupRoot -ErrorAction Stop
    $config = $null
    try { $config = Get-Item -LiteralPath $ConfigPath -ErrorAction Stop }
    catch [System.Management.Automation.ItemNotFoundException] { $config = $null }
    if ($null -ne $config) {
        if ($config.PSIsContainer) { throw 'Configuration is not a regular file' }
        $before = (Get-FileHash -LiteralPath $ConfigPath -Algorithm SHA256 -ErrorAction Stop).Hash
        $backupConfig = Join-Path $BackupRoot 'config.before.toml'
        Copy-Item -LiteralPath $ConfigPath -Destination $backupConfig -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $backupConfig -Algorithm SHA256 -ErrorAction Stop).Hash -ne $before -or
            (Get-FileHash -LiteralPath $ConfigPath -Algorithm SHA256 -ErrorAction Stop).Hash -ne $before) { throw 'Config backup verification failed' }
        $configState = 'PRESENT_BACKED_UP'
    } else { $configState = 'ABSENT_BEFORE_INSTALL' }
    $configState | Set-Content -LiteralPath (Join-Path $BackupRoot 'config-state.txt') -Encoding UTF8 -ErrorAction Stop
    $query | Set-Content -LiteralPath (Join-Path $BackupRoot 'plugins.before.json') -Encoding UTF8 -ErrorAction Stop
    $roleBackup = Join-Path $BackupRoot 'roles'
    $null = Invoke-CheckedNative $PythonCommand @((Join-Path $source 'plugins/sol-advisor/scripts/backup-roles.py'),
        'snapshot', '--target-dir', $AgentsPath, '--backup-dir', $roleBackup, '--group', 'all')
    $roleReceipt = Get-Content -LiteralPath (Join-Path $roleBackup 'roles.json') -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($roleReceipt.schema -ne 1 -or $roleReceipt.target -ne [IO.Path]::GetFullPath($AgentsPath) -or
        @($roleReceipt.files.PSObject.Properties).Count -ne $roles.Count) { throw 'Role backup receipt invalid' }
    foreach ($name in $roles) {
        $entry = $roleReceipt.files.$name
        if ($entry.candidate_sha256 -ne $files['source/plugins/sol-advisor/agents/' + $name]) { throw 'Role candidate backup mismatch' }
        if ($null -eq $entry.before) {
            if ($null -ne $entry.before_sha256 -or (Test-Path -LiteralPath (Join-Path $AgentsPath $name) -ErrorAction Stop)) { throw 'Role absence backup mismatch' }
        } else {
            $bytes = [Convert]::FromBase64String($entry.before)
            $algorithm = [Security.Cryptography.SHA256]::Create()
            try { $hash = [BitConverter]::ToString($algorithm.ComputeHash($bytes)).Replace('-', '') }
            finally { $algorithm.Dispose() }
            if ($hash -ne $entry.before_sha256 -or
                (Get-FileHash -LiteralPath (Join-Path $AgentsPath $name) -Algorithm SHA256 -ErrorAction Stop).Hash -ne $hash) { throw 'Role backup integrity mismatch' }
        }
    }
    # The callback runs in this Stop scope. Queries/backups failing above cannot reach it.
    & $Deploy ([pscustomobject]@{ Source = $source; Backup = $BackupRoot; ConfigState = $configState; InstalledSource = $installed[0].source.path })
}
