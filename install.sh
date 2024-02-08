#!/bin/sh

sudo apt -y update
sudo apt -y upgrade
sudo apt -y install pdftk imagemagick python2 parallel sox libleptonica-dev

cd
mkdir bin 2>/dev/null
git clone https://github.com/groovy9/scanner
cd scanner
sudo cp -f 60-libsane.rules /etc/udev/rules.d
cd ~/bin
ln -s ~/scanner/bin/scanner.sh 

echo
echo
echo "Linux will now shut itself down.  Afterward, start it back up with the 'Ubuntu' application in the Windows start menu."
echo
echo

echo -n "Press enter to continue"
read foo
cmd.exe /C wsl --shutdown
