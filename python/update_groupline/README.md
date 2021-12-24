# update_aliases

This updates Thunderbird's aliases file, GnuPG keyrings, and GnuPG
configuration files, all at once for use with PGPNET.

## Requirements

* Python 3
* `urllib3`
* GnuPG (Windows users _must_ use [GPG4WIN](https://www.gpg4win.org))
* Thunderbird 78 or later (technically optional, but a good idea)

To install `urllib3`, do something like (on UNIX):

`$ pip3 install urllib3`

Or on Windows,

`> pip install urllib3`

## Usage

`update_aliases`

Note that you will need to set Thunderbird's alias file location to a
`file://` URI.  For instance, my alias file on Windows is:

`file:///C:/Users/rjh/AppData/Roaming/gnupg/thunderbird_aliases.json`

On UNIX it's:

`file:///home/rjh/.gnupg/thunderbird_aliases.json`

On MacOS (untested!) it would probably be,

`file:///Users/rjh/.gnupg/thunderbird_aliases.json`