$ErrorActionPreference = 'Stop'

# 仓库根目录由脚本所在的 tool 目录反向解析，避免依赖调用者当前路径。
$repositoryRoot = Split-Path -Parent $PSScriptRoot
# 清单是原生二进制唯一允许的路径、来源和哈希基线。
$manifestPath = Join-Path $repositoryRoot 'native_bins\manifest.json'
# 原生工具目录只允许出现清单登记文件和清单自身。
$nativeBinsRoot = Join-Path $repositoryRoot 'native_bins'
# 读取 JSON 清单并保留每项的路径与 SHA-256 供逐文件校验。
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
# 收集已登记相对路径，用于阻止未审计二进制混入发布包。
$registeredPaths = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($entry in $manifest.files) {
    # 清单路径统一使用正斜杠，转换后再限制必须落在 native_bins 内。
    $relativePath = [string]$entry.path
    $null = $registeredPaths.Add($relativePath)
    # 目标绝对路径来源于受版本控制的清单，不接受命令行外部路径。
    $targetPath = Join-Path $nativeBinsRoot ($relativePath -replace '/', '\')
    # 缺少目标文件意味着平台包不完整，应立即停止发布检查。
    if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
        throw "缺少原生二进制：$relativePath"
    }
    # 使用系统 SHA-256 实现计算当前文件摘要，与清单固定值做常量比较。
    $actualHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedHash = ([string]$entry.sha256).ToLowerInvariant()
    # 任何字节变化都必须先经过来源审计并显式更新清单。
    if ($actualHash -ne $expectedHash) {
        throw "原生二进制哈希不匹配：$relativePath，期望 $expectedHash，实际 $actualHash"
    }
}

# 枚举实际工具文件，避免只校验已知文件而遗漏额外注入的可执行文件。
$unexpectedFiles = Get-ChildItem -LiteralPath $nativeBinsRoot -Recurse -File |
    Where-Object { $_.FullName -ne $manifestPath } |
    ForEach-Object {
        # 实际文件路径转换为清单格式后再检查是否已登记。
        [IO.Path]::GetRelativePath($nativeBinsRoot, $_.FullName).Replace('\', '/')
    } |
    Where-Object { -not $registeredPaths.Contains($_) }

# 未登记文件没有来源、许可证和哈希，禁止进入构建。
if ($unexpectedFiles) {
    throw "发现未登记原生二进制：$($unexpectedFiles -join ', ')"
}

Write-Host "原生二进制供应链校验通过：$($manifest.files.Count) 个文件。"
