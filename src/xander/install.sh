#!/bin/bash
# Colors
GREEN='\033[0;32m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
# Make .xander directory
[ -d "~/.xander" ] && mkdir "~/.xander"
# Get latest version of Xander
x=($(ls ~/.nimble/pkgs | grep xander-))
y=~/.nimble/pkgs/${x[-1]}/xander.nim
# Compiling with cpp for better compatiblity
echo "Found Xander in $y"
echo -e "${WHITE}Compiling ${x[-1]}${NC}"
~/.nimble/bin/nim cpp --verbosity:1 --hints:off --threads:on -o:~/.xander/xander $y
echo -e "${GREEN}Finished!${NC} The Xander executable can be found in ~/.xander"
echo "Add the following line to ~/.bashrc or ~/.profile:"
echo ""
echo "  export PATH=/home/$USER/.xander:\$PATH"
echo ""