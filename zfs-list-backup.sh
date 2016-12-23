#!/bin/sh -xe

zfs list -o name,written,compressratio -t snapshot -r lib15/backup
