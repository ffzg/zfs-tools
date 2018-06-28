#!/bin/sh -xe

patt=$1
test -z "$patt" && echo "Usage: $0 grep-pattern" && exit 1

echo "# grep $patt"
sudo grep $patt /var/log/rsyncd.log-* | sed -e 's/\[[0-9\.]*\] //g' -e 's/ [^ ]*.ffzg.hr backup () / /g'


