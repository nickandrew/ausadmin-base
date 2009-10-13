#!/bin/bash
#	@(#) $Id$
#
#	Do this stuff once a day

cd $AUSADMIN_HOME

HIER=${1:-aus}
DATADIR=data/$HIER.data

# Make a new mrtg.cfg file for all aus groups
make-mrtg-newsgroups.pl $DATADIR/checkgroups $DATADIR/mrtg.head $AUSADMIN_HOME/Mrtg/news-latest-$HIER.mrtg > $AUSADMIN_HOME/tmp/$$.cfg
s=$?

if [ $s -eq 0 ] ; then
	mv $AUSADMIN_HOME/tmp/$$.cfg $AUSADMIN_HOME/Mrtg/newsgroups-$HIER.cfg
else
	rm -f $AUSADMIN_HOME/tmp/$$.cfg
	echo "Unable to create replacement Mrtg/newsgroups.cfg file, code $s"
fi

bin/make-mrtg-newsgroups-arrival.pl $DATADIR/checkgroups $AUSADMIN_HOME/config/mrtg-arrival.head $AUSADMIN_HOME/Mrtg/arrival/news-latest-$HIER.mrtg > Mrtg/arrival/newsgroups-$HIER.cfg

# Attempt to download new checkgroups from news.admin.hierarchies and update our
# data structures
logrun suck-checkgroups.pl

# Cleanup the logrun directory occasionally
find ~/Logrun/ok -type f -mtime +30 -exec rm {} \;
find ~/Logrun/bad -type f -mtime +90 -exec rm {} \;
find ~/Logrun -type f -mtime +121 -exec rm {} \;
