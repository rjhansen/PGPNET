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
