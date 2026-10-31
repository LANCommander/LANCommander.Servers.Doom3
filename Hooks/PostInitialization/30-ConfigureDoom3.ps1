#Requires -Modules Logging

# Write the D3_* settings into <D3_GAME>/lancommander.cfg, which d3-server execs before
# +spawnServer. The file is regenerated on every start; put your own settings in
# <D3_GAME>/server.cfg (in Overlay/), which lancommander.cfg execs first when it exists.

$dir = Join-Path $Env:SERVER_ROOT $Env:D3_GAME
$file = Join-Path $dir 'lancommander.cfg'

if (-not (Test-Path -Path (Join-Path $Env:SERVER_ROOT 'base/pak000.pk4'))) {
    Write-Log -Level Error "base/pak000.pk4 not found in $Env:SERVER_ROOT; copy the retail Doom 3 base/ (and d3xp/) folders into $Env:SERVER_DIR"
    return
}

function ConvertTo-Quoted([string] $Value) { '"' + $Value.Replace('"', '') + '"' }

function ConvertTo-Bool([string] $Value) {
    if (-not $Value) { return $null }
    if ($Value -in 'true', '1', 'yes') { '1' } else { '0' }
}

$values = [ordered]@{
    'si_name'                         = $(if ($Env:D3_SERVER_NAME) { ConvertTo-Quoted $Env:D3_SERVER_NAME })
    'si_map'                          = $(if ($Env:D3_MAP) { ConvertTo-Quoted $Env:D3_MAP })
    'si_gameType'                     = $(if ($Env:D3_GAME_TYPE) { ConvertTo-Quoted $Env:D3_GAME_TYPE })
    'si_maxPlayers'                   = $Env:D3_MAX_PLAYERS
    'si_fragLimit'                    = $Env:D3_FRAG_LIMIT
    'si_timeLimit'                    = $Env:D3_TIME_LIMIT
    'si_pure'                         = ConvertTo-Bool $Env:D3_PURE
    'si_warmup'                       = ConvertTo-Bool $Env:D3_WARMUP
    'si_teamDamage'                   = ConvertTo-Bool $Env:D3_TEAM_DAMAGE
    'si_spectators'                   = ConvertTo-Bool $Env:D3_SPECTATORS
    'si_usePass'                      = $(if ($Env:D3_PASSWORD) { '1' })
    'g_password'                      = $(if ($Env:D3_PASSWORD) { ConvertTo-Quoted $Env:D3_PASSWORD })
    'net_serverRemoteConsolePassword' = $(if ($Env:D3_RCON_PASSWORD) { ConvertTo-Quoted $Env:D3_RCON_PASSWORD })
}

$lines = @('// Generated from the D3_* environment variables on every start, edit server.cfg instead')
$lines += 'exec server.cfg'

foreach ($key in $values.Keys) {
    if ($null -ne $values[$key] -and $values[$key] -ne '') { $lines += "set $key $($values[$key])" }
}

New-Item -ItemType Directory -Path $dir -Force | Out-Null
[System.IO.File]::WriteAllText($file, ($lines -join "`n") + "`n")
# Not -R: a recursive chown through Merged/ would copy every pak up into Overlay/
chown "$($Env:UID):$($Env:GID)" $file

Write-Log "Wrote D3_* settings to $file"
