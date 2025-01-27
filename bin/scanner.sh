#!/bin/bash 

export PATH=~/bin:$PATH

bindir=`readlink -f $0 |xargs -n 1 dirname`
homedir=`readlink -f ~`
user=`whoami`

sigint() {
  exec $0
}

trap 'sigint' INT

doscan="$bindir/scan.sh"
upload="$bindir/upl.sh"
last="$bindir/last.sh"
sound="$bindir/error.wav"

uploadhist=/tmp/uploadhist
scandir=~/Scans

mkdir -p $scandir 2>/dev/null

for f in curl pdftk convert play evince parallel python2; do
  if [ ! -x "`which $f`" ]; then
    echo "You need to install $f."
    exit 1
  fi
done

# if running in WSL on windows, launch Acrobat Reader
iswindows=0
uname -a |grep WSL >/dev/null
if [ $? -eq 0 ]; then
  iswindows=1
  windir=`wslvar USERPROFILE`
  lindir=`wslpath "$(wslvar USERPROFILE)"`
fi

groups |grep scanner >/dev/null
if [ $? -ne 0 ]; then
  echo "Setup error: Add user `whoami` to the scanner group via the command vigr"
  exit 1
fi

if [ ! -f /etc/udev/rules.d/60-libsane.rules ]; then
  echo "Setup error: install 60-libsane.rules to /etc/udev/rules.d and reboot"
  exit 1
fi

loggedin=1

login() {
  echo
  echo 'Your login has expired.'
  while [ $loggedin -ne 1 ]; do
    echo
    echo "Your username is $user"
    read -s -p "Enter your password: " pass
    echo

    curl -k -c ~/.cookies --data "{\"user\":\"$user\",\"pass\":\"$pass\"}" \
      -H "content-type:application/json" \
     https://work.absoluterush.net/auth/ 2>&1 |grep Wrong >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "Bad username/password"
    else
      loggedin=1
      echo
    fi
  done
}

# see if login cookie is still valid.  if not, $last receives:
# Found. Redirecting to /auth/auth.html
if $last |grep auth.html >/dev/null 2>&1; then
  loggedin=0
  login
fi


while true; do
clear
duplex=
echo
echo "Place document on scanner face down."
echo "Press control-c at any time to start over."
echo "Press enter to accept default answers to questions."

action=
while ! echo $action |grep '^[nls]$' >/dev/null; do
  echo
  if [ $user = "jburnett" ]; then
	  echo -n "Upload (N)ew scan or (L)ast viewed PDF or (S)ave scan as PDF?  [default: n] "
  else
	  echo -n "Upload (N)ew scan or (L)ast viewed PDF or (S)ave scan as PDF?  [default: s] "
  fi
  read action
  if [ $user = "jburnett" ]; then
    test -z "$action" && action=n
  else
    test -z "$action" && action=s
  fi
  action=`echo $action |tr '[A-Z]' '[a-z]'`
done
echo $action |grep ^n >/dev/null && action=upload
echo $action |grep ^l >/dev/null && action=existing
echo $action |grep ^s >/dev/null && action=save

if [ $action = "upload" -o $action = "existing" ]; then
  # what'd I look at last?
  l=`$last`
  if echo "$l" |grep auth.html >/dev/null 2>&1; then
    loggedin=0
    login
    l=`$last`
  fi

  type=`echo $l |cut -f1 -d\ `
  id=`echo $l |cut -f2 -d\ `

  echo $id |grep -v [0-9] >/dev/null;
  if [ $? -eq 0 ]; then
    echo "Failed to determine last item viewed.  Exiting."
    exit 1
  fi

  if [ $user = "jburnett" ]; then
  ans=
  while [ -z "$ans" ]; do
    echo -n "Upload a (f)orm, or (l)ast viewed record? [default: l]"
    read ans
    if [ -z "$ans" ]; then
      ans=l
    fi
    if echo $ans |grep -i ^f >/dev/null; then
      type="forms"
      id=1
    fi
  done
  fi

  description=pdf

  if [ $type = "runs" ]; then
    tp=
    tpdef=p

    while ! echo $tp |grep '^[plc]$' >/dev/null; do
      echo
      if [ -f "$uploadhist/pod.$id" -a ! -f "$uploadhist/log.$id" ]; then
        tpdef=l
        echo -n "Is this a (P)OD, (L)og or (C)ontract? [default: p] "
      else
        echo -n "Is this a (P)OD, (L)og or (C)ontract? [default: p] "
      fi
      read tp
      test -z "$tp" && tp=$tpdef
      tp=`echo $tp |tr '[A-Z]' '[a-z]'`
    done
    echo $tp |grep ^p >/dev/null
    if [ $? -eq 0 ]; then
      description=pod
    fi
    echo $tp |grep ^l >/dev/null
    if [ $? -eq 0 ]; then
      description=log
      duplex="-d"
    fi
    echo $tp |grep ^c >/dev/null
    if [ $? -eq 0 ]; then
      description=contract
    fi
  fi


  if [ $type = "employees" -o $type = "vendors" -o $type = "vehicles" -o $type = "customers" -o $type = "forms" -o $type = "tasks" ]; then
    desc=
    while [ -z "$desc" ]; do
      echo -n "What is the name of this attachment? "
      read d
      echo -n "Attachment name is '$d', is that right? "
      read ans
      if echo $ans |grep -i y >/dev/null; then
        desc=$d
      fi
    done
    description=$desc
  fi

  echo
  echo "!!! You're about to upload this scan to '$description' for $type $id !!!"
fi

quick=
if [ $action != "existing" ]; then
  while ! echo "$quick" |grep '^[yn]$' >/dev/null; do
    echo
    if [ $action = "upload" ]; then
      echo -n "Quick Scan (one sided, no overwrite, darkness 3)? [default: y] "
    else
      echo -n "Quick Scan (one sided, darkness 3)? [default: y] "
    fi
    read quick
    test -z "$quick" && quick=y
  done
fi

if [ "$quick" = 'y' ]; then
  flatbed=
  gray=
  bright=3
  overwrite=No
else
  if [ $action = "upload" -o $action = "existing" ]; then
    ow_a=append
    ow_n=No
    ow_y=overwrite

    ow=
    echo
    while ! echo $ow |grep '^[yna]$' > /dev/null; do
      echo -n "Overwrite Existing Scan (Y)es, (N)o, (A)ppend ? [default: n] "
      read ow
      ow=`echo $ow |tr '[A-Z]' '[a-z]'`
      test -z "$ow" && ow=n
    done
    eval overwrite=\$ow_$ow
  fi

  fname=
  if [ $action = "existing" ]; then
    latestpdf="/tmp/_current.pdf"
    if [ $iswindows -eq 1 ]; then
      latestpdf=`ls -Art $lindir/Downloads/*.pdf |tail -1`
    fi
    while [ -z "$fname" -o ! -f "$fname" ]; do
      echo -n "What file would you like to upload? [$latestpdf]"
      read fname
      if [ -z "$fname" ]; then
        fname=$latestpdf
      fi
      if [ ! -z "$fname" -a ! -f "$fname" ]; then
        echo "File does not exist!"
      fi
    done
  fi

  if [ -z "$fname" ]; then
    echo
    g=
    while ! echo $g |grep '^[bg]$' > /dev/null; do
      echo "(B)lack and white or (G)rayscale? "
      echo -n "(Gray ONLY if Black is not readable) [default: b] ? "
      read g
      g=`echo $g |tr '[A-Z]' '[a-z]'`
      test -z "$g" && g=b
    done

    test $g = "g" && gray="-g"

    if [ "$gray" = "-g" -a -f /etc/ImageMagick*/policy.xml ]; then
      echo "WARNING: Grayscale scans may not work while /etc/ImageMagick*/policy.xml exists"
    fi

    echo
    bright=9
    while [ $bright -lt 0 -o $bright -gt 8 ]; do
      echo -n "Scan darkness from 0 (darkest) to 8 (lightest) [default: 3] ? "
      read bright
      test -z "$bright" && bright=3
    done

    echo
    echo -n "Scan both sides of pages on document feeder? [default: n] ? "
    read answer
    test -z "$answer" && answer=n
    duplex=""
    if echo $answer |grep -i y >/dev/null; then
      duplex="-d"
    fi
  fi
fi

rm -f /tmp/scan*.pdf
file=$fname
while [ ! -f "$file" ]; do
  echo
  echo "Scanning document.  Please wait."
  file=`$doscan $flatbed -b $bright $duplex $gray -n $scandir 2>/dev/null`

  if [ ! -f "$file" ]; then
    play -q $sound >/dev/null 2>/dev/null  &
    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Scan failed"
    echo "  Replace on scanner and press enter to try again."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    read foo
#  else

    #cp -f "$file" $homedir/Downloads/upl.pdf
  fi
done

if [ $action = "upload" -o $action = "existing" ]; then
  msg=`$upload $type "$description" $id $overwrite $file 2>/dev/null`
  if echo "$msg" |grep auth.html >/dev/null 2>&1; then
    loggedin=0
    login
    msg=`$upload $type "$description" $id $overwrite $file 2>/dev/null`
  fi

  if echo "$msg" |grep "ok" >/dev/null 2>&1; then
    test ! -d $uploadhist && mkdir /tmp/uploadhist
    touch $uploadhist/$type.$id
  else
    play -q $sound >/dev/null 2>/dev/null  &
    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    if echo "$msg" |grep -i "file exists" >/dev/null 2>&1; then
      echo "Scan completed but upload failed"
      echo "  Upload already exists. Try again"
    else
      echo "Scan completed but upload failed"
      echo "  See Jason"
    fi
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo
  fi

fi

if [ $user = "jburnett" ]; then
  viewer=pdf
else
  viewer=evince
fi

if [ $iswindows -eq 1 ]; then
  viewer="/mnt/c/Program Files/Adobe/Acrobat DC/Acrobat/Acrobat.exe"
fi

fname=`basename $file`
echo

if [ $action != "existing" ]; then
cd /tmp
if [ $iswindows -eq 1 ]; then
  echo "Your scan is saved as $fname in your Downloads folder."
  # copy this file to our Windows downloads directory
  cp -f "$fname" $lindir/Downloads/
  nohup "$viewer" "$windir/Downloads/$fname" 2>/dev/null &
else
  echo "Your scan is saved as $fname in your scans folder."
fi

#nohup "$viewer" "$windir/Downloads/$fname" 2>/dev/null &
fi

echo
echo "Press enter to scan another."
read foo

done
