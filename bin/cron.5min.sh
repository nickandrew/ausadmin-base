#!/bin/bash
#	Run from cron each 5 minutes

HIER=${1:-aus}

DATADIR=~/data/$HIER.data

ts=`date '+%Y%m%d%H%M%S'`
TEMPFILE="$HOME/tmp/news-$ts.mrtg"
FAILCOUNT_FILE="$DATADIR/server-fail-count"

# Create a file in my 5-line mrtg format containing the highwater article
# numbers for each newsgroup in this hierarchy.

mrtg-newsgroups $DATADIR/checkgroups $DATADIR/mrtg-newsgroups-config.xml $DATADIR/mrtg-newsgroups-arrival-$HIER.log > $TEMPFILE 2> $DATADIR/missing-groups
s=$?

if [ $s -ne 0 ] ; then
	# Count how many successive failures talking to the server
	# Alert every 20 failures
	NG_FAIL=$(cat $FAILCOUNT_FILE)
	NG_FAIL=$(expr $NG_FAIL + 1)
	if [ $NG_FAIL -gt 20 ] ; then
		echo Unable to connect to newsserver - $NG_FAIL times | mail -s error nick@tull.net
		NG_FAIL=0
	fi
	echo $NG_FAIL > $FAILCOUNT_FILE
	rm -f $TEMPFILE
	exit 8
fi

# Success code path

echo 0 > $FAILCOUNT_FILE
mv $TEMPFILE ~/Mrtg/news-latest-$HIER.mrtg
#mrtg ~/Mrtg/newsgroups.cfg

# Create another file in my 5-line format containing the
# arrival rate for new articles (avg per 2 hours and per 24)

~/bin/mrtg-newsgroups-arrival.pl -f $DATADIR/mrtg-newsgroups-arrival-$HIER.log > ~/Mrtg/arrival/news-latest-$HIER.mrtg

mrtg ~/Mrtg/arrival/newsgroups-$HIER.cfg

exit 0
