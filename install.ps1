# Windows Installation Script for PDF Translation Tool
# This script installs all required dependencies for the PDF translation tool

Write-Host "=====================================" -ForegroundColor Green
Write-Host "PDF Translation Tool - Dependencies Installer" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Check if Python is installed
Write-Host "`nChecking Python installation..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "Python found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Python is not installed or not in PATH!" -ForegroundColor Red
    Write-Host "Please install Python from https://www.python.org/downloads/" -ForegroundColor Red
    Write-Host "Make sure to check 'Add Python to PATH' during installation" -ForegroundColor Red
    pause
    exit 1
}

# Check if pip is available
Write-Host "`nChecking pip installation..." -ForegroundColor Yellow
try {
    $pipVersion = pip --version 2>&1
    Write-Host "Pip found: $pipVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: pip is not available!" -ForegroundColor Red
    Write-Host "Please reinstall Python with pip included" -ForegroundColor Red
    pause
    exit 1
}

# Upgrade pip
Write-Host "`nUpgrading pip to latest version..." -ForegroundColor Yellow
python -m pip install --upgrade pip

# Install Python packages
Write-Host "`nInstalling Python dependencies..." -ForegroundColor Yellow

$packages = @(
    "pdfplumber",
    "python-docx", 
    "transformers",
    "torch",
    "torchvision",
    "torchaudio"
)

foreach ($package in $packages) {
    Write-Host "Installing $package..." -ForegroundColor Cyan
    pip install $package
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Failed to install $package" -ForegroundColor Red
    } else {
        Write-Host "✓ $package installed successfully" -ForegroundColor Green
    }
}

# Check if Ollama is installed
Write-Host "`nChecking Ollama installation..." -ForegroundColor Yellow
try {
    $ollamaVersion = ollama --version 2>&1
    Write-Host "Ollama found: $ollamaVersion" -ForegroundColor Green
} catch {
    Write-Host "Ollama not found. Installing Ollama..." -ForegroundColor Yellow
    
    # Download and install Ollama for Windows
    try {
        Write-Host "Downloading Ollama installer..." -ForegroundColor Cyan
        $ollamaUrl = "https://ollama.com/download/windows"
        $installerPath = "$env:TEMP\OllamaSetup.exe"
        
        # Download Ollama installer
        Invoke-WebRequest -Uri $ollamaUrl -OutFile $installerPath -UseBasicParsing
        
        Write-Host "Running Ollama installer..." -ForegroundColor Cyan
        Write-Host "Please follow the installation prompts in the installer window." -ForegroundColor Yellow
        Start-Process -FilePath $installerPath -Wait
        
        # Clean up installer
        Remove-Item $installerPath -ErrorAction SilentlyContinue
        
        Write-Host "✓ Ollama installation completed" -ForegroundColor Green
        Write-Host "Note: You may need to restart your terminal/PowerShell for Ollama to be available in PATH" -ForegroundColor Yellow
        
    } catch {
        Write-Host "Failed to automatically install Ollama" -ForegroundColor Red
        Write-Host "Please manually download and install Ollama from: https://ollama.com/download/windows" -ForegroundColor Yellow
    }
}

# Download required Ollama models
Write-Host "`nDownloading required Ollama models..." -ForegroundColor Yellow
Write-Host "This may take a while depending on your internet connection..." -ForegroundColor Cyan

$models = @(
    "gemma2:27b",
    "deepseek-r1:32b", 
    "llama3.1:latest"
)

foreach ($model in $models) {
    Write-Host "Downloading $model..." -ForegroundColor Cyan
    try {
        ollama pull $model
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ $model downloaded successfully" -ForegroundColor Green
        } else {
            Write-Host "WARNING: Failed to download $model" -ForegroundColor Red
        }
    } catch {
        Write-Host "WARNING: Could not download $model - Ollama may not be in PATH yet" -ForegroundColor Red
        Write-Host "You can download it later with: ollama pull $model" -ForegroundColor Yellow
    }
}

Write-Host "`n=====================================" -ForegroundColor Green
Write-Host "Installation Summary" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

Write-Host "`nPython packages installed:" -ForegroundColor Yellow
foreach ($package in $packages) {
    try {
        $version = pip show $package 2>$null | Select-String "Version:" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }
        if ($version) {
            Write-Host "✓ $package ($version)" -ForegroundColor Green
        } else {
            Write-Host "✗ $package (not found)" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ $package (check failed)" -ForegroundColor Red
    }
}

Write-Host "`nOllama models:" -ForegroundColor Yellow
foreach ($model in $models) {
    try {
        $modelList = ollama list 2>$null
        if ($modelList -match $model.Split(":")[0]) {
            Write-Host "✓ $model" -ForegroundColor Green
        } else {
            Write-Host "✗ $model (not downloaded)" -ForegroundColor Red
        }
    } catch {
        Write-Host "? $model (unable to check)" -ForegroundColor Yellow
    }
}

Write-Host "`n=====================================" -ForegroundColor Green
Write-Host "Installation completed!" -ForegroundColor Green
Write-Host "You can now run the translation script:" -ForegroundColor Yellow
Write-Host "python translate.py" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Green

pause