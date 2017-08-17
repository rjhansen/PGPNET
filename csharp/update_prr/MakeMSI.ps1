& MSBuild.exe .\UpdatePRR.sln /t:Clean /p:Configuration=Release /p:Platform="Any CPU"
Remove-Item -Force UpdatePRR\*.msi
Remove-Item -Force UpdatePRR\*.wixobj
Remove-Item -Force UpdatePRR\*.wixpdb
Remove-Item -Force -Recurse UpdatePRR\bin
Remove-Item -Force -Recurse UpdatePRR\obj
& MSBuild.exe .\UpdatePRR.sln /t:Rebuild /p:Configuration=Release /p:Platform="Any CPU"
& signtool.exe sign /tr http://timestamp.digicert.com /td sha256 /fd sha256 /a UpdatePRR\bin\Release\UpdatePRR.exe
& signtool.exe sign /tr http://timestamp.digicert.com /td sha256 /fd sha256 /a UpdatePRR\bin\Release\Microsoft.Extensions.CommandLineUtils.dll
Push-Location UpdatePRR
& candle.exe UpdatePRR.wxs
& light.exe -ext WixUIExtension UpdatePRR.wixobj
& signtool.exe sign /tr http://timestamp.digicert.com /td sha256 /fd sha256 /a UpdatePRR.msi
Copy-Item UpdatePrr.msi -Destination 'C:\Users\Robert J. Hansen\Desktop'
Pop-Location
Remove-Item -Force UpdatePRR\*.msi
Remove-Item -Force UpdatePRR\*.wixobj
Remove-Item -Force UpdatePRR\*.wixpdb
Remove-Item -Force -Recurse UpdatePRR\bin
Remove-Item -Force -Recurse UpdatePRR\obj
