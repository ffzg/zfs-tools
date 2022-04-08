#!/bin/sh -x

rsync -ravHXA --numeric-ids --sparse --delete $*
