[CmdletBinding()]
param(
    [ValidateSet(
        "all",
        "windows-amd64",
        "linux-amd64",
        "linux-arm64",
        "openwrt-mipsel"
    )]
    [string[]]$Targets = @("all"),

    [string]$NimExe = "",

    # 留空时，默认使用与 nim.exe 同目录的 nimble.exe。
    [string]$NimbleExe = "",

    # Nimble 的包目录。pkgcache、pkgs2 和 nimbledata2.json 都放在这里。
    # 留空时使用 <project>\build\nimble。
    [string]$NimbleDir = "",

    # 清理 build 和 dist 后再构建。
    [switch]$Clean,

    # 跳过 nimble install --depsOnly。
    [switch]$SkipDeps,

    # 输出 Nimble/Nim 的详细构建信息。
    [switch]$VerboseBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = $PSScriptRoot
$BuildRoot   = Join-Path $ProjectRoot "build"
$NimCacheRoot = Join-Path $BuildRoot "nimcache"
$DistDir     = Join-Path $ProjectRoot "dist"

if ([string]::IsNullOrWhiteSpace($NimbleDir)) {
    $NimbleDir = Join-Path $BuildRoot "nimble"
}

function Assert-FileExists {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description not found: $Path"
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList,

        [Parameter(Mandatory)]
        [string]$Description
    )

    Write-Host ""
    Write-Host "==> $Description" -ForegroundColor Cyan

    if ($VerboseBuild) {
        $shownArgs = $ArgumentList | ForEach-Object {
            if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ }
        }
        Write-Host ("    {0} {1}" -f $FilePath, ($shownArgs -join " "))
    }

    & $FilePath @ArgumentList

    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

function Remove-BuildOutputCandidates {
    $candidates = @(
        (Join-Path $ProjectRoot "buaalogin.exe"),
        (Join-Path $ProjectRoot "buaalogin"),
        (Join-Path $ProjectRoot "src\buaalogin.exe"),
        (Join-Path $ProjectRoot "src\buaalogin")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            Remove-Item -LiteralPath $candidate -Force
        }
    }
}

function Find-BuildOutput {
    $candidates = @(
        (Join-Path $ProjectRoot "buaalogin.exe"),
        (Join-Path $ProjectRoot "buaalogin"),
        (Join-Path $ProjectRoot "src\buaalogin.exe"),
        (Join-Path $ProjectRoot "src\buaalogin")
    )

    $found = @(
        $candidates |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            ForEach-Object { Get-Item -LiteralPath $_ } |
            Sort-Object LastWriteTimeUtc -Descending
    )

    if ($found.Count -eq 0) {
        throw "Nimble reported success, but buaalogin/buaalogin.exe was not found."
    }

    return $found[0].FullName
}

function Resolve-NimExe {
    param(
        [string]$ConfiguredPath
    )

    if (-not [string]::IsNullOrWhiteSpace($ConfiguredPath)) {
        if (-not (Test-Path -LiteralPath $ConfiguredPath -PathType Leaf)) {
            throw "Specified Nim executable does not exist: $ConfiguredPath"
        }

        return (Resolve-Path -LiteralPath $ConfiguredPath).Path
    }

    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        try {
            $prefixOutput = @(& scoop prefix nim 2>$null)

            if ($LASTEXITCODE -eq 0 -and $prefixOutput.Count -gt 0) {
                $nimPrefix = $prefixOutput[-1].ToString().Trim()
                $candidate = Join-Path $nimPrefix "bin\nim.exe"

                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    return (Resolve-Path -LiteralPath $candidate).Path
                }
            }
        }
        catch {
            # 继续尝试其他定位方法
        }
    }

    $command = Get-Command nim.exe -ErrorAction SilentlyContinue

    if ($null -ne $command) {
        $candidate = $command.Source

        if ($candidate -match '[\\/](shims)[\\/]nim\.exe$') {
            $shimFile = [System.IO.Path]::ChangeExtension($candidate, ".shim")

            if (Test-Path -LiteralPath $shimFile -PathType Leaf) {
                $pathLine = Get-Content -LiteralPath $shimFile |
                    Where-Object { $_ -match '^\s*path\s*=' } |
                    Select-Object -First 1

                if ($pathLine -match '^\s*path\s*=\s*"([^"]+)"') {
                    $realPath = $Matches[1]

                    if (Test-Path -LiteralPath $realPath -PathType Leaf) {
                        return (Resolve-Path -LiteralPath $realPath).Path
                    }
                }
            }
        }
        elseif (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw @"
Unable to locate the real nim.exe.

For a Scoop installation, verify:
    scoop prefix nim

Or specify it explicitly:
    .\build.ps1 -NimExe "D:\Scoop\Scoop\apps\nim\current\bin\nim.exe"
"@
}

$NimExe = Resolve-NimExe -ConfiguredPath $NimExe
$NimBinDir = Split-Path -Parent $NimExe
$env:PATH = "$NimBinDir;$env:PATH"
$env:NIMBLE_DIR = $NimbleDir

if ([string]::IsNullOrWhiteSpace($NimbleExe)) {
    $candidate = Join-Path $NimBinDir "nimble.exe"

    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $NimbleExe = (Resolve-Path -LiteralPath $candidate).Path
    }
    else {
        $nimbleCommand = Get-Command nimble.exe -ErrorAction SilentlyContinue

        if ($null -eq $nimbleCommand) {
            throw "Unable to locate nimble.exe."
        }

        $NimbleExe = $nimbleCommand.Source
    }
}

Assert-FileExists -Path $NimExe -Description "Nim compiler"
Assert-FileExists -Path $NimbleExe -Description "Nimble"

if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot "buaalogin.nimble"))) {
    throw "buaalogin.nimble was not found in project root: $ProjectRoot"
}

if ($Clean) {
    Write-Host "Cleaning build and dist directories..." -ForegroundColor Yellow

    foreach ($path in @($BuildRoot, $DistDir)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
}

foreach ($path in @($BuildRoot, $NimCacheRoot, $NimbleDir, $DistDir)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}

# 每个目标使用独立 nimcache，避免不同 CPU/OS 生成的 C 文件和目标文件相互污染。
$TargetTable = [ordered]@{
    "windows-amd64" = @{
        Cpu        = "amd64"
        Os         = "windows"
        OutputName = "buaalogin-windows-amd64.exe"
        ExtraArgs  = @()
    }

    "linux-amd64" = @{
        Cpu        = "amd64"
        Os         = "linux"
        OutputName = "buaalogin-linux-amd64"
        ExtraArgs  = @()
    }

    "linux-arm64" = @{
        Cpu        = "arm64"
        Os         = "linux"
        OutputName = "buaalogin-linux-arm64"
        ExtraArgs  = @()
    }

    "openwrt-mipsel" = @{
        Cpu        = "mipsel"
        Os         = "linux"
        OutputName = "buaalogin-openwrt-mipsel"
        ExtraArgs  = @()
    }
}

if ($Targets -contains "all") {
    $SelectedTargets = @($TargetTable.Keys)
}
else {
    $SelectedTargets = @($Targets)
}

Write-Host "Project root   : $ProjectRoot"
Write-Host "Nim            : $NimExe"
Write-Host "Nimble         : $NimbleExe"
Write-Host "Nimble dir     : $NimbleDir"
Write-Host "Nimble pkgcache: $(Join-Path $NimbleDir 'pkgcache')"
Write-Host "Nim caches     : $NimCacheRoot"
Write-Host "Output         : $DistDir"
Write-Host "Targets        : $($SelectedTargets -join ', ')"

Push-Location $ProjectRoot

try {
    if (-not $SkipDeps) {
        $depsArgs = @(
            "--useSystemNim",
            "--nimbleDir:$NimbleDir",
            "install",
            "--depsOnly",
            "--accept"
        )

        if ($VerboseBuild) {
            $depsArgs += "--verbose"
        }

        Invoke-Checked `
            -FilePath $NimbleExe `
            -ArgumentList $depsArgs `
            -Description "Installing project dependencies"
    }

    $results = @()

    foreach ($targetName in $SelectedTargets) {
        $target = $TargetTable[$targetName]
        $nimCache = Join-Path $NimCacheRoot $targetName
        $destination = Join-Path $DistDir $target.OutputName

        New-Item -ItemType Directory -Path $nimCache -Force | Out-Null
        Remove-BuildOutputCandidates

        if (Test-Path -LiteralPath $destination -PathType Leaf) {
            Remove-Item -LiteralPath $destination -Force
        }

        $buildArgs = @(
            "--useSystemNim",
            "--nimbleDir:$NimbleDir",
            "build",
            "--cc:clang",
            "--cpu:$($target.Cpu)",
            "--os:$($target.Os)",
            "--nimcache:$nimCache",
            "--forceBuild:on"
        )

        $buildArgs += $target.ExtraArgs

        if ($VerboseBuild) {
            $buildArgs += "--verbose"
        }

        Invoke-Checked `
            -FilePath $NimbleExe `
            -ArgumentList $buildArgs `
            -Description "Building $targetName"

        $sourceOutput = Find-BuildOutput
        Move-Item -LiteralPath $sourceOutput -Destination $destination -Force

        $file = Get-Item -LiteralPath $destination
        $results += [pscustomobject]@{
            Target = $targetName
            File   = $file.Name
            Bytes  = $file.Length
            KiB    = [math]::Round($file.Length / 1KB, 1)
        }

        Write-Host ("    -> {0} ({1:N1} KiB)" -f $destination, ($file.Length / 1KB)) `
            -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Build completed." -ForegroundColor Green
    $results | Format-Table Target, File, KiB, Bytes -AutoSize
}
finally {
    Pop-Location
}
