param(
    [ValidateSet('Simulation', 'Quartus')]
    [string] $Check = 'Simulation',
    [string] $QuartusBin = 'C:/intelFPGA_lite/20.1/quartus/bin64',
    [string] $BuildRoot = $env:PUBLIC
)

$ErrorActionPreference = 'Stop'
$build = Join-Path $BuildRoot ('onfi-fsm-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $build | Out-Null
$files = 'onfi_fsm_pkg.vhd', 'onfi_protocol_fsm.vhd', 'tb_onfi_protocol_fsm.vhd',
         'check_sim.do', 'check_quartus.tcl', 'check_core.sdc'
foreach ($file in $files) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $build
}
Write-Output "Reports: $build"
Push-Location -LiteralPath $build
try {
    if ($Check -eq 'Simulation') {
        vlib work
        if ($LASTEXITCODE -ne 0) { throw "vlib failed: $LASTEXITCODE" }
        vcom -2008 onfi_fsm_pkg.vhd onfi_protocol_fsm.vhd tb_onfi_protocol_fsm.vhd |
            Tee-Object -FilePath compile.log
        if ($LASTEXITCODE -ne 0) { throw "VHDL compilation failed: $LASTEXITCODE" }
        vsim -c -l regression.log work.tb_onfi_protocol_fsm -do check_sim.do
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $LASTEXITCODE" }
    } else {
        $quartus = Join-Path $QuartusBin 'quartus_sh.exe'
        & $quartus -t check_quartus.tcl
        if ($LASTEXITCODE -ne 0) { throw "Quartus project setup failed: $LASTEXITCODE" }
        foreach ($tool in 'quartus_map.exe', 'quartus_fit.exe', 'quartus_sta.exe') {
            & (Join-Path $QuartusBin $tool) onfi_fsm_check
            if ($LASTEXITCODE -ne 0) { throw "$tool failed: $LASTEXITCODE" }
        }
        $timing = Get-Content -Raw -LiteralPath 'onfi_fsm_check.sta.summary'
        if ($timing -notmatch "(?m)^Type\s*:\s*.*Setup 'core_clk'") {
            throw 'TimeQuest did not report the core clock setup paths'
        }
        if ($timing -match '(?m)^Slack\s*:\s*-\d') {
            throw "TimeQuest reported negative slack. See $build/onfi_fsm_check.sta.summary"
        }
    }
} finally {
    Pop-Location
}
