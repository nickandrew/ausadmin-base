#!/usr/bin/perl
#	@(#) collater.pl - Record incoming votes
#
# $Source$
# $Revision$
# $Date$
#
# Processes any incoming votes from incoming.pl
# 1. Checks whether the newsgroup is valid
# 2. Checks to see whether user has already voted
# 3. Otherwise adds vote
# 4. Sends an acknowledgment

=head1 NAME

collater.pl - Record (or reject) incoming votes

=head1 SYNOPSIS

This program is called by B<bin/incoming> and should never be run
directly.

=head1 DESCRIPTION

This program reads on its standard input, a sanitised set of votes
in the format:

	userid@domain newsgroup YES|NO|ABSTAIN time filename

Each vote is compared against the vote directory for the stated
newsgroup and accepted or rejected according to the voting status
of that newsgroup.

=cut

use FileHandle;
use Fcntl qw(:flock);

my $HomeDir = "/virt/web/ausadmin";
my $BaseDir = "$HomeDir/vote";

while ( <STDIN> ) {
	chomp;
	my($EmailAddress, $Newsgroup, $Vote, $CTime, $fn) = split;

	if ($Newsgroup !~ /^[a-z0-9+-]+\.[a-z0-9+-]+(\.[a-z0-9+-]+)*$/) {
		FailVote($EmailAddress, "Invalid newsgroup name (must be of the format aus.whatever, in lower case");
		next;
	}

	my $ng_dir = "$BaseDir/$Newsgroup";

	eval {
		# Use die to get our error message out ASAP
		die "Invalid newsgroup $Newsgroup" if (!-d $ng_dir);
		die "A vote for $Newsgroup has not (yet) started" if (!-f "$ng_dir/vote_start.cfg");
		die "The vote for $Newsgroup has been cancelled" if (-f "$ng_dir/vote_cancel.cfg");
	};

	if ($@) {
		FailVote($EmailAddress, $@);
		next;
	}

	# Section 1 (see above)
	if ( open( CONFIGFILE, "$BaseDir/$Newsgroup/endtime.cfg" ) ) {
		chomp( $_ = <CONFIGFILE> );
		my $VoteTime = $_;
		close( CONFIGFILE );
		if ($CTime > $VoteTime) {
			FailVote($EmailAddress, "$Newsgroup vote ended" );
			next;
		}
	} else {
		FailVote($EmailAddress, "invalid newsgroup $Newsgroup" );
		next;
	}

	# Section 2 (see above)
	if ( open( TALLYFILE, "$BaseDir/$Newsgroup/tally.dat" ) ) {
		my $found = 0;

		while( <TALLYFILE> ) {
			chomp;
			my($EA, $NG, $V, $CT, $FN) = split;
			if ( $EmailAddress eq $EA ) {
				$found = 1;
				last;
			}
		}
		close( TALLYFILE );

		if ($found) {
			FailVote($EmailAddress, "already voted on $Newsgroup" );
			next;
		}
	}

	# Section 3 (see above)
	if ( open( TALLYFILE, ">>$BaseDir/$Newsgroup/tally.dat" ) ) {
		flock(TALLYFILE, LOCK_EX);
		print TALLYFILE "$EmailAddress $Newsgroup $Vote $CTime $fn\n";
		close(TALLYFILE);
	} else {
		die "Collater failed (couldn't open/create tally file)";
	}
	AckVote($EmailAddress, $Vote, $Newsgroup);	
}
# End of main loop


# This sub returns a message (using sendmail) to say the vote failed
sub FailVote {
	my $EmailAddress = shift;

	$ENV{'MAILHOST'}="aus.news-admin.org";
	if ( open ( MAILPIPE, "|/usr/sbin/sendmail $EmailAddress ausadmin\@aus.news-admin.org" ) ) {
		print MAILPIPE "From: ausadmin\@aus.news-admin.org (aus Newsgroup Administration)\n";
		print MAILPIPE "To: $EmailAddress,ausadmin\@aus.news-admin.org\n";
		print MAILPIPE "Subject: Vote Failed ($_[0])\n";
		print MAILPIPE "X-Automated-Reply: this message was sent by an auto-reply program\n\n";

		if ( open ( ERRORMSG, "$HomeDir/config/votefail.msg" ) ) {
			while ( <ERRORMSG> ) {
				chomp;
				print MAILPIPE "$_\n";
			}
			close( ERRORMSG );
		} else {
			print MAILPIPE "Your vote failed, but I couldn't open my error message file\n";
			print MAILPIPE "so please contact ausadmin\@aus.news-admin.org for assistance.\n";
			print STDERR "Couldn't open votefail.msg!";
		}

		close( MAILPIPE );
	} else {
		die "MAILPIPE failed";
	}
	print STDERR "Collater failed ($_[0])";
	exit(0);
}

# This sub returns a message (using sendmail) to say the vote was accepted
sub AckVote {
	my $EmailAddress = shift;
	my $Vote = shift;
	my $Newsgroup = shift;

	$ENV{'MAILHOST'}="aus.news-admin.org";
	if ( open ( MAILPIPE, "|/usr/sbin/sendmail $EmailAddress" ) ) {
		print MAILPIPE "From: ausadmin\@aus.news-admin.org (aus Newsgroup Administration)\n";
		print MAILPIPE "To: $EmailAddress\n";
		print MAILPIPE "Subject: Vote accepted for $Newsgroup\n";
		print MAILPIPE "X-Automated-Reply: this message was sent by an auto-reply program\n";
		
		printf MAILPIPE "
This is an automatic message sent to you after your vote has been counted.
If this is correct, there is no need for you to reply. 

	Newsgroup                                         Vote
	---------					  ----
	%-50s $Vote

This is a public vote, and all addresses and votes will be listed in the 
final voting results.

For a copy of the Call For Votes (CFV) email cfv\@aus.news-admin.org 
indicating the newsgroup in the subject line.

If you have a problem please contact <ausadmin\@aus.news-admin.org>. ", $Newsgroup;

		close( MAILPIPE );
	} else {
		die "MAILPIPE failed";
	}
}
