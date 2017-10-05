#!/bin/sh

path=$SSH_ORIGINAL_COMMAND
test -z "$path" && exit 1
test -d /$path && zfs snap $path@`date +%Y-%m-%d`

