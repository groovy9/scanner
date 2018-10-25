#!/bin/sh -x

bindir=`readlink -f $0 |xargs -n 1 dirname`

contrast=75
brightness=0
duplex=0
dir=/tmp
brightness=0
b=-1
gray=0
scanimage="$bindir/scanimage"
pdfpar="$bindir/pdfpar.sh"

type=`cat ~/.scannertype`
if [ -z "$type" ]; then
  # Jason's scanner is a model Fi-7160
  type=fi7160

  # everyone else has a Scanscap iX500
  if $scanimage -L |grep -i scansnap >/dev/null; then
    type=scansnap
  fi
  echo $type > ~/.scannertype
fi

while getopts "fdb:n:g" opt; do
  case $opt in
    d) duplex=1 ;;
    b) b=$OPTARG ;;
    n) dir=$OPTARG ;;
    g) gray=1 ;;
  esac
done

test ! -d $dir && dir=/tmp
test ! -w $dir && dir=/tmp

test $b -eq 0 && brightness=-100
test $b -eq 1 && brightness=-75
test $b -eq 2 && brightness=-50
test $b -eq 3 && brightness=-25
test $b -eq 4 && brightness=0
test $b -eq 5 && brightness=25
test $b -eq 6 && brightness=50
test $b -eq 7 && brightness=75
test $b -eq 8 && brightness=100

mkdir /tmp/scan$$
cd /tmp/scan$$

if [ $gray -eq 1 -a -f /etc/ImageMagick*/policy.xml ];then
  echo "WARNING: Grayscale scans may not work while /etc/ImageMagick*/policy.xml exists"
fi

res=300

source="ADF Front"
if [ $duplex -eq 1 ]; then
  source="ADF Duplex"
fi

if [ $gray -eq 0 ]; then
  if [ $type = "scansnap" ]; then
    mode=Lineart
  else
    mode=Halftone
  fi
  # start the pnm -> pdf mashing process, which will keep running until we're
  # done scanning pages.  It loops looking for pnms until it sees the 'end'
  # file, which we create after scanning is done.
  $pdfpar /tmp/scan$$ $dir/scan$$.pdf &
else
  mode=Gray
fi

# scan what's on the ADF
$scanimage -d fujitsu --mode $mode --resolution $res --source "$source" \
          --batch=out%03d.pnm --brightness $brightness \
          --contrast $contrast >/dev/null 2>&1

if [ $? -ne 0 ]; then
  touch "/tmp/scan$$/end"
  exit 1
fi

if [ $gray -eq 0 ]; then
  # signal pdfpar that scanning is done
  touch "/tmp/scan$$/end"

  # wait for pdfpar to finish
  while [ -f "/tmp/scan$$/end" ]; do
    sleep .1
  done
else
  convert *.pnm -density $res -set units PixelsPerInch $dir/scan$$.pdf
fi

rm -rf /tmp/scan$$
echo $dir/scan$$.pdf
