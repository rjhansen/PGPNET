#!/usr/bin/pwsh
#
# Copyright 2020, Rob Hansen
#
# Permission to use, copy, modify, and/or distribute this
# software for any purpose with or without fee is hereby
# granted, provided that the above copyright notice and
# this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS
# ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
# EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
# WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
# TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE
# USE OR PERFORMANCE OF THIS SOFTWARE.

# Path to GnuPG.  (Populated later.)
$gpg = ""
# Path to gpg.conf.  (Populated later.)
$conffile = ""
# The location of our key file.
$keyfileUrl = "https://www.dropbox.com/s/2tu23r92h8taock/" +`
   "PGPNET%40groups.io.asc?dl=1"
# A temporary file name used to store our downloaded keys.
$keyfile = [System.IO.Path]::GetTempFileName()
# The location of our group file.
$groupfileUrl = "https://www.dropbox.com/s/9abn35l2xqeqc04/" +`
   "PGPNET%40groups.io.txt?dl=1"
# A temporary file name used to store our downloaded membership list.
$groupfile = [System.IO.Path]::GetTempFileName()
# A list of our member's keys (populated later).
$keyids = New-Object Collections.Generic.List[string]
# Our new configuration file (populated later).
$newconf = New-Object Collections.Generic.List[string]

# Find GnuPG.
If ("Win32NT" -eq [environment]::OSVersion.Platform) {
   $conffile = $env:APPDATA + "\GnuPG\gpg.conf"
   If (Test-Path "HKLM:\SOFTWARE\GnuPG") {
      $gpg = (Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\GnuPG" `
         "Install Directory") + "\bin\gpg.exe"
   }
   ElseIf (Test-Path "HKLM:\SOFTWARE\WOW6432Node\GnuPG") {
      $gpg = (Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\WOW6432Node\GnuPG" `
         "Install Directory") + "\bin\gpg.exe"
   }
}
Elseif ("Unix" -eq [environment]::OSVersion.Platform) {
   $conffile = $env:HOME + "/.gnupg/gpg.conf"
   foreach ($_ in $env:PATH -Split ":") {
      Write-Host $_
      If ([System.IO.File]::Exists($_ + "/gpg")) {
         $gpg = $_ + "/gpg"
         break
      }
   }
}

# Ensure we have a path to the GnuPG binary and to gpg.conf.
If (! [System.IO.File]::Exists($gpg)) {
   Write-Host "Error: could not find GnuPG!"
   Exit
}
If (! [System.IO.File]::Exists($conffile)) {
   Write-Host "Error: could not find gpg.conf file!"
   Exit
}

# Load a copy of our gpg.conf file, skipping over any PGPNET-related
# group lines.
Get-Content $conffile | ForEach-Object {
   if (-not ($_ -match "^\s*group\s+(<)?pgpnet@groups.io(>)?\s*=.*$")) {
      $newconf.Add($_)
   }
}

# Acquire our files from Dropbox.
try {
   (New-Object System.Net.WebClient).DownloadFile($keyfileUrl, $keyfile)
   (New-Object System.Net.WebClient).DownloadFile($groupfileUrl, $groupfile)
} catch {
   Write-Host "Error: could not download files from Dropbox!"
   Exit
}

# Import our keyfile into GnuPG and then delete it.
&$gpg --quiet --batch --import $keyfile
if ($LASTEXITCODE -ne 0) {
   Write-Host "Error: GnuPG didn't like the keyfile."
   Exit
}
Remove-Item $keyfile

# Walk over our membership list, harvesting each member's key ID.
# Once done delete the file.
Get-Content $groupfile | Foreach-Object {
   if ($_ -match '^\s*(0x[A-Fa-f0-9]{16})\s+.*$') {
      $keyids.Add($Matches.1)
   }
}
Remove-Item $groupfile

# Add two group lines to our copy of the gpg.conf file
$newconf.Add("group <pgpnet@groups.io>=" + ($keyids.ToArray() -Join " "))
$newconf.Add("group pgpnet@groups.io=" + ($keyids.ToArray() -Join " "))

# Write out our new gpg.conf file
Out-File -FilePath $conffile -InputObject $newconf -Encoding ascii

# SIG # Begin signature block
# MIIcygYJKoZIhvcNAQcCoIIcuzCCHLcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAZv4Yl3R1fSEQU
# H0iTGKst1V07UixqnHrJJuvWVUfPNKCCCxkwggUxMIIEGaADAgECAhBn2il4jgV9
# pVu3d91I6iERMA0GCSqGSIb3DQEBCwUAMH0xCzAJBgNVBAYTAkdCMRswGQYDVQQI
# ExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGjAYBgNVBAoT
# EUNPTU9ETyBDQSBMaW1pdGVkMSMwIQYDVQQDExpDT01PRE8gUlNBIENvZGUgU2ln
# bmluZyBDQTAeFw0xNjA2MjgwMDAwMDBaFw0yMTA2MjgyMzU5NTlaMIGaMQswCQYD
# VQQGEwJVUzEOMAwGA1UEEQwFMjAxNzExCzAJBgNVBAgMAlZBMRAwDgYDVQQHDAdI
# ZXJuZG9uMQ0wCwYDVQQJDAQjODAzMR0wGwYDVQQJDBQyNTU3IEZhcm1jcmVzdCBE
# cml2ZTEWMBQGA1UECgwNUm9iZXJ0IEhhbnNlbjEWMBQGA1UEAwwNUm9iZXJ0IEhh
# bnNlbjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAN3PgVF88TGcaWsA
# W0MCCO8e9O9Zh1A8/sJTZx8F5GWHS6W+q8RfwrVdiQjc99VMFOAsRm3vBchvNojq
# bqEkim/Xs890xgGPy62iPehiR2wiIvqkBHZZiFVfkQpx46QaYHVyVVYfVsHQtA8d
# iT6ZxqApOjDDh0hjsKYWWRk6gC0NovD8YcvakoBE/ItLv/G5QnldZVplHkim7fY6
# qZ6XNHdm50E36RR73xJNZ2dwEzEkPsj6J8KIvoWt9FXILg79HJft2bS0rO/mr77C
# 1Sl4LFwZvrZR19cyGcSUjfpy0Six+DdFhmwYiC6nCyVtc66jJo4uY3+8K5siMSa1
# AjITSPECAwEAAaOCAY0wggGJMB8GA1UdIwQYMBaAFCmRYP+KTfrr+aZquM/55ku9
# Sc4SMB0GA1UdDgQWBBTjEllCTK6fkrJfRAAhxnWnMkwpjzAOBgNVHQ8BAf8EBAMC
# B4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzARBglghkgBhvhC
# AQEEBAMCBBAwRgYDVR0gBD8wPTA7BgwrBgEEAbIxAQIBAwIwKzApBggrBgEFBQcC
# ARYdaHR0cHM6Ly9zZWN1cmUuY29tb2RvLm5ldC9DUFMwQwYDVR0fBDwwOjA4oDag
# NIYyaHR0cDovL2NybC5jb21vZG9jYS5jb20vQ09NT0RPUlNBQ29kZVNpZ25pbmdD
# QS5jcmwwdAYIKwYBBQUHAQEEaDBmMD4GCCsGAQUFBzAChjJodHRwOi8vY3J0LmNv
# bW9kb2NhLmNvbS9DT01PRE9SU0FDb2RlU2lnbmluZ0NBLmNydDAkBggrBgEFBQcw
# AYYYaHR0cDovL29jc3AuY29tb2RvY2EuY29tMA0GCSqGSIb3DQEBCwUAA4IBAQBg
# wrckjDPnCoA1GV8cBd04HS+MVfItD9OXD6jALwmoyC8NdkTp+UsWpXw+mEBUx9bs
# AzfDjR/OB2u6lStAe3DUQOIDKBPijpcn+9gyb4AGaj4Yu8EQEv8NqmpV3KeB1jv+
# HYkX1AxPtAdFa0AV6wrHe0TBwMo2nMnOXV6PS8mqRinq7qQOnskZOr2UmGmxGzwW
# 6EpzTqm1BGBqPa4k8SVxdO8sJ8o12S+v7Vu9s9JtJDXYfQKwqvyIbrSlmI7RsCRl
# GKlt+gRwnE56E064JWtYPFQk4Hlp3lfy4c5kMBPljBY+5Up2vvD3J5r7y9xf6Viz
# DYDp2l8phMPVM+WQQWORMIIF4DCCA8igAwIBAgIQLnyHzA6TSlL+lP0ct800rzAN
# BgkqhkiG9w0BAQwFADCBhTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIg
# TWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENB
# IExpbWl0ZWQxKzApBgNVBAMTIkNPTU9ETyBSU0EgQ2VydGlmaWNhdGlvbiBBdXRo
# b3JpdHkwHhcNMTMwNTA5MDAwMDAwWhcNMjgwNTA4MjM1OTU5WjB9MQswCQYDVQQG
# EwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxm
# b3JkMRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDEjMCEGA1UEAxMaQ09NT0RP
# IFJTQSBDb2RlIFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQCmmJBjd5E0f4rR3elnMRHrzB79MR2zuWJXP5O8W+OfHiQyESdrvFGRp8+e
# niWzX4GoGA8dHiAwDvthe4YJs+P9omidHCydv3Lj5HWg5TUjjsmK7hoMZMfYQqF7
# tVIDSzqwjiNLS2PgIpQ3e9V5kAoUGFEs5v7BEvAcP2FhCoyi3PbDMKrNKBh1SMF5
# WgjNu4xVjPfUdpA6M0ZQc5hc9IVKaw+A3V7Wvf2pL8Al9fl4141fEMJEVTyQPDFG
# y3CuB6kK46/BAW+QGiPiXzjbxghdR7ODQfAuADcUuRKqeZJSzYcPe9hiKaR+ML0b
# tYxytEjy4+gh+V5MYnmLAgaff9ULAgMBAAGjggFRMIIBTTAfBgNVHSMEGDAWgBS7
# r34CPfqm8TyEjq3uOJjs2TIy1DAdBgNVHQ4EFgQUKZFg/4pN+uv5pmq4z/nmS71J
# zhIwDgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwEwYDVR0lBAww
# CgYIKwYBBQUHAwMwEQYDVR0gBAowCDAGBgRVHSAAMEwGA1UdHwRFMEMwQaA/oD2G
# O2h0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0NPTU9ET1JTQUNlcnRpZmljYXRpb25B
# dXRob3JpdHkuY3JsMHEGCCsGAQUFBwEBBGUwYzA7BggrBgEFBQcwAoYvaHR0cDov
# L2NydC5jb21vZG9jYS5jb20vQ09NT0RPUlNBQWRkVHJ1c3RDQS5jcnQwJAYIKwYB
# BQUHMAGGGGh0dHA6Ly9vY3NwLmNvbW9kb2NhLmNvbTANBgkqhkiG9w0BAQwFAAOC
# AgEAAj8COcPu+Mo7id4MbU2x8U6ST6/COCwEzMVjEasJY6+rotcCP8xvGcM91hoI
# lP8l2KmIpysQGuCbsQciGlEcOtTh6Qm/5iR0rx57FjFuI+9UUS1SAuJ1CAVM8bdR
# 4VEAxof2bO4QRHZXavHfWGshqknUfDdOvf+2dVRAGDZXZxHNTwLk/vPa/HUX2+y3
# 92UJI0kfQ1eD6n4gd2HITfK7ZU2o94VFB696aSdlkClAi997OlE5jKgfcHmtbUIg
# os8MbAOMTM1zB5TnWo46BLqioXwfy2M6FafUFRunUkcyqfS/ZEfRqh9TTjIwc8Jv
# t3iCnVz/RrtrIh2IC/gbqjSm/Iz13X9ljIwxVzHQNuxHoc/Li6jvHBhYxQZ3ykub
# Ua9MCEp6j+KjUuKOjswm5LLY5TjCqO3GgZw1a6lYYUoKl7RLQrZVnb6Z53BtWfht
# Kgx/GWBfDJqIbDCsUgmQFhv/K53b0CDKieoofjKOGd97SDMe12X4rsn4gxSTdn1k
# 0I7OvjV9/3IxTZ+evR5sL6iPDAZQ+4wns3bJ9ObXwzTijIchhmH+v1V04SF3Awpo
# bLvkyanmz1kl63zsRQ55ZmjoIs2475iFTZYRPAmK0H+8KCgT+2rKVI2SXM3CZZgG
# ns5IW9S1N5NGQXwH3c/6Q++6Z2H/fUnguzB9XIDj5hY5S6cxghEHMIIRAwIBATCB
# kTB9MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAw
# DgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDEjMCEG
# A1UEAxMaQ09NT0RPIFJTQSBDb2RlIFNpZ25pbmcgQ0ECEGfaKXiOBX2lW7d33Ujq
# IREwDQYJYIZIAWUDBAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0B
# CQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAv
# BgkqhkiG9w0BCQQxIgQgkGML1A4C4Yoo+LP547X/IW45oOHsQ0bmqn0bIklS5z0w
# DQYJKoZIhvcNAQEBBQAEggEAdiFQikROUyb3Jsh7C8B5xvvK2ADWNVlzEfOJhjub
# Vao92JtgoyteZIqcNFR/CT0KE23QUjGPHjiYKDCH6hZH7ohxNIYRLBcVWQefyd0B
# oJGJyAL69fsNnOT42gwjbYXmzU7OAbX1gJJgg6A8ynjX+twSuEkgG9cDX9eiE162
# bUAQNa5q/dlZx+uf4lLRfLWTc4s1rFSdtGYb5GWK1Xgjmn8pyiz4vitJQx3FCLHP
# iqoQX0SknIpPqB0TcFacZELe3Tm+rDWoHxSowlttZNrUj11o2QhhPh9Z2fdZMPW3
# oi90cqMyI1d8J2L38RKVGOJRoR4HuO9F3oE8MQ8gaJ+UKqGCDsgwgg7EBgorBgEE
# AYI3AwMBMYIOtDCCDrAGCSqGSIb3DQEHAqCCDqEwgg6dAgEDMQ8wDQYJYIZIAWUD
# BAIBBQAwdwYLKoZIhvcNAQkQAQSgaARmMGQCAQEGCWCGSAGG/WwHATAxMA0GCWCG
# SAFlAwQCAQUABCB0mUjGIA5p6J2YA+Bf3CXu7xPMebRwKk5edwLhNwIp6AIQY7W8
# dydEvjOoUuVLfiqisBgPMjAyMDEyMDcyMjUzMzRaoIILuzCCBoIwggVqoAMCAQIC
# EATNP4VornbGG7D+cWDMp20wDQYJKoZIhvcNAQELBQAwcjELMAkGA1UEBhMCVVMx
# FTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNv
# bTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIFRpbWVzdGFtcGlu
# ZyBDQTAeFw0xOTEwMDEwMDAwMDBaFw0zMDEwMTcwMDAwMDBaMEwxCzAJBgNVBAYT
# AlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjEkMCIGA1UEAxMbVElNRVNUQU1Q
# LVNIQTI1Ni0yMDE5LTEwLTE1MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
# AQEA6WQ1nPqpmGVkG+QX3LgpNsxnCViFTTDgyf/lOzwRKFCvBzHiXQkYwvaJjGkI
# BCPgdy2dFeW46KFqjv/UrtJ6Fu/4QbUdOXXBzy+nrEV+lG2sAwGZPGI+fnr9RZcx
# tPq32UI+p1Wb31pPWAKoMmkiE76Lgi3GmKtrm7TJ8mURDHQNsvAIlnTE6LJIoqEU
# pfj64YlwRDuN7/uk9MO5vRQs6wwoJyWAqxBLFhJgC2kijE7NxtWyZVkh4HwsEo1w
# Do+KyuDT17M5d1DQQiwues6cZ3o4d1RA/0+VBCDU68jOhxQI/h2A3dDnK3jqvx9w
# xu5CFlM2RZtTGUlinXoCm5UUowIDAQABo4IDODCCAzQwDgYDVR0PAQH/BAQDAgeA
# MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwggG/BgNVHSAE
# ggG2MIIBsjCCAaEGCWCGSAGG/WwHATCCAZIwKAYIKwYBBQUHAgEWHGh0dHBzOi8v
# d3d3LmRpZ2ljZXJ0LmNvbS9DUFMwggFkBggrBgEFBQcCAjCCAVYeggFSAEEAbgB5
# ACAAdQBzAGUAIABvAGYAIAB0AGgAaQBzACAAQwBlAHIAdABpAGYAaQBjAGEAdABl
# ACAAYwBvAG4AcwB0AGkAdAB1AHQAZQBzACAAYQBjAGMAZQBwAHQAYQBuAGMAZQAg
# AG8AZgAgAHQAaABlACAARABpAGcAaQBDAGUAcgB0ACAAQwBQAC8AQwBQAFMAIABh
# AG4AZAAgAHQAaABlACAAUgBlAGwAeQBpAG4AZwAgAFAAYQByAHQAeQAgAEEAZwBy
# AGUAZQBtAGUAbgB0ACAAdwBoAGkAYwBoACAAbABpAG0AaQB0ACAAbABpAGEAYgBp
# AGwAaQB0AHkAIABhAG4AZAAgAGEAcgBlACAAaQBuAGMAbwByAHAAbwByAGEAdABl
# AGQAIABoAGUAcgBlAGkAbgAgAGIAeQAgAHIAZQBmAGUAcgBlAG4AYwBlAC4wCwYJ
# YIZIAYb9bAMVMB8GA1UdIwQYMBaAFPS24SAd/imu0uRhpbKiJbLIFzVuMB0GA1Ud
# DgQWBBRWUw/BxgenTdfYbldygFBM5OyewTBxBgNVHR8EajBoMDKgMKAuhixodHRw
# Oi8vY3JsMy5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLXRzLmNybDAyoDCgLoYs
# aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC10cy5jcmwwgYUG
# CCsGAQUFBwEBBHkwdzAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQu
# Y29tME8GCCsGAQUFBzAChkNodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGln
# aUNlcnRTSEEyQXNzdXJlZElEVGltZXN0YW1waW5nQ0EuY3J0MA0GCSqGSIb3DQEB
# CwUAA4IBAQAug6FEBUoE47kyUvrZgfAau/gJjSO5PdiSoeZGHEovbno8Y243F6Ma
# v1gjskOclINOOQmwLOjH4eLM7ct5a87eIwFH7ZVUgeCAexKxrwKGqTpzav74n8GN
# 0SGM5CmCw4oLYAACnR9HxJ+0CmhTf1oQpvgi5vhTkjFf2IKDLW0TQq6DwRBOpCT0
# R5zeDyJyd1x/T+k5mCtXkkTX726T2UPHBDNjUTdWnkcEEcOjWFQh2OKOVtdJP1f8
# Cp8jXnv0lI3dnRq733oqptJFplUMj/ZMivKWz4lG3DGykZCjXzMwYFX1/GswrKHt
# 5EdOM55naii1TcLtW5eC+MupCGxTCbT3MIIFMTCCBBmgAwIBAgIQCqEl1tYyG35B
# 5AXaNpfCFTANBgkqhkiG9w0BAQsFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMM
# RGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQD
# ExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMTYwMTA3MTIwMDAwWhcN
# MzEwMTA3MTIwMDAwWjByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQg
# SW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2Vy
# dCBTSEEyIEFzc3VyZWQgSUQgVGltZXN0YW1waW5nIENBMIIBIjANBgkqhkiG9w0B
# AQEFAAOCAQ8AMIIBCgKCAQEAvdAy7kvNj3/dqbqCmcU5VChXtiNKxA4HRTNREH3Q
# +X1NaH7ntqD0jbOI5Je/YyGQmL8TvFfTw+F+CNZqFAA49y4eO+7MpvYyWf5fZT/g
# m+vjRkcGGlV+Cyd+wKL1oODeIj8O/36V+/OjuiI+GKwR5PCZA207hXwJ0+5dyJoL
# VOOoCXFr4M8iEA91z3FyTgqt30A6XLdR4aF5FMZNJCMwXbzsPGBqrC8HzP3w6kfZ
# iFBe/WZuVmEnKYmEUeaC50ZQ/ZQqLKfkdT66mA+Ef58xFNat1fJky3seBdCEGXIX
# 8RcG7z3N1k3vBkL9olMqT4UdxB08r8/arBD13ays6Vb/kwIDAQABo4IBzjCCAcow
# HQYDVR0OBBYEFPS24SAd/imu0uRhpbKiJbLIFzVuMB8GA1UdIwQYMBaAFEXroq/0
# ksuCMS1Ri6enIZ3zbcgPMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQD
# AgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHkGCCsGAQUFBwEBBG0wazAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0Eu
# Y3J0MIGBBgNVHR8EejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMFAGA1UdIARJ
# MEcwOAYKYIZIAYb9bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdp
# Y2VydC5jb20vQ1BTMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAQEAcZUS
# 6VGHVmnN793afKpjerN4zwY3QITvS4S/ys8DAv3Fp8MOIEIsr3fzKx8MIVoqtwU0
# HWqumfgnoma/Capg33akOpMP+LLR2HwZYuhegiUexLoceywh4tZbLBQ1QwRostt1
# AuByx5jWPGTlH0gQGF+JOGFNYkYkh2OMkVIsrymJ5Xgf1gsUpYDXEkdws3XVk4WT
# fraSZ/tTYYmo9WuWwPRYaQ18yAGxuSh1t5ljhSKMYcp5lH5Z/IwP42+1ASa2bKXu
# h1Eh5Fhgm7oMLSttosR+u8QlK0cCCHxJrhO24XxCQijGGFbPQTS2Zl22dHv1VjMi
# LyI2skuiSpXY9aaOUjGCAk0wggJJAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAv
# BgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBpbmcgQ0EC
# EATNP4VornbGG7D+cWDMp20wDQYJYIZIAWUDBAIBBQCggZgwGgYJKoZIhvcNAQkD
# MQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yMDEyMDcyMjUzMzRaMCsG
# CyqGSIb3DQEJEAIMMRwwGjAYMBYEFAMlvVBe2pYwLcIvT6AeTCi+KDTFMC8GCSqG
# SIb3DQEJBDEiBCCv4n3vz7DlGPFc3dAZvieU06uX0qlF845rJ9rSWm+2xjANBgkq
# hkiG9w0BAQEFAASCAQB8OX7BrZdylndj1NpdTHVVjpN4mW2Jnuinw2CAxhCugeaw
# xm9+UMxoqxUoklGF9rrA7KxZzXKMvB9d4Np704hmwrUqAdmbbe1Afj8vRgcJyTxv
# haCe9Ci8z6n9uGxlxoOdPw136F7KKShF9nLN/LJkc4SLiEdpebFDkxkXebFsBA7B
# iACkN879bMmvGMAP3RFZVRdw5EqKJSPOD3Ltckz4BX7KXxHDHYXKAxtaIEKPT+aw
# fN4d06tdUJYHBzDpWR2tOC+f85RVU9GL7NNmXobYZXKkiz4l/qYJsSFD3eChNQUQ
# lViq/TeqWE9M5O8awpDzz+jk02BMd+k9IA9zKGcY
# SIG # End signature block
