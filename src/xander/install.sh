#!/bin/bash
[ -d "~/.xander" ] && mkdir "~/.xander"
printf "Compiling Xander..."
# Compiling with cpp for better compatiblity
~/.nimble/bin/nim cpp --verbosity:1 --hints:off --threads:on -o:~/.xander/xander ~/.nimble/pkgs/xander-0.5.0/xander.nim
echo "Finished. The Xander executable can be found in ~/.xander"
echo "Add the following line to ~/.bashrc or ~/.profile:"
echo ""
echo "  export PATH=/home/$USER/.xander:\$PATH"
echo ""