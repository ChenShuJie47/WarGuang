$ErrorActionPreference = "SilentlyContinue"
$historyPath = "$env:APPDATA\Code\User\History"
$targetDir = "D:\Tools\GameTools\GODOT\GodotGames\warma-shadow-test"
$entries = Get-ChildItem -Path $historyPath -Filter "entries.json" -Recurse -ErrorAction SilentlyContinue

Write-Host "Found entries.json total: $($entries.Count)"
$results = @()

foreach ($entryFile in $entries) {
    try {
        $raw = Get-Content -Path $entryFile.FullName -Raw -Encoding UTF8
        $json = $raw | ConvertFrom-Json
        $res = [System.Uri]::UnescapeDataString($json.resource)
        
        if ($res -match "warma-shadow-test") {
            $relativePath = $res -replace "(?i).*warma-shadow-test/", ""
            $relativePath = $relativePath -replace "/", "\"
            
            # Find the latest entry
            $latestEntry = $json.entries | Sort-Object timestamp -Descending | Select-Object -First 1
            $sourceFile = Join-Path $entryFile.DirectoryName $latestEntry.id
            
            if (Test-Path $sourceFile) {
                $results += [PSCustomObject]@{
                    RelativePath = $relativePath
                    SourcePath = $sourceFile
                    Time = $latestEntry.timestamp
                    Timestamp = $latestEntry.timestamp
                }
            } else {
                Write-Host "Source file missing: $sourceFile"
            }
        }
    } catch {
        Write-Host "Error parsing $entryFile : $_"
    }
}

$results = $results | Sort-Object Timestamp -Descending
Write-Host "=== Found VS Code History Files (Top 50) ==="
$results | Select-Object RelativePath, Time | Sort-Object Timestamp -Descending | Select-Object -First 50 | Format-Table -AutoSize

# Precise overwrite
Write-Host "`n=== Starting Overwrite Recovery ==="
$count = 0
foreach ($item in $results) {
    if (-not ($item.RelativePath)) { continue }
    $targetPath = Join-Path $targetDir $item.RelativePath
    $targetParent = Split-Path $targetPath -Parent
    if (-not (Test-Path $targetParent)) {
        New-Item -ItemType Directory -Force -Path $targetParent | Out-Null
    }
    Copy-Item -Path $item.SourcePath -Destination $targetPath -Force
    Write-Host "Restored: $($item.RelativePath)"
    $count++
}
Write-Host "Total files recovered: $count"
