#!/usr/bin/perl
#	@(#) incoming.pl - parse a message
#
# $Source$
# $Revision$
# $Date$
#
# Usage: incoming.pl filename | collater.pl
#
# Processes any incoming mail
# 1. Read in the message header and obtain the return email address
#    - otherwise die. Each vote needs a return email address.
# 2. Grabs vote and group from body - otherwise fail
# 3. Assign timestamp (time)
# 4. output to STDOUT

my $message_path = shift @ARGV;

my $HomeDir = "/home/ausadmin";
my $BaseDir = "$HomeDir/vote";


# Section 1 and 2 (see above)
# Read in headers

my $EmailAddress;

if (!open(M, "<$message_path")) {
	die "Unable to open $message_path for input ...!";
}

while ( <M> ) {
	if ( $_ eq "\n" ) {
		last;
	}
	chomp;
	if ( ($_ =~ /^From:.*/) && ($EmailAddress eq "") ) {
		s/^From:(.*)/$1/;
		$EmailAddress = GetAddr( $_ );
	}
	elsif ( $_ =~ /^reply-to:.*/i ) {
		s/^reply-to:(.*)/$1/i;
		$EmailAddress = GetAddr( $_ );
	}
}
if ( $EmailAddress eq "" ) {
	die "NO RETURN EMAIL ADDRESS SUPPLIED IN HEADER";
}

my %vote;

# Section 2 (see above)
while ( <M> ) {
	chomp;
	if ( /I vote (\S+) (on|to|for) ([a-z0-9+.-]+)/i ) {
		$vote{$3} = $1;
	}
}

close(M);

if (not keys %vote) {
	FailVote ( "no votes" );
}

for (keys %vote) {
	if ($vote{$_} =~ /^yes$/i) {
		$vote{$_} = 'YES';
		next;
	}
	if ($vote{$_} =~ /^no$/i) {
		$vote{$_} = 'NO';
		next;
	}
	if ($vote{$_} =~ /^abstain$/i) {
		$vote{$_} = 'ABSTAIN';
		next;
	}

	# Otherwise ...
	FailVote ( "invalid vote" );
}

# Section 3 (see above)
my $ts = time();

# Output Results - Section 4 (see above)

for (keys %vote) {
	print "$EmailAddress $_ ", $vote{$_}, " $ts $message_path\n";
}

exit(0);

# This sub returns a message (using sendmail) to say the vote failed
sub FailVote {

	$ENV{'MAILHOST'}="aus.news-admin.org";

	if ( open ( MAILPIPE, "|/usr/sbin/sendmail $EmailAddress" ) ) {
		print MAILPIPE "From: ausadmin\@aus.news-admin.org (aus Newsgroup Administration)\n";
		print MAILPIPE "To: $EmailAddress\n";
		print MAILPIPE "Subject: Vote Failed ($_[0])\n";
		print MAILPIPE "X-Automated-Reply: this message was sent by an auto-reply program\n";

		if ( open ( ERRORMSG, "$HomeDir/config/parsefail.msg" ) ) {
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

	my $address = $_[0];

	# This bit removes any unwanted parts from the email address
	if ( $address =~ /<.*>/ ) {
		$address =~ s/.*<([^>]+)>.*/$1/;
	}
	elsif ( $address =~ /\(.*\)/ ) {
		# remove multiple occurances of ( ) style comments
		$address =~ s/\([^\)]+\)/$1/g;

		# remove all unwanted spaces leaving just one
		$address =~ s/\s*([^\s]+)\s*/$1 /g;

		# if more than one space then more than one reply address
		if ( $address =~ /\s([^\s]+)\s/g ) {
			$address =~ s/^([^\s]+).*/$1/;
			print "$address\n";
			die "ERROR More than one reply-to address";
		}

		# Now remove trailing spaces
		$address =~ s/([^\s]+)\s*/$1/;
	} else {
		# Remove any leading or traling spaces
		$address =~ s/\s*([^\s]+).*/$1/;
	}

	return lc($address);
}
