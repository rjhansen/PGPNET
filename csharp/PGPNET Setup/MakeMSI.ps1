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
