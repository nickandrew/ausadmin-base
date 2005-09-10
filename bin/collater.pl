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

This program is called by B<incoming> and should never be run
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

	userid@domain newsgroup YES|NO|ABSTAIN time pathname NEW

=cut


use FileHandle;
use IO::File;
use Fcntl qw(:flock);

use VoterState qw();

my $basedir = "./vote";
my $vs = new VoterState();

while ( <STDIN> ) {
	chomp;
	my($emailaddress, $newsgroup, $Vote, $ts, $fn) = split;

	if ($newsgroup !~ /^[a-z0-9+-]+\.[a-z0-9+-]+(\.[a-z0-9+-]+)*$/) {
		FailVote($emailaddress, "Invalid newsgroup name (must be of the format aus.whatever, in lower case)");
		next;
	}

	my $vr = $vs->getCheckRef($emailaddress);
	my $check_id = $vr->{check_id};

	my $ng_dir = "$basedir/$newsgroup";

	eval {
		# Use die to get our error message out ASAP
		# Because it's a string we have to end it with \n else perl
		# will add "at collater.pl line nn" automatically (urk)

		die "Invalid newsgroup $newsgroup\n" if (!-d $ng_dir);
		die "A vote for $newsgroup has not (yet) started\n" if (!-f "$ng_dir/vote_start.cfg");
		die "The vote for $newsgroup has been cancelled\n" if (-f "$ng_dir/vote_cancel.cfg");
	};

	if ($@) {
		my $msg = $@;
		chomp $msg;
		FailVote($emailaddress, $msg);
		next;
	}

	# Section 1 (see above)
	if ( open( CONFIGFILE, "$basedir/$newsgroup/endtime.cfg" ) ) {
		chomp( $_ = <CONFIGFILE> );
		my $VoteTime = $_;
		close( CONFIGFILE );
		if ($ts > $VoteTime) {
			FailVote($emailaddress, "$newsgroup vote ended" );
			next;
		}
	} else {
		FailVote($emailaddress, "invalid newsgroup $newsgroup" );
		next;
	}

	# Section 2 (see above)
	if ( open( TALLYFILE, "$basedir/$newsgroup/tally.dat" ) ) {
		my $found = 0;

		while( <TALLYFILE> ) {
			chomp;
			my($EA, $NG, $V, $CT, $FN) = split;
			if ( $emailaddress eq $EA ) {
				$found = 1;
				last;
			}
		}
		close( TALLYFILE );

		if ($found) {
			FailVote($emailaddress, "already voted on $newsgroup" );
			next;
		}
	}

	# Section 3 (see above)
	my $tf = new IO::File("$basedir/$newsgroup/tally.dat", O_WRONLY|O_APPEND|O_CREAT, 0640);
	die "Collater failed (couldn't create/append tally file: $!" if (!defined $tf);
	flock($tf, LOCK_EX);
	$tf->print("$emailaddress $newsgroup $Vote $ts $fn NEW\n");
	if (!$tf->close()) {
		die "Error writing to tally file for $newsgroup";
	}

	AckVote($emailaddress, $Vote, $newsgroup, $check_id);	
}

$vs->save();

exit(0);

# This sub returns a message (using sendmail) to say the vote failed
sub FailVote {
	my $emailaddress = shift;

	$ENV{'MAILHOST'}="aus.news-admin.org";
	if ( open ( MAILPIPE, "|/usr/sbin/sendmail $emailaddress ausadmin\@aus.news-admin.org" ) ) {
		print MAILPIPE "From: ausadmin\@aus.news-admin.org (aus Newsgroup Administration)\n";
		print MAILPIPE "To: $emailaddress,ausadmin\@aus.news-admin.org\n";
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
}

# This sub returns a message (using sendmail) to say the vote was accepted
sub AckVote {
	my $emailaddress = shift;
	my $Vote = shift;
	my $newsgroup = shift;
	my $check_id = shift;

	$ENV{MAILHOST} = "aus.news-admin.org";
	$ENV{QMAILUSER} = "vote-return-$check_id";

	if ( open ( MAILPIPE, "|/usr/sbin/sendmail $emailaddress" ) ) {
		print MAILPIPE "From: ausadmin\@aus.news-admin.org (aus Newsgroup Administration)\n";
		print MAILPIPE "To: $emailaddress\n";
		print MAILPIPE "Subject: Vote accepted for $newsgroup\n";
		print MAILPIPE "X-Automated-Reply: this message was sent by an auto-reply program\n";
		
		print MAILPIPE "
This is an automatic message sent to you after your vote has been counted.
If this is correct, there is no need for you to reply.\n";

		printf MAILPIPE "\t%-50s %s\n", "Newsgroup", "Vote";
		printf MAILPIPE "\t%-50s %s\n", "---------", "----";
		printf MAILPIPE "\t%-50s %s\n", $newsgroup, $Vote;

		print MAILPIPE "

This is a public vote, and all voting e-mail addresses will be listed
in the final voting results.

For a copy of the Call For Votes (CFV) go to:

	http://aus.news-admin.org/cgi-bin/voteinfo?newsgroup=$newsgroup

If you have a problem please contact <ausadmin\@aus.news-admin.org>.\n";

		close( MAILPIPE );
	} else {
		die "MAILPIPE failed";
	}
}
