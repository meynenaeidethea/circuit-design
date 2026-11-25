param(
    [ValidateSet('Simulation', 'Quartus')]
    [string] $Check = 'Simulation',
    [string] $ChatArchive = (Join-Path $env:USERPROFILE 'Downloads/Telegram Desktop/ChatExport_2026-11-25.zip'),
    [string] $QuartusBin = 'C:/intelFPGA_lite/20.1/quartus/bin64',
    [string] $BuildRoot = $env:PUBLIC
)

$ErrorActionPreference = 'Stop'
$build = Join-Path $BuildRoot ('onfi-integration-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $build | Out-Null
$core = Join-Path $PSScriptRoot '../fsm-control'
$sources = 'onfi_stream_fifo.vhd', 'onfi_packet_bridge.vhd', 'onfi_integration_top.vhd'
$tests = 'tb_onfi_async_phy.vhd', 'tb_onfi_integration.vhd', 'check_integration.do'
$quartusFiles = 'check_integration.sdc', 'check_integration.tcl'
foreach ($file in ($sources + $tests + $quartusFiles)) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $build
}
foreach ($file in 'onfi_fsm_pkg.vhd', 'onfi_protocol_fsm.vhd') {
    Copy-Item -LiteralPath (Join-Path $core $file) -Destination $build
}

Write-Output "Reports: $build"
Push-Location -LiteralPath $build
try {
    if ($Check -eq 'Simulation') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $outer = [System.IO.Compression.ZipFile]::OpenRead($ChatArchive)
        try {
            $entry = $outer.Entries | Where-Object Name -eq 'MX30LF1G18AC-TI,Verilog,1.2a.zip'
            if (@($entry).Count -ne 1) { throw 'Expected one Macronix model archive' }
            $stream = $entry.Open()
            try {
                $inner = [System.IO.Compression.ZipArchive]::new($stream)
                try {
                    $model = $inner.GetEntry('MX30LF1G18AC.v')
                    if ($null -eq $model) { throw 'Macronix Verilog source is missing' }
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile(
                        $model, (Join-Path $build 'MX30LF1G18AC.v')
                    )
                } finally {
                    $inner.Dispose()
                }
            } finally {
                $stream.Dispose()
            }
        } finally {
            $outer.Dispose()
        }
        vlib work
        if ($LASTEXITCODE -ne 0) { throw "vlib failed: $LASTEXITCODE" }
        vlog MX30LF1G18AC.v | Tee-Object -FilePath vlog.log
        if ($LASTEXITCODE -ne 0) { throw "Verilog compilation failed: $LASTEXITCODE" }
        vcom -2008 onfi_fsm_pkg.vhd onfi_protocol_fsm.vhd @sources tb_onfi_async_phy.vhd tb_onfi_integration.vhd |
            Tee-Object -FilePath compile.log
        if ($LASTEXITCODE -ne 0) { throw "VHDL compilation failed: $LASTEXITCODE" }
        vsim -c -t ps -L altera_mf -l integration.log work.tb_onfi_integration -do check_integration.do
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $LASTEXITCODE" }
    } else {
        & (Join-Path $QuartusBin 'quartus_sh.exe') -t check_integration.tcl *> setup.log
        $setupStatus = $LASTEXITCODE
        if ($setupStatus -ne 0) { Get-Content setup.log -Tail 25; throw "Setup failed: $setupStatus" }
        foreach ($stage in 'map', 'fit', 'sta') {
            $log = "$stage.log"
            & (Join-Path $QuartusBin "quartus_$stage.exe") onfi_integration_check *> $log
            $status = $LASTEXITCODE
            if ($status -ne 0) { Get-Content $log -Tail 25; throw "Quartus $stage failed: $status" }
            Get-Content $log | Select-String 'was successful|^Critical Warning|Worst-case.*slack'
        }
        $timing = Get-Content -Raw -LiteralPath 'onfi_integration_check.sta.summary'
        foreach ($clock in 'avalon_clk', 'logic_clk') {
            if ($timing -notmatch "(?m)^Type\s*:\s*.*Setup '$clock'") {
                throw "TimeQuest did not report setup paths for $clock"
            }
        }
        if ($timing -match '(?m)^Slack\s*:\s*-\d') {
            throw "TimeQuest reported negative slack. See $build/onfi_integration_check.sta.summary"
        }
    }
} finally {
    Pop-Location
}
