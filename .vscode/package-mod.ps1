$ErrorActionPreference = 'Stop'

$source = Split-Path -Parent $PSScriptRoot
$metadata = Get-Content -LiteralPath (Join-Path $source 'info.json') -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($metadata.name) -or [string]::IsNullOrWhiteSpace($metadata.version)) {
    throw 'info.json must contain a mod name and version.'
}

$modsDirectory = Join-Path $env:APPDATA 'Factorio\mods'
New-Item -ItemType Directory -Path $modsDirectory -Force | Out-Null
$modDirectoryName = "{0}_{1}" -f $metadata.name, $metadata.version
$destination = Join-Path $modsDirectory "$modDirectoryName.zip"
$temporaryArchive = Join-Path ([System.IO.Path]::GetTempPath()) ("{0}.zip" -f [guid]::NewGuid())

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

try {
    $archive = [System.IO.Compression.ZipFile]::Open(
        $temporaryArchive,
        [System.IO.Compression.ZipArchiveMode]::Create
    )
    try {
        Get-ChildItem -LiteralPath $source -Recurse -File -Force | ForEach-Object {
            $relativePath = $_.FullName.Substring($source.Length).TrimStart('\', '/').Replace('\', '/')
            if (($relativePath -split '/')[0] -notin @('.git', '.vscode')) {
                $entryPath = "$modDirectoryName/$relativePath"
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $archive,
                    $_.FullName,
                    $entryPath
                ) | Out-Null
            }
        }
    }
    finally {
        $archive.Dispose()
    }

    Move-Item -LiteralPath $temporaryArchive -Destination $destination -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryArchive) {
        Remove-Item -LiteralPath $temporaryArchive -Force
    }
}

Write-Output "Installed $($metadata.name)_$($metadata.version).zip in $modsDirectory"