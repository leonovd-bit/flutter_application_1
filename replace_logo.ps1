# Fresh Punk Logo Replacement Script
# This script helps you replace the app logo

Write-Host "=== Fresh Punk Logo Replacement ===" -ForegroundColor Green
Write-Host ""

$logoPath = "C:\Users\dleon\OneDrive\Desktop\flutter_application_1\assets\images\freshpunk_logo.png"
$backupPath = "C:\Users\dleon\OneDrive\Desktop\flutter_application_1\assets\images\freshpunk_logo_backup.png"

# Check if current logo exists
if (Test-Path $logoPath) {
    Write-Host "✓ Current logo found at: $logoPath" -ForegroundColor Yellow
    
    # Create backup
    Copy-Item $logoPath $backupPath -Force
    Write-Host "✓ Backup created at: $backupPath" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "INSTRUCTIONS:" -ForegroundColor Cyan
    Write-Host "1. Save your new Fresh Punk logo image as 'freshpunk_logo.png'"
    Write-Host "2. Replace the file at: $logoPath"
    Write-Host "3. Recommended size: 512x512 pixels (PNG with transparent background)"
    Write-Host "4. Run 'flutter run -d chrome' to see the changes"
    Write-Host ""
    Write-Host "The logo appears in:"
    Write-Host "- Home page (center, 100px height)"
    Write-Host "- Splash screen (280x280px)"
    Write-Host ""
    
    # Wait for user confirmation
    Write-Host "Press any key after you've replaced the logo file..." -ForegroundColor Green
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Check if file was updated
    $currentSize = (Get-Item $logoPath).Length
    $backupSize = (Get-Item $backupPath).Length
    
    if ($currentSize -ne $backupSize) {
        Write-Host "✓ Logo file has been updated! New size: $currentSize bytes" -ForegroundColor Green
        Write-Host "✓ You can now run the app to see your new logo" -ForegroundColor Green
    } else {
        Write-Host "⚠ Logo file size unchanged. Make sure you replaced the file." -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ Logo file not found at: $logoPath" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Run: flutter run -d chrome"
Write-Host "2. Check both the splash screen and home page"
Write-Host "3. If the logo looks good, you're done!"
