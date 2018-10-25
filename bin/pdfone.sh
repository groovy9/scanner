#!/bin/sh

bindir=`readlink -f $0 |xargs -n 1 dirname`
jbig2="$bindir/jbig2"
pdfpy="$bindir/pdf.py"

test -f "$1.pdf" && exit
mv "$1" ".$1"
cp ".$1" ".$1.orig"
$jbig2 -p -b "$1" -s ".$1" >/dev/null 2>&1
$pdfpy "$1" > $$.pdf
rm "$1".0* "$1".sym ".$1"
mv $$.pdf "$1.pdf"
