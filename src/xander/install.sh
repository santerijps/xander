#!/bin/bash
[ -d "~/.xander" ] && mkdir "~/.xander"
# Get latest version of Xander
x=($(ls ~/.nimble/pkgs | grep xander-))
y=~/.nimble/pkgs/${x[-1]}/xander.nim
# Compiling with cpp for better compatiblity
echo "Found Xander in $y"
echo "Compiling ${x[-1]}"
~/.nimble/bin/nim cpp --verbosity:1 --hints:off --threads:on -o:~/.xander/xander $y
echo "Finished. The Xander executable can be found in ~/.xander"
echo "Add the following line to ~/.bashrc or ~/.profile:"
echo ""
echo "  export PATH=/home/$USER/.xander:\$PATH"
echo ""