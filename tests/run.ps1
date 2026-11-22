param([string]$Haxe = "haxe")
$ErrorActionPreference = "Stop"
$testRoot = $PSScriptRoot
$testWork = Join-Path ([IO.Path]::GetTempPath()) ("drh-auto-tests-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testWork | Out-Null
Copy-Item -Path (Join-Path $testRoot 'support\*') -Destination $testWork -Recurse
$package = Join-Path $testWork 'mods\auto_dungeon_loot_manager'
foreach ($name in @('RestartCountdown','RewardFlow','SummaryRules','LevelUpDismissal','PartyTimeGuard')) {
 Copy-Item -LiteralPath (Join-Path $testRoot "..\src\$name.hx") -Destination $package
}
foreach ($name in @('CountdownTest','RewardFlowTest','FiredRevealTaskTest','LevelUpDismissalTest','PartyIntegrationTest')) {
 & $Haxe -cp $testWork -cp $testRoot --main $name --interp
 if ($LASTEXITCODE -ne 0) { throw "$name failed" }
}
