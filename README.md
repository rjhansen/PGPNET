# pgpnet

This repo contains a handful of scripts and applications I use to automate a number of tasks for the PGPNET mailing list.  None meet my professional standards for code: “it works for me” is the best which can be said for them.  But if they’re useful to you, have at them.

## Licensing

All scripts are released under terms of the ISC License.  Share and enjoy.

## C#

The `csharp` directory contains C# applications which should work on anything with .NET 4.5.2 or later.  (If you’re running Windows and you’ve installed the latest updates, you almost certainly have it installed.)  Some of these applications have Windows MSI installers, too.

## Python

You’ll need Python 3.  (I used 3.6, but anything 3.4 and beyond **should** work…)  Further, due to the `gpg` module not existing for Windows Python, these scripts are limited to UNIX.