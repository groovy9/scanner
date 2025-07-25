@echo off

goto ENDCOMMENT

Dear future IT guy,

This is the Absolute Rush Delivery scanner intall/launch tool.  ARD uses a scanning tool that was originally 
written for the Linux terminal.  It's an old-looking text based menu interface but requires very few key 
strokes and integrates with the ARD web application so that it knows what the user is looking at, scans 
what's on the scanner into a highly compressed PDF, uploads it to ARD attached to whatever the user 
is looking at, saves it in the Windows Documents folder and opens in it your PDF reader.  Usually, you just 
put paper in the feeder and press enter a few times and it does the rest.

It runs on MS Windows via the Windows subsystem for Linux.  This script takes care of installing 
everything it needs the first time you run it and from then on, it just launches the scanner tool
inside the Linux virtual machine.  There should be no prerequisites to install first.

Save this script to a user's Documents directory, then right-click it, choose new -> shortcut,
and a new shortcut file will be created in the same directory.  Right-click the new shortcut and
rename it to "ARD scanner tool". Move the shortcut (not this bat file) to the Desktop or toolbar 
and double-click it to run it.

It depends on a tool which is automatically installed by this script called usbipd 
found here: https://github.com/dorssel/usbipd-win ...  It's responsible for passing the scanner USB device 
through to the Linux environment.

For problems or with or changes to the scanning script itself, see ~/scanner/bin/scanner.sh inside 
the Linux install.  They're all plain old Linux shell scripts. 

scanner.sh is the main menu program and depends on several other scripts found in the same directory.

:ENDCOMMENT

echo.
echo This may take a few seconds...
echo.
SETLOCAL EnableDelayedExpansion
TITLE ARD Scanner Tool
set linuxname=ARD_Linux

rem first, make sure usbipd is installed.  It's our only prerequisite outside the Linux environment.
:USBIPD
where usbipd >nul
if ERRORLEVEL 1 (
	cls
	echo ###########################################################################################################
	echo.
	echo The ARD scanner tool requires one bit of software called usbipd which
	echo can be found here: https://github.com/dorssel/usbipd-win/releases/download/v5.1.0/usbipd-win_5.1.0_x64.msi
	echo.
	echo I'll try to download and install it now, just press enter.  If anything goes wrong, download it and install it
	echo manually from https://github.com/dorssel/usbipd-win and then press enter here.
	echo.
	pause
	curl -fLso %tmp%\usbipd.msi https://github.com/dorssel/usbipd-win/releases/download/v5.1.0/usbipd-win_5.1.0_x64.msi
	if ERRORLEVEL 1 (
		echo.
		echo Failed to download usbipd from https://github.com/dorssel/usbipd-win/releases/download/v5.1.0/usbipd-win_5.1.0_x64.msi
		echo.
		echo Try downloading a release from https://github.com/dorssel/usbipd-win, install it, and then 
		echo press enter here. Version 5.x would be the safest bet since that's what was last tested here.
		echo.
		pause
	)
	
	msiexec /i "%tmp%\usbipd.msi" /passive
	if ERRORLEVEL 1 (
		echo.
		echo Failed to install usbipd.  
		echo.
		echo Try downloading a release from https://github.com/dorssel/usbipd-win, install it, and then 
		echo press enter here to continue. Version 5.x would be the safest bet since that's what was 
		echo last tested here.
		echo.
		pause
	)

	set "PATH=%PATH%;C:\Program Files\usbipd-win"
	where usbipd >nul
	if ERRORLEVEL 1 (
		echo.
		echo Could not find usbipd command after attempting to install it.  Trying again.
		echo.
		timeout /t 5
		goto USBIPD
	)
)
	
rem see if we need to elevate to admin. It's required to run the command 'usbipd bind'
usbipd list |findstr "Attached forced" >nul
if ERRORLEVEL 1 (
	rem elevate to administrator privileges
	net sess>nul 2>&1||(echo(CreateObject("Shell.Application"^).ShellExecute"%~0",,,"RunAs",1:CreateObject("Scripting.FileSystemObject"^).DeleteFile(wsh.ScriptFullName^)>"%temp%\%~nx0.vbs"&start wscript.exe "%temp%\%~nx0.vbs"&exit)
)

:TOP
rem first, see if Ubuntu has been installed
rem next line is needed so the wsl | findstr thing works below
set WSL_UTF8=1
wsl --list |findstr %linuxname% >nul
if ERRORLEVEL 1 (
	echo.
	echo After you press enter, I'll install the Linux environment for the scanner tools to
	echo run inside.  Some text will pass by and when it prompts for you for a username, use the same
	echo username you log into ARD with. 
	echo.
	echo It will also ask for a password.  You won't need it so just press x twice.
	echo.
	echo When you see some colored text and a flashing cursor, type the word exit and press enter.  

	echo Ready?  Press enter now.
	echo.
	pause
	wsl --install -d Ubuntu-24.04 --name %linuxname%
	if ERRORLEVEL 1 (
		echo Failed to install Linux.  See Jason.
		pause
		goto TOP
	)
) 
set WSL_UTF8=0 :: set this back to default or errors get thrown later

rem now see if the scanner tools bundle has been installed inside Linux

rem load a kernel module needed by usbipd below
wsl -d %linuxname% --user root modprobe vhci-hcd
:MOUNT
rem a bug can happen, the following prevents it per https://github.com/dorssel/usbipd-win/issues/856
wsl -d %linuxname% --user root mkdir -p /var/run/usbipd-win ^&^& mount |findstr usbipd >nul
if ERRORLEVEL 1 (
	wsl -d %linuxname% --user root mount -t drvfs -o "ro,umask=222" "C:\Program Files\usbipd-win\WSL" "/var/run/usbipd-win"
	goto MOUNT
)

rem make it so scanner starts when we log in
wsl -d %linuxname% grep scanner ~/.bashrc ^>/dev/null ^|^| echo ~/bin/scanner ^>^> ~/.bashrc

:SOFTWAREINSTALL
wsl -d %linuxname% ls ~/bin/scanner 2^>/dev/null| findstr scanner >nul
if ERRORLEVEL 1 (
	rem what's our linux username?
	for /f %%i in ('wsl -d %linuxname% whoami') do ( set user=%%i )

	rem what's our home directory?
	for /f %%i in ('wsl -d %linuxname% echo $HOME') do ( set home="%%i" )
	
	echo.
	echo Press enter to install scanner software bundle onto the new Linux environment.  
	echo A bunch of text will stream by for a few minutes.  Just wait.
	echo.
	pause
	
	rem in the 'apt -y install' line below, the packages from pdftk to wslu are those required
	rem for the scanner software to work.  The next two lines from build-essential to libffi-dev
	rem are build tools used to compile python2, which we need but it reached end of life and was
	rem removed from ubuntu.
	set log=/var/log/ARD_install.log
	wsl -d %linuxname% --user root ^( ^
				set -x ^&^& ^
				echo APT UPDATE---------------------------------------------------------------------------- ^&^& ^
				apt -y update ^&^& ^
				echo APT UPGRADE--------------------------------------------------------------------------- ^&^& ^
		 		apt -y upgrade ^&^& ^
				echo APT INSTALL--------------------------------------------------------------------------- ^&^& ^
				apt -y install pdftk imagemagick parallel sox libleptonica-dev evince sane-utils wslu ^
					build-essential checkinstall libncursesw5-dev libssl-dev libsqlite3-dev tk-dev usbutils ^
					libgdbm-dev libc6-dev libbz2-dev libffi-dev ^&^& ^
				echo INSTALL PYTHON------------------------------------------------------------------------ ^&^& ^
				cd !home! ^&^& ^
				wget https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz ^&^& ^
				tar -xvf Python-2.7.18.tgz ^&^& ^
				cd Python-2.7.18 ^&^& ^
				./configure --enable-optimizations ^&^& ^
				make install ^&^& ^
				python -V ^&^& ^
				cd !home! ^&^& ^
				rm -rf Python-2.7.18 ^&^& ^
				echo INSTALL SCANNER TOOL----------------------------------------------------------------- ^&^& ^
				rm -rf scanner bin ^&^& ^
				mkdir -p bin ^&^& ^
				git clone https://github.com/groovy9/scanner ^&^& ^
				chown -R !user! scanner bin ^&^& ^
				cd scanner ^&^& ^
				cp -f 60-libsane.rules /etc/udev/rules.d ^&^& ^
				cd !home! ^&^& cd bin ^&^& ^
				ln -s ../scanner/bin/scanner.sh scanner ^&^& ^
				usermod -G scanner !user! ^
			^) 2^>^&1 ^|tee -a /var/log/ARD_install.log

	if ERRORLEVEL 1 (
		echo.
		echo Install failed.  Talk to Jason.  The install log file is at /var/log/ARD_install.log
		echo.
		pause
		goto SOFTWAREINSTALL
	)
)

:FINDSCANNER
rem     find busid of Fujitsu scanner device.  Fujitsu has reserved "04c5" in VID field of the
rem     the output of USBIPD.  it should look something like this:
rem     BUSID  VID:PID    DEVICE                                                        STATE
rem     3-4    04c5:132e  Unknown device                                                Not shared
set scannerbusid=""
for /f %%i in ('usbipd list ^|findstr 04c5') do (
  set scannerbusid=%%i
)
if %scannerbusid% == "" (
  echo.
  echo No Fujitsu scanner found.  Unplug it from USB, turn it off then back on, reconnect it to USB, and press enter
  echo.
  pause
  goto FINDSCANNER
)

rem make sure Linux hasn't gone away
wsl -d %linuxname% uptime >nul

:BINDSCANNER
rem    make sure the scanner has already been "bound" via the usbipd command
rem    first, see if wsit's already attached
usbipd list |findstr 04c5 | findstr Attached >nul
if ERRORLEVEL 1 (
        rem not attached.  see if it's at least correctly bound
	usbipd list |findstr 04c5 | findstr forced >nul
	if ERRORLEVEL 1 (
		rem not correcly bound.  bind it with --force so any programs that are using
		rem it don't prevent the binding
		usbipd bind --force -b %scannerbusid% >nul
		if ERRORLEVEL 1 (
			echo.
			echo Failed to bind the scanner USB device.  See Jason.
			echo.
			pause
			goto FINDSCANNER
		)

	)

	rem now that it's bound, attach it to the Linux environment
	usbipd attach -w -b %scannerbusid% >nul
	if ERRORLEVEL 1 (
	  echo.
	  echo Failed to attach scanner to Linux environment.  See Jason. After he fixes the problem, press enter.
	  echo.
	  pause
	  goto FINDSCANNER
	)
) 

rem jump straight into the scanner tool inside Linux
start "ARD Scanner Tool" cmd.exe /k wsl -d %linuxname% 
exit
