#!/bin/bash
#
#	Do this stuff once a day

# Make a new mrtg.cfg file for all aus groups
bin/make-mrtg-newsgroups.pl data/ausgroups $AUSADMIN_HOME/data/config.head $AUSADMIN_HOME/Mrtg/news-latest.mrtg > $AUSADMIN_HOME/tmp/$$.cfg
s=$?

if [ $s -eq 0 ] ; then
	mv $AUSADMIN_HOME/tmp/$$.cfg $AUSADMIN_HOME/Mrtg/newsgroups.cfg
else
	rm -f $AUSADMIN_HOME/tmp/$$.cfg
	echo "Unable to create replacement Mrtg/newsgroups.cfg file, code $s"
fi

