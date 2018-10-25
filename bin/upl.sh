#!/bin/sh

tbl=$1
description=$2
tblid=$3
overwrite=$4
file=$5

if ! echo $tbl |grep '^[a-z][a-z]*$' >/dev/null; then
  exit 1
fi

if ! echo $tblid |grep '^[1-9][0-9]*$' >/dev/null; then
  exit 1
fi

if [ ! -f "$file" ]; then
  exit 1
fi

curl -k -b ~/.cookies -F "filename=@$file" -F "tbl=$tbl" -F "tblid=$tblid" -F "which=$description" -F "overwrite=$overwrite" https://work.absoluterush.net/upload

