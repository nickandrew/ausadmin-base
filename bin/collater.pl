#!/usr/bin/perl

use FileHandle;

# Processes any incoming votes from incoming.pl
# 1. Checks whether the newsgroup is valid
# 2. Checks to see whether user has already voted
# 3. Otherwise adds vote
# 4. Sends an acknowledgment

$LOCK_SH = 1;
$LOCK_EX = 2;
$LOCK_UN = 8;

$HomeDir = "/virt/web/ausadmin";
$BaseDir = "$HomeDir/vote";

while ( <STDIN> ) {
	($EmailAddress, $Newsgroup, $Vote, $CTime, $fn) = split;

	# Section 1 (see above)
	if ( open( CONFIGFILE, "$BaseDir/$Newsgroup/group.cfg" ) ) {
		chomp( $_ = <CONFIGFILE> );
		$VoteTime = $_;
		close( CONFIGFILE );
		if ($CTime > $VoteTime) {
			FailVote( "$Newsgroup vote ended" );
		}
	}
	else {
		FailVote( "invalid newsgroup" );
	}

	# Section 2 (see above)
	if ( open( TALLYFILE, "$BaseDir/$Newsgroup/tally.dat" ) ) {
		while( <TALLYFILE> ) {
			chomp;
			($EA, $NG, $V, $CT, $FN) = split;
			if ( $EmailAddress eq $EA ) {
				FailVote( "already voted on $Newsgroup" );
			}
		}
		close( TALLYFILE );
	}

	# Section 3 (see above)
	if ( open( TALLYFILE, ">>$BaseDir/$Newsgroup/tally.dat" ) ) {
		flock( TALLYFILE, $LOCK_EX );
		print TALLYFILE "$EmailAddress $Newsgroup $Vote $CTime $fn\n";
		close( TALLYFILE );
	}
	else {
		die "Collater failed (couldn't open/create tally file)";
	}
	AckVote();	
}
# End of main loop


# This sub returns a message (using sendmail) to say the vote failed
sub FailVote {
	$ENV{'MAILHOST'}="aus.news-admin.org";
	if ( open ( MAILPIPE, "|/usr/sbin/sendmail $EmailAddress" ) ) {
		print MAILPIPE "From: ausadmin\@aus.news-admin.org (aus Newsgroup Administration)\n";
		print MAILPIPE "To: $EmailAddress\n";
		print MAILPIPE "Subject: Vote Failed ($_[0])\n";
		print MAILPIPE "X-Automated-Reply: this message was sent by an auto-reply program\n";

		if ( open ( ERRORMSG, "$BaseDir/conf/votefail.msg" ) ) {
			while ( <ERRORMSG> ) {
				chomp;
				print MAILPIPE "$_\n";
			}
			close( ERRORMSG );
		}
		else {
			die "Couldn't open votefail.msg!";
		}

		close( MAILPIPE );
	}
	else {
		die "MAILPIPE failed";
	}
	die "Collater failed ($_[0])";
}

# This sub returns a message (using sendmail) to say the vote was accepted
sub AckVote {
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

If you have a problem please contact the aus Newsgroup 
Administrator Nick Andrew <ausadmin\@aus.news-admin.org>. ", $Newsgroup;

		close( MAILPIPE );
	}
	else {
		die "MAILPIPE failed";
	}
}
