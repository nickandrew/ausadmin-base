#!/usr/bin/perl
#	@(#) incoming.pl
# $Revision$
# $Date$

# Processes any incoming mail
# 1. Read in the message header and obtain the return email address 
#    - otherwise die. Each vote needs a return email address.
# 2. Grabs vote and group from body - otherwise fail
# 3. Assign timestamp (time)
# 4. output to STDOUT


$HomeDir = "/virt/web/ausadmin";
$BaseDir = "$HomeDir/vote";


# Section 1 and 2 (see above)
# Read in headers
S1: while ( <STDIN> ) {
	if ( $_ eq "\n" ) {
		last S1;
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
S2: while ( <STDIN> ) {
	chomp;
	if ( $_ =~ /^I vote [^\s]* (on|to|for) aus.*/i ) {
		/^I vote ([^\s]*).*(aus[.a-z0-9]*).*/i;
		$vote{$2} = $1;
#		last S2;
	}
}

if (not keys %vote) {
	FailVote ( "no votes" );
}

for (values %vote) {
  if (not (/^yes$/i or /^no$/i or /^abstain$/i)) {
    FailVote ( "invalid vote" );
  }	
}

# Section 3 (see above)
$CTime = time;

# Output Results - Section 4 (see above)

for (keys %vote) {
  print "$EmailAddress $_ ",$vote{$_}," $CTime $ARGV[0]\n";
}


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
