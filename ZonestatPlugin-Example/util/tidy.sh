#!/bin/sh
#
# $Id: tidy.sh 765 2009-05-20 07:18:40Z calle $

TIDYRC=util/perltidyrc

find . -name contrib -prune -o \( -name '*.pl' -o -name '*.pm' -o -name '*.t' \) -print |\
xargs perltidy --profile=${TIDYRC} --backup-and-modify-in-place
find . \( -name '*.pl.bak' -o -name '*.pm.bak' -o -name '*.t.bak' \) -type f -print |\
xargs rm
