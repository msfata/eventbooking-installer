$AppName    = "EventBooking"
$JarName    = "EventBooking.jar"
$InstallDir = "$env:LOCALAPPDATA\$AppName"
$JarUrl     = "https://github.com/msfata/eventbooking-installer/raw/main/EventBooking.jar"
$JarSource  = "$env:TEMP\$JarName"

# 1. Check Java 21
$javaOk = $false
try {
    $v = & java -version 2>&1
    if ($v -match "21\.") { $javaOk = $true }
} catch {}

if (-not $javaOk) {
    Write-Host "Java 21 not found. Installing via winget..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        winget install Microsoft.OpenJDK.21 --silent --accept-package-agreements --accept-source-agreements
    } else {
        Write-Host "winget not available, downloading JRE directly..."
        $jreUrl = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.3%2B9/OpenJDK21U-jre_x64_windows_hotspot_21.0.3_9.msi"
        $jreMsi = "$env:TEMP\jre21.msi"
        Invoke-WebRequest $jreUrl -OutFile $jreMsi
        Start-Process msiexec -ArgumentList "/i `"$jreMsi`" /quiet" -Wait
    }
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
}

# 2. Download JAR
Write-Host "Downloading $AppName..."
Invoke-WebRequest $JarUrl -OutFile $JarSource

# 3. Install app
if (-not (Test-Path $JarSource)) {
    Write-Host "ERROR: Download failed"
    Start-Sleep 3
    exit 1
}

Write-Host "Installing $AppName..."
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }
Copy-Item $JarSource -Destination "$InstallDir\$JarName" -Force

# 4. Find Java 21 executable explicitly
$javaExe = "javaw"
$searchPaths = @(
    "C:\Program Files\Eclipse Adoptium",
    "C:\Program Files\Microsoft",
    "C:\Program Files\Java",
    "C:\Program Files\OpenJDK"
)
foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        $found = Get-ChildItem $path -Recurse -Filter "javaw.exe" -ErrorAction SilentlyContinue |
                 Where-Object { $_.FullName -match "21" } |
                 Select-Object -First 1
        if ($found) { $javaExe = $found.FullName; break }
    }
}

# 5. Create launcher bat
$launcher = "$InstallDir\launch.bat"
@"
@echo off
cd /d "%~dp0"
"$javaExe" -jar $JarName
"@ | Set-Content $launcher

# 6. Desktop shortcut
$shell     = New-Object -ComObject WScript.Shell
$shortcut  = $shell.CreateShortcut("$env:USERPROFILE\Desktop\$AppName.lnk")
$shortcut.TargetPath       = $launcher
$shortcut.WorkingDirectory = $InstallDir
$shortcut.WindowStyle      = 7
$shortcut.Save()

Write-Host "Done. Shortcut created on Desktop."
Start-Sleep 2
