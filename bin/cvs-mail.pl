#!/usr/bin/perl -w

use strict;

# Usage: cvs-mail.pl filename

# Proccesses incoming mail for ausadmin adding

# X-PTS-Account: ausadmin
# X-PTS-Status: open
# X-PTS-Handled: dformosa

my $ttsid = 'zz-pts@staff.zeta.org.au';
my $admin = 'dformosa@zeta.org.au';
my $from  = 'ausadmin@zeta.org.au';

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
print "X-PTS-Handled: dformosa\n";

print "\n";

while (<>) {
  print;
}

close MAIL or die "Can't open sendmail $! please report this to $admin";
