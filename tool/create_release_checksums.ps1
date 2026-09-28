param(
  [Parameter(Mandatory = $false)]
  [string]$Path = "dist",

  [Parameter(Mandatory = $false)]
  [string]$Output = "SHA256SUMS.txt"
)

$ErrorActionPreference = "Stop"

# 发布校验清单只面向最终交付产物，避免把临时文件、符号文件或日志写进用户说明。
$artifactPattern = '\.(exe|msi|msix|appx|zip|7z|apk|aab|dmg|pkg|appimage|tar\.gz|tar\.xz)$'

# 解析发布目录为绝对路径，后续所有相对路径都以它为根。
$releaseRoot = Resolve-Path -LiteralPath $Path
# 输出路径允许传相对路径；相对路径固定落在发布目录内部。
$outputPath = $null
if ([System.IO.Path]::IsPathRooted($Output)) {
  $outputPath = $Output
} else {
  $outputPath = Join-Path $releaseRoot.Path $Output
}

# 按文件名过滤发布产物，排除旧校验清单本身，保持输出稳定可复现。
$artifacts = Get-ChildItem -LiteralPath $releaseRoot.Path -Recurse -File |
  Where-Object {
    $_.Name -ne (Split-Path -Leaf $outputPath) -and
    $_.Name.ToLowerInvariant() -match $artifactPattern
  } |
  Sort-Object FullName

if ($artifacts.Count -eq 0) {
  throw "No release artifacts found in '$($releaseRoot.Path)'."
}

# 使用常见 sha256sum 格式：hash、两个空格、星号和相对路径，方便用户跨平台校验。
$lines = foreach ($artifact in $artifacts) {
  $hash = Get-FileHash -LiteralPath $artifact.FullName -Algorithm SHA256
  $relativePath = [System.IO.Path]::GetRelativePath(
    $releaseRoot.Path,
    $artifact.FullName
  ).Replace('\', '/')
  "$($hash.Hash.ToLowerInvariant()) *$relativePath"
}

# UTF-8 无 BOM 适合 GitHub Release、PowerShell 和 Linux sha256sum 读取。
[System.IO.File]::WriteAllLines(
  $outputPath,
  $lines,
  [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Wrote $($artifacts.Count) checksum entries to $outputPath"
