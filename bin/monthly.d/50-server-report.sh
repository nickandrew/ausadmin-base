#!/bin/bash

cd $HOME

yyyymmdd=$(date '+%Y%m%d')

server-report.pl > server-report.txt

ci -l "-mUpdated $yyyymmdd" server-report.txt
post.pl < server-report.txt
