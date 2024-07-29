#!/bin/sh -e

path=$1
from=$2
to=$3

test -z "$path" -o -z "$from" -o -z "$to" && echo "Usage: $0 zfs/backup/host/3 from-mm-dd toyy-mm-dd" && exit 1

host=`echo $path | cut -d/ -f 3- | tr '/' '.'`

sudo zfs diff -FH $path@$from $path@$to | tee /dev/shm/zfs.$host.$from-$to.diff \
| grep -v '	/	' \
| grep -v wp-content/cache \
| grep -v cache/page \
| grep -v wp-content/upgrade/wordpress \
| grep -v wp-content/wflogs \
| grep -v wp-content/upgrade/wordfence \
| grep -v /dokuwiki/data/cache/ \
| sed "s!/$path/*!!" | sort -k 2 | tee /dev/shm/zfs.$host.$from-$to.filter
