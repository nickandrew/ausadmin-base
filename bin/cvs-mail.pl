#!/usr/bin/perl -w
#
# $Source$
# $Revision$
# $Date$
#
# Usage: cvs-mail.pl filename
#
# Proccesses incoming mail for ausadmin adding
# X-PTS-Account: ausadmin
# X-PTS-Status: open
# X-PTS-Assigned: nick

use strict;

my $ttsid = 'zz-pts@staff.zeta.org.au';
my $admin = 'nick-ausadmin@tull.net';
my $from  = 'ausadmin@aus.news-admin.org';

open (MAIL,'|/usr/sbin/sendmail $ttsid') or 
  die "Can't fork sendmail $! please report this to $admin";

#Set MAIL as the defult output for print;

select MAIL;

while (<>) {
  last if /^$/;
  s/To: .*/To: $ttsid/;
  print;
}

print "X-PTS-Account: ausadmin\n";
print "X-PTS-Status: open\n";
print "X-PTS-Assigned: nick\n";

print "\n";

while (<>) {
  print;
}

close MAIL or die "Can't open sendmail $! please report this to $admin";
