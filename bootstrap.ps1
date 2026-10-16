param([Parameter(Mandatory=$true)][ValidateSet('CheckoutTools','CheckoutCandidate','CheckoutSource','CheckoutEvidence','Install','Preflight','Identity','Import','Package','DownloadRuntime','Runtime','Accept','SealLogs')][string]$Mode,
 [string]$EvidenceSha='',[string]$PlanPath='')
# Public generic bootstrap. Raw private output never reaches Actions logs.
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$privateExit=0
$secretLog="D:\CodexState\private-entry-logs\$env:GITHUB_RUN_ID-$env:GITHUB_RUN_ATTEMPT"
try {
 if($env:GITHUB_REPOSITORY -cne 'g2314687990-ship-it/crm-release-entry' -or $env:GITHUB_REF -cne 'refs/tags/release-entry-ab358-v3' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or $env:RUNNER_OS -cne 'Windows') { throw 'HOST' }
 New-Item -ItemType Directory -Path $secretLog -Force | Out-Null
 $controller=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
 & "$env:SystemRoot\System32\icacls.exe" $secretLog '/inheritance:r' '/grant:r' "*$($controller):(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' *> $null
 if($LASTEXITCODE -ne 0) { throw 'LOG_ACL' }
 $log=Join-Path $secretLog ($Mode+'.log')
 & {
   $entry=Join-Path $env:GITHUB_WORKSPACE 'entry'
   $lock=Get-Content -LiteralPath (Join-Path $entry 'release-lock.json') -Raw | ConvertFrom-Json
   if($lock.version -ne 1 -or $lock.toolSha -cnotmatch '^[a-f0-9]{40}$' -or $lock.candidateSha -cne 'ab358f9533c5f991eea6d7572c9356d13eee3f61' -or $lock.sourceBaselineSha -cne $lock.candidateSha) { throw 'LOCK' }
   if($Mode.StartsWith('Checkout')) {
     if(-not $env:CRM_READ_TOKEN) { throw 'READ_TOKEN' }
     switch($Mode) {
       'CheckoutTools' { $name='tools';$sha=$lock.toolSha }
       'CheckoutCandidate' { $name='candidate';$sha=$lock.candidateSha }
       'CheckoutSource' { $name='source';$sha=$lock.candidateSha }
       'CheckoutEvidence' { $name='evidence';$sha=$EvidenceSha }
     }
     if($sha -cnotmatch '^[a-f0-9]{40}$') { throw 'COMMIT' }
     $dest=Join-Path $env:GITHUB_WORKSPACE $name
     if(Test-Path -LiteralPath $dest) { throw 'NEW_CHECKOUT_REQUIRED' }
     # Header exists only in this high controller process environment, never
     # command text, persistent config, candidate execution or public output.
     $env:GIT_CONFIG_COUNT='2';$env:GIT_CONFIG_KEY_0='http.https://github.com/.extraheader'
     $env:GIT_CONFIG_VALUE_0='AUTHORIZATION: basic '+[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('x-access-token:'+$env:CRM_READ_TOKEN))
     $env:GIT_CONFIG_KEY_1='core.autocrlf';$env:GIT_CONFIG_VALUE_1='false'
     $env:GIT_TERMINAL_PROMPT='0'
     try {
       & git clone --quiet --no-checkout 'https://github.com/g2314687990-ship-it/crm-system.git' $dest
       if($LASTEXITCODE -ne 0) { throw 'FETCH' }
       & git -C $dest config core.autocrlf false
       & git -C $dest checkout --quiet --detach $sha
       if($LASTEXITCODE -ne 0 -or (& git -C $dest rev-parse HEAD).Trim() -cne $sha) { throw 'EXACT_CHECKOUT' }
     } finally { foreach($n in @('GIT_CONFIG_COUNT','GIT_CONFIG_KEY_0','GIT_CONFIG_VALUE_0','GIT_CONFIG_KEY_1','GIT_CONFIG_VALUE_1','GIT_TERMINAL_PROMPT')) { Remove-Item -LiteralPath ('Env:'+$n) -ErrorAction SilentlyContinue } }
   } else {
     $hostExe=[Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
     & $hostExe -NoLogo -NoProfile -NonInteractive -File (Join-Path $env:GITHUB_WORKSPACE 'tools/scripts/public-release-step.ps1') -Mode $Mode -EvidenceSha $EvidenceSha -PlanPath $PlanPath
     $script:privateExit=$LASTEXITCODE
     if($LASTEXITCODE -ne 0) { throw 'STEP' }
   }
 } *> $log
 if(-not $?) { throw 'PRIVATE_STEP_FAILED' }
 Write-Output 'REVIEWED_ENTRY_STEP=PASS'
} catch {
 # Do not format ErrorRecord/exception: it may contain private source or data.
 if($Mode -ceq 'SealLogs') {
   switch($privateExit) { 41 { Write-Output 'DIAGNOSTIC_FAILURE_STAGE=ARCHIVE' } 42 { Write-Output 'DIAGNOSTIC_FAILURE_STAGE=ENCRYPT' } 43 { Write-Output 'DIAGNOSTIC_FAILURE_STAGE=BUDGET' } }
 }
 Write-Output 'REVIEWED_ENTRY_STEP=FAIL'
 exit 1
}
