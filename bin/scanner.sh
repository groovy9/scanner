#!/bin/bash

export PATH=/home/jburnett/bin:$PATH

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

faxhist=~/.faxes
uploadhist=/tmp/uploadhist
scandir=~/Scans

mkdir -p $scandir 2>/dev/null

for f in curl pdftk convert play evince; do
  if [ ! -x "`which $f`" ]; then
    echo "You need to install $f.  Exiting in 10 seconds."
    sleep 10
    exit 1
  fi
done

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
echo
echo "Place document on scanner face down."
echo "Press control-c at any time to start over."
echo "Press enter to accept default answers to questions."

action=
while ! echo $action |grep '^[ufse]$' >/dev/null; do
  echo
  if [ $user = "jburnett" ]; then
    echo -n "(U)pload scan or (E)xisting, (F)ax, or (S)ave?  [default: u] "
  else
    echo -n "(U)pload scan or (E)xisting, (F)ax, or (S)ave?  [default: s] "
  fi
  read action
  if [ $user = "jburnett" ]; then
    test -z "$action" && action=u
  else
    test -z "$action" && action=s
  fi
  action=`echo $action |tr '[A-Z]' '[a-z]'`
done
echo $action |grep ^u >/dev/null && action=upload
echo $action |grep ^e >/dev/null && action=existing
echo $action |grep ^f >/dev/null && action=fax
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
    tpdef=c
    if [ $user = "jburnett" ]; then
      tpdef=p
    fi

    while ! echo $tp |grep '^[plc]$' >/dev/null; do
      echo
      if [ -f "$uploadhist/pod.$id" -a ! -f "$uploadhist/log.$id" ]; then
        tpdef=l
        if [ $user = "jburnett" ]; then
          echo -n "Is this a (P)OD, (L)og or (C)ontract? [default: p] "
        else
          echo -n "Is this a (P)OD, (L)og or (C)ontract? [default: c] "
        fi
      else
        if [ $user = "jburnett" ]; then
          echo -n "Is this a (P)OD, (L)og or (C)ontract? [default: p] "
        else
          echo -n "Is this a (P)OD, (L)og or (C)ontract? [default: c] "
        fi
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

if [ $action = "fax" ]; then
  go=1
  while [ $go -eq 1 ]; do
    faxnum=
    while ! echo "$faxnum" |grep '^[1-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]$' >/dev/null; do
      echo
      echo -n "Fax# (xxx-xxx-xxxx) or enter for previous entries: "
      read faxnum
      test -z "$faxnum" && faxnum=999-999-9999
    done
    if [ $faxnum = "999-999-9999" ]; then
      if [ ! -f $faxhist ]; then
        echo "Absolute Rush|zzz|615-301-6531" > $faxhist
      fi
      echo
      n=1
      while read line; do
        company=`echo $line |cut -f1 -d\| |sed -e 's/zzz//'`
        attention=`echo $line |cut -f2 -d\| |sed -e 's/zzz//'`
        faxnum=`echo $line |cut -f3 -d\|`
        eval choice_$n=\$line
        echo "[$n] $company $attention $faxnum" |sed -e 's/\ \ */ /g'
        n=`expr $n + 1`
      done < $faxhist
      echo
      f=0
      while [ $f -lt 1 -o $f -ge $n ]; do
        echo -n "Enter number of fax history entry: "
        read f
      done
      eval choice=\$choice_$f
      company=`echo $choice |cut -f1 -d\| |sed -e 's/zzz//'`
      attention=`echo $choice |cut -f2 -d\| |sed -e 's/zzz//'`
      faxnum=`echo $choice |cut -f3 -d\|`
    else
      company=
      echo -n "Company: "
      read company

      attention=
      echo -n "Attention: "
      read attention
    fi

    conf="Fax to"
    test ! -z "$company" && conf="$conf $company"
    test ! -z "$attention" && conf="$conf $attention"
    conf="$conf $faxnum"

    echo -n "$conf.  Correct? [default: y] "
    read ans
    test -z "$ans" && ans=y
    echo $ans |grep -i ^y >/dev/null && go=0
  done

  test -z "$choice" && echo "$company|$attention|$faxnum" |sed -e 's/^|/zzz|/' -e 's/||/|zzz|/' >> $faxhist
  sort $faxhist | uniq > $faxhist.new
  mv $faxhist.new $faxhist

  if [ $user = "bparsley" ]; then
    from="Bill Parsley"
  fi
  if [ $user = "jburnett" ]; then
    from="Jason Burnett"
  fi
  if [ $user = "jventers" ]; then
    from="John Venters"
  fi
  if [ $user = "lochoa" ]; then
    from="Lindsey Ochoa"
  fi
  faxnum=`echo $faxnum |sed -e 's/-//g'`
  faxnum=1$faxnum
  if [ ! -z "$company" -a ! -z "$attention" ]; then
    to="$attention @ $company"
  else
    to="$attention $company"
  fi
  echo "From: Absolute Rush Delivery <$user@absoluterush.net>" > /tmp/fax.$$
  echo "To: $to <$faxnum@maxemailsend.com>" >> /tmp/fax.$$
  echo "Subject: {fine}" >> /tmp/fax.$$
  echo " " >> /tmp/fax.$$
  echo "Sent by $from (615-252-3774)" >> /tmp/fax.$$
  echo >> /tmp/fax.$$
fi

quick=
if [ $action != "existing" ]; then
  while ! echo "$quick" |grep '^[yn]$' >/dev/null; do
    echo
    if [ $action = "upload" ]; then
      echo -n "Quick Scan (one sided, no overwrite, darkness 4)? [default: y] "
    else
      echo -n "Quick Scan (one sided, darkness 4)? [default: y] "
    fi
    read quick
    test -z "$quick" && quick=y
  done
fi

if [ "$quick" = 'y' ]; then
  flatbed=
  duplex=
  gray=
  bright=4
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
    while [ -z "$fname" -o ! -f "$fname" ]; do
      echo -n "What file would you like to upload? [$homedir/Downloads/upl.pdf]"
      read fname
      if [ -z "$fname" ]; then
        fname="$homedir/Downloads/upl.pdf"
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
      echo -n "Scan darkness from 0 (darkest) to 8 (lightest) [default: 5] ? "
      read bright
      test -z "$bright" && bright=4
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
    play -q $sound &
    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Scan failed"
    echo "  Replace on scanner and press enter to try again."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    read foo
  else
    cp -f "$file" $homedir/Downloads/upl.pdf
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
    play -q $sound &
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

if [ $action = "fax" ]; then
  #fax it
  mail -a $file -t < /tmp/fax.$$ && echo "Fax successfully sent."
fi
fname=`basename $file`
echo
echo "Your scan is saved as $fname in your scans folder."
$viewer $file

echo
echo "Press enter to scan another."
read foo

done
