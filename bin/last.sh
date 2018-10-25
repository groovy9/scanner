#!/bin/sh


curl -s -k -b ~/.cookies https://work.absoluterush.net/mylast |sed -e 's/\"//g'
