#!/bin/sh

bindir=`readlink -f $0 |xargs -n 1 dirname`
pdfone="$bindir/pdfone.sh"
dir=$1
outfile=$2

# kill any pdfpar processes that are already running
if [ -f /tmp/pdfpar.pid ]; then
  kill `cat /tmp/pdfpar.pid` >/dev/null 2>&1
fi
echo $$ > /tmp/pdfpar.pid

test ! -d "$dir" && exit 1

cd $dir
i=1
while [ $i -eq 1 ]; do
  test -f end && i=0
  ls *.pnm 2>/dev/null | parallel -j+0 --no-notice $pdfone 2>/dev/null
  test $i -eq 1 && sleep .2
done

pdftk out*.pdf cat output $outfile 2>/dev/null
rm end /tmp/pdfpar.pid
