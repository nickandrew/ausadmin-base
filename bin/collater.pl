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

Accepted votes are appended to the B<tally.dat> file in the vote
directory in the format:

	userid@domain newsgroup YES|NO|ABSTAIN time

=cut

use FileHandle;
use IO::File;
use Fcntl qw(:flock);

my $BaseDir = "./vote";

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
		# Because it's a string we have to end it with \n else perl
		# will add "at bin/collater.pl line nn" automatically (urk)

		die "Invalid newsgroup $Newsgroup\n" if (!-d $ng_dir);
		die "A vote for $Newsgroup has not (yet) started\n" if (!-f "$ng_dir/vote_start.cfg");
		die "The vote for $Newsgroup has been cancelled\n" if (-f "$ng_dir/vote_cancel.cfg");
	};

	if ($@) {
		my $msg = $@;
		chomp $msg;
		FailVote($EmailAddress, $msg);
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
	my $tf = new IO::File("$BaseDir/$Newsgroup/tally.dat", O_WRONLY|O_APPEND|O_CREAT, 0640);
	die "Collater failed (couldn't create/append tally file: $!" if (!defined $tf);
	flock($tf, LOCK_EX);
	$tf->print("$EmailAddress $Newsgroup $Vote $CTime $fn\n");
	if (!$tf->close()) {
		die "Error writing to tally file for $Newsgroup";
	}

	AckVote($EmailAddress, $Vote, $Newsgroup, $CTime);	
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

		if ( open ( ERRORMSG, "config/votefail.msg" ) ) {
			while ( <ERRORMSG> ) {
				chomp;
				print MAILPIPE "$_\n";
			}
			close( ERRORMSG );
		} else {
			print MAILPIPE "Your vote failed, but I couldn't open my error message file\n";
			print MAILPIPE "so please contact ausadmin\@aus.news-admin.org for assistance.\n";
			print STDERR "Couldn't open votefail.msg!\n";
		}

		close( MAILPIPE );
	} else {
		die "MAILPIPE failed";
	}

	print STDERR "Collater failed ($_[0])\n";
	exit(0);
}

# This sub returns a message (using sendmail) to say the vote was accepted
sub AckVote {
	my $EmailAddress = shift;
	my $Vote = shift;
	my $Newsgroup = shift;
	my $vote_id = shift;

	$ENV{MAILHOST} = "aus.news-admin.org";
	$ENV{QMAILUSER} = "vote-return-$vote_id";

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

This is a public vote, and all voting e-mail addresses will be listed
in the final voting results.

For a copy of the Call For Votes (CFV) go to:

	http://aus.news-admin.org/cgi-bin/voteinfo?newsgroup=$Newsgroup

If you have a problem please contact <ausadmin\@aus.news-admin.org>. ", $Newsgroup;

		close( MAILPIPE );
	} else {
		die "MAILPIPE failed";
	}
}
