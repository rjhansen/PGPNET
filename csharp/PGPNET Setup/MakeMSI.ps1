# This code depends on PowerShell being set with the Microsoft
# Visual Studio development environment variables, and with the
# Wix toolset's bin directory being in your PATH.
#
# Unless you have an Authenticode signing certificate, comment
# out the signtool lines.
#
# In your Documents\WindowsPowershell dir, add this to the file
# profile.ps1.  (Note: you may need to alter the directory in the
# first line to reflect your particular VS version.)
#
# =====
#
# pushd 'C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC'
# cmd /c "vcvarsall.bat amd64&set" |
# foreach {
#   if ($_ -match "=") {
#     $v = $_.split("="); set-item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
#   }
# }
# popd
# write-host "`nVisual Studio 2015 Command Prompt variables set." -ForegroundColor Yellow

& MSBuild.exe ".\PGPNET Setup.sln" /t:Clean /p:Configuration=Release /p:Platform="Any CPU"
& MSBuild.exe ".\PGPNET Setup.sln" /t:Rebuild /p:Configuration=Release /p:Platform="Any CPU"
& signtool.exe sign /tr http://timestamp.digicert.com /td sha256 /fd sha256 /a ".\PGPNET Setup\bin\Release\PGPNET Setup.exe"
Push-Location ".\PGPNET Setup"
& candle.exe ".\PGPNET Setup.wxs"
& light.exe -ext WixUIExtension ".\PGPNET Setup.wixobj"
& signtool.exe sign /tr http://timestamp.digicert.com /td sha256 /fd sha256 /a ".\PGPNET Setup.msi"
Copy-Item ".\PGPNET Setup.msi" -Destination 'C:\Users\Robert J. Hansen\Desktop'
Pop-Location
Remove-Item -Force ".\PGPNET Setup\*.msi"
Remove-Item -Force ".\PGPNET Setup\*.wixobj"
Remove-Item -Force ".\PGPNET Setup\*.wixpdb"
Remove-Item -Force -Recurse ".\PGPNET Setup\bin"
Remove-Item -Force -Recurse ".\PGPNET Setup\obj"
