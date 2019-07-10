#!/bin/bash
[ -d "~/.xander" ] && mkdir "~/.xander"
printf "Compiling Xander..."
~/.nimble/bin/nim c --verbosity:1 --hints:off -o:~/.xander/xander ~/.nimble/pkgs/xander-0.5.0/xander.nim
echo "Finished. The Xander executable can be found in ~/.xander"
echo "Add the following line to ~/.bashrc or ~/.profile:"
echo ""
echo "  export PATH=/home/$USER/.xander:\$PATH"
echo ""