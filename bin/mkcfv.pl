#!/usr/bin/perl
#
# $Source$
# $Revision$
# $Date$
#
# Makes the Call For Votes post from a template and the group charter
# and outputs to STDOUT. Also creates a group configuration file with
# only one line - the end date (in system time (s))

use Time::Local;

# Info Needed to run the script
my $VoteAddress = "vote\@aus.news-admin.org";
my $HomeDir = "/virt/web/ausadmin";
my $BaseDir = "$HomeDir/vote";
my $default_voteperiod = 21;		# days

my $VotePeriod = $default_voteperiod;

my @newsgroups = ReadCharter();

die "You fool it didn't work can't create a blank one." unless @newsgroups;

foreach my $newsgroup (@newsgroups) {

	die "You fool it didn't work can't create a blank one." unless $newsgroup;

	my $ConfigFile ="$BaseDir/$newsgroup/endtime.cfg";

	if (open(VP, "<$BaseDir/$newsgroup/voteperiod")) {
		$VotePeriod = <VP>;
		chop($VotePeriod);
		close(VP);
	}

	# Find the finish date for votes according to the VD (vote duration)
	$VD = $VotePeriod * 86400;

	# Find the gmt end time
	my($sec,$min,$hour,$mday,$mon,$year) = gmtime(time() + $VD);

	# Extend it to nearly midnight
	($hour,$min,$sec) = (23,59,59);
	my $then = timegm($sec,$min,$hour,$mday,$mon,$year);

	# Now make the human-readable one

	$EndDate = gmtime($then);

	# And write to control file
	open(T, ">$ConfigFile");
	print T $then + 1, "\n";
	close(T);
}

# Opens the template Call For Votes file and constructs the actual CFV file
# which is output to STDOUT
select(STDOUT);
$| = 1;

#preprocess(STDOUT, "$BaseDir/conf/cfvtemplate.header");

die "No distribution" unless $distribution;

my $subject = "CFV: $newsgroups[0]";
if ($newsgroups[1]) {
	$subject = "CFV: $newsgroups[0] and others";
}

print <<"EOHEADERS";
Subject: $subject
From: $VoteAddress
Newsgroups: $distribution
Followup-to: poster

EOHEADERS

if (!open(P, "|pgp -s -f")) {
	print STDERR "Unable to open a pipe to PGP: $!";
	exit(3);
}

if ($moderated{$newsgroups[0]}) {

	print P <<"EOTOPBODY";
                           CALL FOR VOTES
                 Moderated newsgroup $newsgroups[0]

Newsgroups line(s)
EOTOPBODY

} else {

	print P <<"EOTOPBODY";
                           CALL FOR VOTES
                 UnModerated newsgroup $newsgroups[0]

Newsgroups line(s)
EOTOPBODY


}


for my $group (@newsgroups) {
	print P $group," ",$NGLine{$group},"\n";
	local *NGLINE;
	open NGLINE,">$BaseDir/$group/ngline" or die "Unable to open ngline $!";
	print NGLINE "$group, "\t", $NGLine{$group}, "\n";
	close NGLINE or die "Unable to close ngline";
}

print P <<"EOMIDBODY";

Votes must be received by $EndDate

This vote is being conducted by ausadmin. For voting questions contact
ausadmin\@aus.news-admin.org. For questions about the proposed group contact
$Proposer.

EOMIDBODY

foreach my $group (@newsgroups) {
	print P "RATIONALE: $group\n",join "\n",@{$Charter{$group}};
}

print P <<"EOMEND";
HOW TO VOTE

Send E-MAIL to: $VoteAddress
Just Replying should work if you are not reading this on a mailing list.

Your mail message should contain only one of the following statements:
      I vote YES on aus.example.name
      I vote NO on aus.example.name

You must replace aus.example.name with the name of the newsgroup that you are
voting for. If the poll is for multiple newsgroups you should include one vote
for each newsgroup, e.g.

I vote YES on aus.example.name
I vote NO on aus.silly.group
I vote YES on aus.good.group

You may also ABSTAIN in place of YES/NO - this will not affect the outcome.
Anything else may be rejected by the automatic vote counting program.
ausadmin will respond to your received ballots with a personal
acknowledgement by E-mail - if you do not receive one within 24 hours, try
again. It's your responsibility to make sure your vote is registered
correctly.

Only one vote per person, no more than one vote per E-mail address.
Votes from invalid emails may be rejected.  E-mail addresses of all
voters will be published in the final voting results list.


[ Note: CFVs and control messages will be signed with the ausadmin key.
  Download it from http://aus.news-admin.org/ausadmin.asc now!   --nick ]

EOMEND


close(P);

for my $group (@newsgroups) {
	open(CHARTER, ">$BaseDir/$group/charter") or die "Unable to write charter";
	print CHARTER join "\n",@{$Charter{$group}};
	close(CHARTER);
}

# All done

exit(0);


# This sub grabs the required info from the RFD piped into the script.

sub ReadCharter {
     my @groups;

     while ( <> ) {
	  chomp;
	  if ( $_ =~ /^Newsgroup line:/i ) {
GROUP:	       while (<>) {
		    chomp;
		    last GROUP if (/^rationale:.*/i);

		    if (/^([^\s]+)\s+(.*)/i) {
			 push @groups,$1;
			 my $newsgroup=$1;
			 $NGLine{$newsgroup}=$2;
		    } else {
			 last GROUP;
		    }
	       }
	  }

	  if ( $_ =~ /^Moderated:.*/i ) {
	       s/^Moderator:\s*(.*)/$1/i;
	       $moderated{$newsgroup}=1;
	       while (<>) {
		    last if (/^End moderator info/i);
		    push @{$moderator{$newsgroup}},$_;
	       }
	  }


	  if ($_ =~ /^DISTRIBUTION:(.*)/i) {
	       $distribution=$1;
DIST:	       while (<>) {
		    chomp;
		    last DIST if (/^Propo(?:nen?ts?|sers?):.*/i);
		    $distribution .= "$_," if not /^\s*$/;
	       }
	       $distribution =~ s/,$//;
	  }
#                      Propo   nent
	  if ( $_ =~ /^Propo(?:nen?ts?|sers?):/i ) {
	       m/^Propo(?:nen?ts?|sers?):\s*(.*)/i;
	       $Proposer .= "$1," if not /^\s*$/;
PROP:	       while (<>) {
		    chomp;
		    last PROP if (/^/i);
		    $Proposer .= "$_," if not /^\s*$/;
	       }
	  }


	  if (/^rationale:.*/i ) {
	       while ( <> ) {
		    last if (/^END CHARTER/i);
		    chomp;
		    push @{$Charter{$newsgroup}},$_;
	       }
	  }
     }

     $distribution = join ',',
	  grep /^\s*([-\w.]+)\s*$/,
	       split '\s*\,\s*',$distribution;

     return @groups;
}

=pod




#Just commenting this out.
sub preprocess {
	my($fh, $path) = @_;

		     if (!open(TEMPLATE, $path)) {
						       print STDERR "Unable to open $path: $!";
						       return 1;
						  }

			  while ( <TEMPLATE> ) {
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
