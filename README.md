# AnonSurf OpenSUSE Module

## Notes

This script is based on the original [AnonSurf Module](https://github.com/ParrotSec/anonsurf). It was modified such that it runs on one particular system (so a lot of assumptions were made, and quite a few features non-essential features were removed). It runs on OpenSUSE Tumbleweed with NetworkManager, firewalld and tor installed. It might run under other rpm-based distributions but there are absolutely no guarantees. The script is provided as is (**please read through the script** to make sure it does what you want). Also, I would advise you to read on [transparent proxy guide from Tor Project](https://trac.torproject.org/projects/tor/wiki/doc/TransparentProxy), and make sure you understand why it is discouraged to use tor this way.

## Installation

Modify any variables specified at the top of the script to reflect your configuration (most importantly _out_if). Copy torrc to the location of your tor configs. Copy (or symlink) anonsurf.sh to the location in PATH

## Usage

init -- Kill dangerous apps before starting tunneling
start -- Start system-wide TOR tunnel
stop -- Stop anonsurf and return to clearnet
restart -- Combines "stop" and "start" options
change -- Restart TOR to change identity