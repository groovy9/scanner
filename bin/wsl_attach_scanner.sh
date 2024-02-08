#!/bin/sh

# this requires a the tool usbipd to be installed on the windows host:
# https://github.com/dorssel/usbipd-win/releases
# install the msi file on the latest release of that page

# find the attached fujitsu scanner
scanner_busid=`cmd.exe /C usbipd list 2>/dev/null |grep 04c5 |cut -f1 -d\ `

# attach it to this WSL instance
cmd.exe /C usbipd attach --wsl --busid ${scanner_busid} 2>/dev/null
