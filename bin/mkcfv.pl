#!/usr/bin/perl

# Makes the Call For Votes post from a template and the group charter
# and outputs to STDOUT. Also created a group configuration file with
# only one line - the end date (in system time (s))

# Info Needed to run the script
$VoteAddress = "vote\@aus.news-admin.org";
$HomeDir = "/virt/web/ausadmin";
$BaseDir = "$HomeDir/vote";

ReadCharter();

for my $newsgroup (@newsgroup) {
  
}
$ConfigFile ="$BaseDir/$Newsgroup/group.cfg";
chop($VotePeriod = `cat $BaseDir/$Newsgroup/voteperiod`);

# Find the finish date for votes according to the VD (vote duration)
$VD = $VotePeriod * 86400;

($day, $mon, $mday, $time, $year) = split /\s+/, gmtime( time + $VD );
$EndDate = "$day, $mday $mon $year 00:00:00 GMT";
system ( "date --date '$day $mon $mday 00:00:00 GMT $year' +%s > $ConfigFile" );

$ExpireDate = "$day, $mday $mon $year 00:00:00 GMT";

# This sub grabs the required info from the group charter piped into the
# script.

sub ReadCharter {
  $CNoL = 0;
  while ( <STDIN> ) {
    chomp;
    if ( $_ =~ /^Newsgroup:.*/i ) {
      s/^Newsgroup:\s*(.*)/$1/i;
      push @Newsgroup,$_;
      $newsgroup=$_;
    }
    if ( $_ =~ /^Line:.*/i ) {
      s/^Line:\s*(.*)/$1/i;
      $NGLine{$newsgroup}=$_;
    }

    if ( $_ =~ /^Moderated:.*/i ) {
      s/^Moderator:\s*(.*)/$1/i;
      $Moderated{$newsgroup}=1;
      while (<STDIN>) {
	last if (/^End moderator info/i);
      push @{$Moderator{$newsgroup}},$_;
      }

    }
    if ( $_ =~ /^Proposer:.*/i ) {
      s/^Proposer:\s*(.*)/$1/i;
      $Proposer=$_;
    }

    if ( $_ =~ /^rationale:.*/i ) {
      while ( <STDIN> ) {
	last if (/^END CHARTER/i);		 
	chomp;
	push @{$Charter{$newsgroup}},$_;
      }
    }

    if ($_ =~ /DISTRIBUTION:(.*)/) {
      $distrabution=$1;
    }
  }
}

=pod
#Just commenting this out.
sub preprocess {
	my($fh, $path) = @_;

	if (!open(TEMPLATE, $path)) {
		print STDERR "Unable to open $path: $!";
		return 1;
	}

	while( <TEMPLATE> ) {
		chomp;
		if ( $_ =~ /.*!CHARTER!/ ) {
			for ( $i=0; $i<=$CNoL; $i++ ) {	
				print $fh "$Charter[$i]\n";
			}
		}
		elsif ( $_ =~ /.*![^!]+!/ ) {
			s/!GROUPNAME!/$Newsgroup/g;
			s/!GROUPLINE!/$NGLine/g;
			s/!PROPOSER!/$Proposer/g;
			s/!VOTEADDRESS!/$VoteAddress/g;
			s/!MODERATED!/$Moderated/g;
			s/!DATE!/$EndDate/g;
			s/!EXPIRES!/$ExpireDate/g;
			print $fh "$_\n";
		}
		else {
			print $fh "$_\n";
		}
	}

	close(TEMPLATE);
	return 0;
}

=cut

# Opens the template Call For Votes file and constructs the actual CFV file
# which is output to STDOUT
select(STDOUT);
$| = 1;

#preprocess(STDOUT, "$BaseDir/conf/cfvtemplate.header");

print <<"EOHEADERS";
Subject: CFV: $Newsgroup[0]
From: ausadmin@aus.news-admin.org
Newsgroup: $distrabution

EOHEADERS

if (!open(P, "|pgp -s -f")) {
	print STDERR "Unable to open a pipe to PGP: $!";
	exit(3);
}

print P <<"EOTOPBODY";
                           CALL FOR VOTES
                 $moderated{$topnewsgroup} $topnewsgroup

Newsgroups line(s)
EOBODY

for my $group (@Newsgroup) {
  print P $NGLine{$group},"\n";
}

print P <<"EOMIDBODY";

Votes must be received by $ExpireDate

This vote is being conducted by ausadmin. For voting questions contact 
ausadmin\@aus.news-admin.org. For questions about the proposed group contact 
$Proposer.

EOMIDBODY

for my $group (@Newsgroup) {
  print P "RATIONALE: $group\n",join '\n',@{$Charter{$newsgroup}};
}

print P <<'EOMEND';
HOW TO VOTE

Send E-MAIL to: vote@aus.news-admin.org
Just Replying should work if you are not reading this on a mailing list.

Your mail message should contain only one of the following statements:
      I vote YES on aus.computers.java
      I vote NO on aus.computers.java

You may also ABSTAIN in place of YES/NO - this will not affect the outcome.
Anything else may be rejected by the automatic vote counting program.  
ausadmin will respond to your received ballots with a personal
acknowledgement by mail - if you do not receive one within 24hrs, try
again. It\'s your responsibility to make sure your vote is registered
correctly.

Only one vote per person, no more than one vote per E-mail address.
Addresses of all voters will be published in the final voting results list.

[ Note: CFVs and control messages will be signed with the ausadmin key.
  Download it from http://aus.news-admin.org/ausadmin.asc now!   --nick ]
EOMEND

close(P);

