#!/usr/bin/perl

# Processes any incoming mail
# 1. Grabs the email address (read the From: line and pipes to getaddr.pl)
# 2. Grabs group out of subject - otherwise fail
# 3. Grabs vote from body - otherwise fail
# 4. Assign timestamp (time)
# 5. output to STDOUT

$HomeDir = "/virt/web/ausadmin";
$BaseDir = "$HomeDir/vote";

# Section 1 and 2 (see above)
S1: while ( <STDIN> ) {
	chomp;
	if ( $_ =~ /^From:.*/ ) {
		s/^From:(.*)/$1/;
		$EmailAddress = GetAddr( $_ );
	}
	elsif ( $_ =~ /^Subject:.*/ ) {
		s/^Subject:\s*(.*)/$1/;
		if ( $_ =~ /aus.*/ ) {
			s/.*(aus[^\s]*).*/$1/;
			$Newsgroup = $_;
		}
		else {
			FailVote( "no newsgroup" );
		}
	}
	if ( ($EmailAddress ne "") && ($Newsgroup ne "") ) {
		last S1;
	}
}


# Section 3 (see above)
S3: while ( <STDIN> ) {
	chomp;
	if ( $_ =~ /I vote [^\s]* on $Newsgroup.*/i ) {
		s/I vote ([^\s]*).*/$1/i;
		$Vote = $_;
		last S3;
	}
}
if ($Vote eq "") {
	FailVote ( "no votes" );
}
elsif ( ($Vote !~ /^yes$/i) & ($Vote !~ /^no$/i) & ($Vote !~ /^abstain$/i) ) {
	FailVote ( "invalid vote" );
}

$CTime = time;
# Output Results
print "$EmailAddress $Newsgroup $Vote $CTime $ARGV[0]\n";

# This sub returns a message (using sendmail) to say the vote failed
sub FailVote {
	$ENV{'MAILHOST'}="aus.news-admin.org";
	if ( open ( MAILPIPE, "|/usr/sbin/sendmail $EmailAddress" ) ) {
		print MAILPIPE "From: ausadmin\@aus.news-admin.org (aus Newsgroup Administration)\n";
		print MAILPIPE "To: $EmailAddress\n";
		print MAILPIPE "Subject: Vote Failed ($_[0])\n";
		print MAILPIPE "X-Automated-Reply: this message was sent by an auto-reply program\n";

		if ( open ( ERRORMSG, "$BaseDir/conf/parsefail.msg" ) ) {
			while ( <ERRORMSG> ) {
				chomp;
				print MAILPIPE "$_\n";
			}
			close( ERRORMSG );
		}
		else {
			die "Couldn't open parsefail.msg!";
		}

		close( MAILPIPE );
	}
	else {
		die "MAILPIPE failed";
	}
	die "Parser failed ($_[0])";
}


# This sub returns the email address out of a "from" field
sub GetAddr {

	$Address = $_[0];

	# This bit removes any unwanted parts from the email address
	if ( $Address =~ /<.*>/ ) {
		$Address =~ s/.*<([^>]+)>.*/$1/;
	}
	elsif ( $Address =~ /\(.*\)/ ) {
		# remove multiple occurances of ( ) style comments
		$Address =~ s/\([^\)]+\)/$1/g;

		# remove all unwanted spaces leaving just one
		$Address =~ s/\s*([^\s]+)\s*/$1 /g;

		# if more than one space then more than one reply address
		if ( $Address =~ /\s([^\s]+)\s/g ) {
			$Address =~ s/^([^\s]+).*/$1/;
			print "$Address\n";
			die "ERROR More than one reply-to address";
		}

		# Now remove trailing spaces
		$Address =~ s/([^\s]+)\s*/$1/;
	}
	else {
		# Remove any leading or traling spaces
		$Address =~ s/\s*([^\s]+).*/$1/;
	}	

	return $Address;
}
