#!/bin/bash

cd "$(dirname "$0")" || exit 1

find . -iname "*.bak" -delete
chmod 664 *.pld
#rmxattr.sh *.pld

for i in *.pld; do
  echo "$i:"
  chmod 664 "$i"
  rmxattr.sh "$i"
  sed -e 's/[ 	]*\/\/.*$//g' "$i" | sed -re ':loop; /\\$/N; s/\\\n//g; tloop' - > "$i".p
  galette "$i".p && rm -f "$i".p
done
