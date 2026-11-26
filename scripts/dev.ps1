[CmdletBinding()]
param(
    [ValidateSet('run', 'build', 'test', 'analyze', 'pubget', 'devices')]
    [string]$Action = 'run',
    [string]$DeviceId,
    [switch]$Release,
    [string]$ToolsRoot = 'E:\Vibe_AI\xiaohe_jizhang\.tools'
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
$flutterBin = Join-Path $ToolsRoot 'flutter\bin'
$sdkRoot = Join-Path $ToolsRoot 'sdk'
$pubCache = Join-Path $ToolsRoot 'pub-cache'
$gradleHome = Join-Path $ToolsRoot 'gradle-home'
$androidUserHome = Join-Path (Split-Path -Parent $ToolsRoot) '.android'

$javaHome = $env:JAVA_HOME
if (-not $javaHome -or -not (Test-Path -LiteralPath (Join-Path $javaHome 'bin\java.exe'))) {
    $javaHome = 'E:\AndroidStudio\jbr'
}
if (-not (Test-Path -LiteralPath (Join-Path $javaHome 'bin\java.exe'))) {
    throw "JDK not found. Set JAVA_HOME or install Android Studio JBR at E:\AndroidStudio\jbr."
}

# Map both ToolsRoot's parent (if needed) and projectRoot to ASCII drive letters
# to avoid Gradle/NDK issues with non-ASCII Chinese directory names.
$projDrive = 'Q:'
$toolsDrive = 'T:'

if (Test-Path "$projDrive\") { & subst.exe $projDrive /D | Out-Null }
if (Test-Path "$toolsDrive\") { & subst.exe $toolsDrive /D | Out-Null }

& subst.exe $projDrive $projectRoot
if ($LASTEXITCODE -ne 0) { throw "Failed to map $projDrive to $projectRoot" }

$toolsParent = Split-Path -Parent $ToolsRoot
& subst.exe $toolsDrive $toolsParent
if ($LASTEXITCODE -ne 0) {
    & subst.exe $projDrive /D | Out-Null
    throw "Failed to map $toolsDrive to $toolsParent"
}

try {
    $env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
    $env:JAVA_HOME = $javaHome
    $env:ANDROID_HOME = "$toolsDrive\.tools\sdk"
    $env:ANDROID_SDK_ROOT = "$toolsDrive\.tools\sdk"
    $env:PUB_CACHE = "$toolsDrive\.tools\pub-cache"
    $env:GRADLE_USER_HOME = "$toolsDrive\.tools\gradle-home"
    $env:ANDROID_USER_HOME = "$toolsDrive\.android"
    $env:ORG_GRADLE_PROJECT_android_overridePathCheck = 'true'
    $env:PATH = "$toolsDrive\.tools\flutter\bin;$toolsDrive\.tools\sdk\platform-tools;$(Join-Path $javaHome 'bin');$env:PATH"

    Push-Location "$projDrive\"
    try {
        switch ($Action) {
            'pubget' {
                flutter pub get
            }
            'analyze' {
                flutter analyze
            }
            'test' {
                flutter test
            }
            'devices' {
                flutter devices
            }
            'build' {
                if ($Release) {
                    flutter build apk --release
                } else {
                    flutter build apk --debug
                }
            }
            'run' {
                $argsList = @('run')
                if ($DeviceId) {
                    $argsList += @('-d', $DeviceId)
                }
                flutter @argsList
            }
        }
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    } finally {
        Pop-Location
    }
} finally {
    if (Test-Path "$projDrive\") { & subst.exe $projDrive /D | Out-Null }
    if (Test-Path "$toolsDrive\") { & subst.exe $toolsDrive /D | Out-Null }
}
