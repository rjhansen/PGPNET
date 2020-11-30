# update_prr

This updates keyrings and Enigmail’s per-recipients rule automagically.  Much easier than maintaining them by hand.  Note that you may need to restart Thunderbird to force it to reload the per-recipient rules.

## Requirements

* Linux, OS X, or macOS only.  (Windows will be supported as soon as the `gpg` module is ported to Windows.)
* Python 3
* `requests`
* `gpg`

Both `requests` and `gpg` may be installed from Python's `pip` tool.  Using Homebrew on macOS, for instance, `pip3 install requests` and `pip3 install gpg` will do the trick.

## Usage

`update_prr`

## Error handling

Informational messages are printed to the screen and written to a log file, `update_prr.log`, in your home directory.
