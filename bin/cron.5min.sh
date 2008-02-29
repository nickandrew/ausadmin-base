#!/bin/bash
#	Run from cron each 5 minutes

HIER=${1:-aus}

DATADIR=~/data/$HIER.data

ts=`date '+%Y%m%d%H%M%S'`
mrtg-newsgroups $DATADIR/checkgroups $DATADIR/mrtg-newsgroups-config.xml $DATADIR/mrtg-newsgroups-arrival-$HIER.log > $DATADIR/news-$ts.mrtg 2> $DATADIR/missing-groups
s=$?

if [ $s -ne 0 ] ; then
	NG_FAIL=$(cat $DATADIR/ng-fail-count)
	NG_FAIL=$(expr $NG_FAIL + 1)
	if [ $NG_FAIL -gt 20 ] ; then
		echo Unable to connect to newsserver - $NG_FAIL times | mail -s error nick@tull.net
		NG_FAIL=0
	fi
	echo $NG_FAIL > $DATADIR/ng-fail-count
	rm -f ~/tmp/news-$ts.mrtg
	exit 8
fi

# Success code path

echo 0 > $DATADIR/ng-fail-count
mv $DATADIR/news-$ts.mrtg ~/Mrtg/news-latest-$HIER.mrtg
#mrtg ~/Mrtg/newsgroups.cfg

~/bin/mrtg-newsgroups-arrival.pl -f $DATADIR/mrtg-newsgroups-arrival-$HIER.log > ~/Mrtg/arrival/news-latest-$HIER.mrtg

mrtg ~/Mrtg/arrival/newsgroups-$HIER.cfg

exit 0
