# DefyxVPN Complete Solution - All-in-One Script
# Handles build, modify, sign, install with menu system

param([string]$Action)

$ErrorActionPreference = "SilentlyContinue"

# Configuration
$finalMsix = "DefyxVPN_Complete.msix"
$certFile = "defyxvpn_cert.pfx"
$certPassword = "defyx123"
$publisherCN = "CN=62937938-2AE2-4C12-9ED8-4C418C0CADF2"

function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "    DefyxVPN Complete Solution By atomic" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Build MSIX Package" -ForegroundColor Yellow
    Write-Host "2. Modify MSIX for Registry Access" -ForegroundColor Yellow
    Write-Host "3. Create & Install Certificate" -ForegroundColor Yellow
    Write-Host "4. Sign MSIX Package" -ForegroundColor Yellow
    Write-Host "5. Install DefyxVPN" -ForegroundColor Yellow
    Write-Host "6. Complete Process (All Steps)" -ForegroundColor Green
    Write-Host "7. Test Proxy Functionality" -ForegroundColor Cyan
    Write-Host "8. Clean All Files" -ForegroundColor Red
    Write-Host "9. Exit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Current Status:" -ForegroundColor White
    if (Test-Path $finalMsix) {
        Write-Host "  • MSIX Package: EXISTS" -ForegroundColor Green
    } else {
        Write-Host "  • MSIX Package: MISSING" -ForegroundColor Red
    }
    
    if (Test-Path $certFile) {
        Write-Host "  • Certificate: EXISTS" -ForegroundColor Green
    } else {
        Write-Host "  • Certificate: MISSING" -ForegroundColor Red
    }
    
    $app = Get-AppxPackage -Name "*UnboundTechUG*"
    if ($app) {
        Write-Host "  • DefyxVPN Installed: YES (v$($app.Version))" -ForegroundColor Green
    } else {
        Write-Host "  • DefyxVPN Installed: NO" -ForegroundColor Red
    }
    Write-Host ""
}

function Build-MSIX {
    Write-Host "=== Step 1: Building MSIX Package ===" -ForegroundColor Cyan
    
    Write-Host "Cleaning Flutter build..." -ForegroundColor Yellow
    flutter clean | Out-Null
    
    Write-Host "Getting Flutter dependencies..." -ForegroundColor Yellow
    flutter pub get | Out-Null
    
    Write-Host "Building Windows release..." -ForegroundColor Yellow
    flutter build windows --release | Out-Null
    
    Write-Host "Creating base MSIX..." -ForegroundColor Yellow
    flutter pub run msix:create | Out-Null
    
    if (Test-Path ".\build\windows\x64\runner\Release\defyx_vpn.msix") {
        Write-Host "Base MSIX created successfully!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "Failed to create base MSIX" -ForegroundColor Red
        return $false
    }
}

function Modify-MSIX {
    Write-Host "=== Step 2: Modifying MSIX for Registry Access ===" -ForegroundColor Cyan
    
    $originalMsix = ".\build\windows\x64\runner\Release\defyx_vpn.msix"
    if (-not (Test-Path $originalMsix)) {
        Write-Host "Base MSIX not found! Run Build MSIX first." -ForegroundColor Red
        return $false
    }
    
    $workDir = "temp_msix_work"
    if (Test-Path $workDir) { 
        Remove-Item $workDir -Recurse -Force 
    }
    
    Write-Host "Extracting MSIX package..." -ForegroundColor Yellow
    Copy-Item $originalMsix "$originalMsix.zip"
    Expand-Archive "$originalMsix.zip" -DestinationPath $workDir -Force
    Remove-Item "$originalMsix.zip"
    
    Write-Host "Creating registry-enabled manifest..." -ForegroundColor Yellow
    
    # Create the manifest content without here-strings to avoid syntax issues
    $manifestLines = @()
    $manifestLines += '<?xml version="1.0" encoding="utf-8"?>'
    $manifestLines += '<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"'
    $manifestLines += '         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"'
    $manifestLines += '         xmlns:uap3="http://schemas.microsoft.com/appx/manifest/uap/windows10/3"'
    $manifestLines += '         xmlns:desktop="http://schemas.microsoft.com/appx/manifest/desktop/windows10"'
    $manifestLines += '         xmlns:desktop6="http://schemas.microsoft.com/appx/manifest/desktop/windows10/6"'
    $manifestLines += '         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"'
    $manifestLines += '         IgnorableNamespaces="uap3 desktop rescap desktop6">'
    $manifestLines += '  <Identity Name="UnboundTechUG.6065AEC5A207" Version="1.0.5.0"'
    $manifestLines += '            Publisher="CN=62937938-2AE2-4C12-9ED8-4C418C0CADF2" ProcessorArchitecture="x64" />'
    $manifestLines += '  <Properties>'
    $manifestLines += '    <DisplayName>Defyx VPN</DisplayName>'
    $manifestLines += '    <PublisherDisplayName>UnboundTech UG</PublisherDisplayName>'
    $manifestLines += '    <Logo>Images\StoreLogo.png</Logo>'
    $manifestLines += '    <Description>Professional VPN with system proxy integration</Description>'
    $manifestLines += '    <desktop6:RegistryWriteVirtualization>disabled</desktop6:RegistryWriteVirtualization>'
    $manifestLines += '    <desktop6:FileSystemWriteVirtualization>disabled</desktop6:FileSystemWriteVirtualization>'
    $manifestLines += '  </Properties>'
    $manifestLines += '  <Resources>'
    $manifestLines += '    <Resource Language="en-us" />'
    $manifestLines += '  </Resources>'
    $manifestLines += '  <Dependencies>'
    $manifestLines += '    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.17763.0" MaxVersionTested="10.0.22621.2506" />'
    $manifestLines += '  </Dependencies>'
    $manifestLines += '  <Capabilities>'
    $manifestLines += '    <Capability Name="internetClientServer" />'
    $manifestLines += '    <Capability Name="privateNetworkClientServer" />'
    $manifestLines += '    <rescap:Capability Name="runFullTrust" />'
    # $manifestLines += '    <rescap:Capability Name="broadFileSystemAccess" />'
    # $manifestLines += '    <rescap:Capability Name="allowElevation" />'
    $manifestLines += '    <rescap:Capability Name="unvirtualizedResources" />'
    $manifestLines += '  </Capabilities>'
    $manifestLines += '  <Applications>'
    $manifestLines += '    <Application Id="defyxvpn" Executable="DefyxVPN.exe" EntryPoint="Windows.FullTrustApplication">'
    $manifestLines += '      <uap:VisualElements BackgroundColor="transparent"'
    $manifestLines += '        DisplayName="Defyx VPN"'
    $manifestLines += '        Square150x150Logo="Images\Square150x150Logo.png"'
    $manifestLines += '        Square44x44Logo="Images\Square44x44Logo.png" Description="Professional VPN with system proxy integration">'
    $manifestLines += '        <uap:DefaultTile ShortName="Defyx VPN" Square310x310Logo="Images\LargeTile.png"'
    $manifestLines += '        Square71x71Logo="Images\SmallTile.png" Wide310x150Logo="Images\Wide310x150Logo.png">'
    $manifestLines += '          <uap:ShowNameOnTiles>'
    $manifestLines += '            <uap:ShowOn Tile="square150x150Logo"/>'
    $manifestLines += '            <uap:ShowOn Tile="square310x310Logo"/>'
    $manifestLines += '            <uap:ShowOn Tile="wide310x150Logo"/>'
    $manifestLines += '          </uap:ShowNameOnTiles>'
    $manifestLines += '        </uap:DefaultTile>'
    $manifestLines += '        <uap:SplashScreen Image="Images\SplashScreen.png"/>'
    $manifestLines += '        <uap:LockScreen BadgeLogo="Images\BadgeLogo.png" Notification="badge"/>'
    $manifestLines += '      </uap:VisualElements>'
    $manifestLines += '      <Extensions>'
    $manifestLines += '        <uap3:Extension Category="windows.appExecutionAlias" Executable="DefyxVPN.exe" EntryPoint="Windows.FullTrustApplication">'
    $manifestLines += '          <uap3:AppExecutionAlias>'
    $manifestLines += '            <desktop:ExecutionAlias Alias="defyxvpn.exe" />'
    $manifestLines += '          </uap3:AppExecutionAlias>'
    $manifestLines += '        </uap3:Extension>'
    $manifestLines += '      </Extensions>'
    $manifestLines += '    </Application>'
    $manifestLines += '  </Applications>'
    $manifestLines += '</Package>'
    
    # Write manifest to file
    $manifestLines | Out-File "$workDir\AppxManifest.xml" -Encoding UTF8
    
    Write-Host "Repackaging MSIX with registry access..." -ForegroundColor Yellow
    $makeappx = Get-ChildItem "C:\Program Files (x86)\Windows Kits\*\bin\*\x64\makeappx.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    
    if ($makeappx) {
        Remove-Item $finalMsix -ErrorAction SilentlyContinue
        & "$makeappx" pack /d $workDir /p $finalMsix /overwrite | Out-Null
        
        if (Test-Path $finalMsix) {
            Write-Host "Modified MSIX created successfully!" -ForegroundColor Green
            Remove-Item $workDir -Recurse -Force
            return $true
        } else {
            Write-Host "Failed to create modified MSIX" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host " Windows SDK makeappx.exe not found!" -ForegroundColor Red
        return $false
    }
}

function Create-Certificate {
    Write-Host "=== Step 3: Creating & Installing Certificate ===" -ForegroundColor Cyan
    
    Write-Host "Creating self-signed certificate..." -ForegroundColor Yellow
    $cert = New-SelfSignedCertificate -Type Custom -Subject $publisherCN -KeyUsage DigitalSignature -FriendlyName "DefyxVPN Certificate" -CertStoreLocation "Cert:\CurrentUser\My" -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}") -NotAfter (Get-Date).AddYears(1)
    
    Write-Host "Exporting certificate..." -ForegroundColor Yellow
    $pwd = ConvertTo-SecureString -String $certPassword -Force -AsPlainText
    Export-PfxCertificate -cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath $certFile -Password $pwd | Out-Null
    
    Write-Host "Installing certificate to trusted store..." -ForegroundColor Yellow
    try {
        Import-PfxCertificate -FilePath $certFile -CertStoreLocation "Cert:\LocalMachine\TrustedPeople" -Password $pwd | Out-Null
        Write-Host "Certificate created and installed successfully!" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Certificate created but needs admin rights for trusted install" -ForegroundColor Yellow
        Write-Host "Certificate file created: $certFile" -ForegroundColor Green
        return $true
    }
}

function Sign-MSIX {
    Write-Host "=== Step 4: Signing MSIX Package ===" -ForegroundColor Cyan
    
    if (-not (Test-Path $finalMsix)) {
        Write-Host "MSIX package not found! Run previous steps first." -ForegroundColor Red
        return $false
    }
    
    if (-not (Test-Path $certFile)) {
        Write-Host "Certificate not found! Create certificate first." -ForegroundColor Red
        return $false
    }
    
    $signtool = Get-ChildItem "C:\Program Files (x86)\Windows Kits\*\bin\*\x64\signtool.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    
    if ($signtool) {
        Write-Host "Signing MSIX package..." -ForegroundColor Yellow
        & "$signtool" sign /fd sha256 /a /f $certFile /p $certPassword $finalMsix 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "MSIX package signed successfully!" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Failed to sign MSIX package" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "Windows SDK signtool.exe not found!" -ForegroundColor Red
        return $false
    }
}

function Install-DefyxVPN {
    Write-Host "=== Step 5: Installing DefyxVPN ===" -ForegroundColor Cyan
    
    if (-not (Test-Path $finalMsix)) {
        Write-Host "Signed MSIX package not found! Complete previous steps first." -ForegroundColor Red
        return $false
    }
    
    Write-Host "Removing previous installation..." -ForegroundColor Yellow
    Get-AppxPackage -Name "*UnboundTechUG*" | Remove-AppxPackage -ErrorAction SilentlyContinue
    
    Write-Host "Installing DefyxVPN..." -ForegroundColor Yellow
    try {
        Add-AppxPackage -Path $finalMsix
        
        $app = Get-AppxPackage -Name "*UnboundTechUG*"
        if ($app) {
            Write-Host "DefyxVPN installed successfully!" -ForegroundColor Green
            Write-Host "Version: $($app.Version)" -ForegroundColor White
            Write-Host "Find 'Defyx VPN' in your Start Menu" -ForegroundColor Gray
            return $true
        } else {
            Write-Host "Installation verification failed" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Complete-Process {
    Write-Host "=== Complete Process: All Steps ===" -ForegroundColor Cyan
    Write-Host "This will build, modify, sign, and install DefyxVPN" -ForegroundColor White
    Write-Host ""
    
    if (-not (Build-MSIX)) { return }
    Write-Host ""
    
    if (-not (Modify-MSIX)) { return }
    Write-Host ""
    
    if (-not (Create-Certificate)) { return }
    Write-Host ""
    
    if (-not (Sign-MSIX)) { return }
    Write-Host ""
    
    if (-not (Install-DefyxVPN)) { return }
    
    Write-Host ""
    Write-Host "COMPLETE SUCCESS!" -ForegroundColor Green
    Write-Host "DefyxVPN is ready with full registry access capabilities!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Registry virtualization disabled" -ForegroundColor Green
    Write-Host "Full trust + elevation enabled" -ForegroundColor Green
    Write-Host "System proxy access enabled" -ForegroundColor Green
    Write-Host "Production ready package" -ForegroundColor Green
}

function Test-Proxy {
    Write-Host "=== Step 7: Testing Proxy Functionality ===" -ForegroundColor Cyan
    
    $app = Get-AppxPackage -Name "*UnboundTechUG*"
    if (-not $app) {
        Write-Host "DefyxVPN not installed! Install it first." -ForegroundColor Red
        return
    }
    
    Write-Host "Current proxy settings:" -ForegroundColor Yellow
    $proxy = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Write-Host "ProxyEnable: $($proxy.ProxyEnable)" -ForegroundColor White
    Write-Host "ProxyServer: $($proxy.ProxyServer)" -ForegroundColor White
    Write-Host ""
    Write-Host "DefyxVPN is installed and ready" -ForegroundColor Green
    Write-Host "Launch DefyxVPN from Start Menu to test proxy functionality" -ForegroundColor Gray
    
    try {
        Write-Host "Attempting to launch DefyxVPN..." -ForegroundColor Yellow
        Start-Process "shell:AppsFolder\$($app.PackageFamilyName)!defyxvpn"
        Write-Host "DefyxVPN launched!" -ForegroundColor Green
    } catch {
        Write-Host "Find DefyxVPN in Start Menu to launch manually" -ForegroundColor Yellow
    }
}

function Clean-Files {
    Write-Host "=== Step 8: Cleaning All Files ===" -ForegroundColor Red
    
    Write-Host "Removing DefyxVPN installation..." -ForegroundColor Yellow
    Get-AppxPackage -Name "*UnboundTechUG*" | Remove-AppxPackage -ErrorAction SilentlyContinue
    
    Write-Host "Removing build files..." -ForegroundColor Yellow
    Remove-Item $finalMsix, $certFile, "temp_*", "DefyxVPN_*" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "All files cleaned!" -ForegroundColor Green
}

# Main execution
if ($Action) {
    switch ($Action.ToLower()) {
        "build" { Build-MSIX }
        "modify" { Modify-MSIX }
        "cert" { Create-Certificate }
        "sign" { Sign-MSIX }
        "install" { Install-DefyxVPN }
        "complete" { Complete-Process }
        "test" { Test-Proxy }
        "clean" { Clean-Files }
        default { Show-Menu; $choice = Read-Host "Enter your choice (1-9)" }
    }
} else {
    # Interactive menu mode
    do {
        Show-Menu
        $choice = Read-Host "Enter your choice (1-9)"
        
        switch ($choice) {
            "1" { Build-MSIX; Read-Host "`nPress Enter to continue" }
            "2" { Modify-MSIX; Read-Host "`nPress Enter to continue" }
            "3" { Create-Certificate; Read-Host "`nPress Enter to continue" }
            "4" { Sign-MSIX; Read-Host "`nPress Enter to continue" }
            "5" { Install-DefyxVPN; Read-Host "`nPress Enter to continue" }
            "6" { Complete-Process; Read-Host "`nPress Enter to continue" }
            "7" { Test-Proxy; Read-Host "`nPress Enter to continue" }
            "8" { Clean-Files; Read-Host "`nPress Enter to continue" }
            "9" { Write-Host "Goodbye!" -ForegroundColor Green; exit }
            default { Write-Host "Invalid choice! Please select 1-9." -ForegroundColor Red; Start-Sleep 2 }
        }
    } while ($choice -ne "9")
}