#!/bin/bash
#	@(#) $Id$
#
#	Do this stuff once a day

cd $AUSADMIN_HOME

# Make a new mrtg.cfg file for all aus groups
make-mrtg-newsgroups.pl data/checkgroups $AUSADMIN_HOME/config/mrtg.head $AUSADMIN_HOME/Mrtg/news-latest.mrtg > $AUSADMIN_HOME/tmp/$$.cfg
s=$?

if [ $s -eq 0 ] ; then
	mv $AUSADMIN_HOME/tmp/$$.cfg $AUSADMIN_HOME/Mrtg/newsgroups.cfg
else
	rm -f $AUSADMIN_HOME/tmp/$$.cfg
	echo "Unable to create replacement Mrtg/newsgroups.cfg file, code $s"
fi

bin/make-mrtg-newsgroups-arrival.pl data/checkgroups $AUSADMIN_HOME/config/mrtg-arrival.head $AUSADMIN_HOME/Mrtg/arrival/news-latest.mrtg > Mrtg/arrival/newsgroups.cfg

# Attempt to download new checkgroups from news.admin.hierarchies and update our
# data structures
logrun suck-checkgroups.pl

# Cleanup the logrun directory occasionally
find ~/Logrun/ok -type f -mtime +30 -exec rm {} \;
find ~/Logrun/bad -type f -mtime +90 -exec rm {} \;
find ~/Logrun -type f -mtime +120 -exec rm {} \;
