#!/bin/bash
#	Run from cron each 5 minutes

DATADIR=~/data/aus.data

ts=`date '+%Y%m%d%H%M%S'`
mrtg-newsgroups $DATADIR/checkgroups $DATADIR/mrtg-newsgroups-config.xml ~/tmp/mrtg-newsgroups-arrival.log > ~/tmp/news-$ts.mrtg 2> tmp/missing-groups
s=$?

if [ $s -eq 0 ] ; then
	echo 0 > $DATADIR/ng-fail-count
	mv ~/tmp/news-$ts.mrtg ~/Mrtg/news-latest.mrtg
	mrtg ~/Mrtg/newsgroups.cfg
else
	NG_FAIL=$(cat $DATADIR/ng-fail-count)
	NG_FAIL=$(expr $NG_FAIL + 1)
	if [ $NG_FAIL -gt 20 ] ; then
		echo Unable to connect to newsserver - $NG_FAIL times | mail -s error nick@tull.net
		NG_FAIL=0
	fi
	echo $NG_FAIL > $DATADIR/ng-fail-count
	rm -f ~/tmp/news-$ts.mrtg
fi

bin/mrtg-newsgroups-arrival.pl > ~/Mrtg/arrival/news-latest.mrtg
mrtg ~/Mrtg/arrival/newsgroups.cfg

exit 0
