#!/bin/bash
#	@(#) $Id$
#
#	Do this stuff once a day

# Make a new mrtg.cfg file for all aus groups
bin/make-mrtg-newsgroups.pl data/ausgroups $AUSADMIN_HOME/config/mrtg.head $AUSADMIN_HOME/Mrtg/news-latest.mrtg > $AUSADMIN_HOME/tmp/$$.cfg
s=$?

if [ $s -eq 0 ] ; then
	mv $AUSADMIN_HOME/tmp/$$.cfg $AUSADMIN_HOME/Mrtg/newsgroups.cfg
else
	rm -f $AUSADMIN_HOME/tmp/$$.cfg
	echo "Unable to create replacement Mrtg/newsgroups.cfg file, code $s"
fi


# Attempt to download new checkgroups from news.admin.hierarchies and update our
# data structures
logrun suck-checkgroups.pl

# Cleanup the logrun directory occasionally
find ~/Logrun/ok -type f -mtime +30 -exec rm {} \;
find ~/Logrun/bad -type f -mtime +90 -exec rm {} \;
find ~/Logrun -type f -mtime +120 -exec rm {} \;
