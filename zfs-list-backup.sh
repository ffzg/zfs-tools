#!/bin/sh -xe

grep="cat"
test ! -z "$1" && grep="grep $*"

sudo zfs list -o name,logicalreferenced,written,compressratio -t snapshot -r lib15/backup lib15/diskrsync | $grep
