# key_checker

This app pulls down a current list of PGPNET members and examines their certificates for errors.

A well-made certificate will have:

* Primary keys and subkeys of NIST-approved lengths
  * 2048 bits for RSA, DSA, and Elgamal
  * 128 bits for ECC
* AES256 in the first three preferred ciphers
* SHA256 in the first three preferred hashes
* No cipher or hash shadowing
  * 3DES, if present, must be the least-preferred cipher
  * SHA-1, if present, must be the least-preferred hash

A log file will get written to `key_checker.log` in the home directory.

## Requirements

* Python 3.6 with requests, gpg
