#!/usr/bin/perl

# Makes the Call For Votes post from a template and the group charter
# and outputs to STDOUT. Also created a group configuration file with
# only one line - the end date (in system time (s))

$Newsgroup = $ARGV[0];

# Info Needed to run the script
$VoteAddress = "vote\@aus.news-admin.org";
$HomeDir = "/virt/web/ausadmin";
$BaseDir = "$HomeDir/vote";
$ConfigFile ="$BaseDir/$Newsgroup/conf/group.cfg";
chop($VotePeriod =`cat $BaseDir/$Newsgroup/conf/voteperiod`);

# Find the finish date for votes according to the VD (vote duration)
# Currently set to 21days
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
			$Newsgroup = $_;
		}
		if ( $_ =~ /^Line:.*/i ) {
			s/^Line:\s*(.*)/$1/i;
			$NGLine = $_;
		}
		if ( $_ =~ /^Moderated:.*/i ) {
			s/^Moderated:\s*(.*)/$1/i;
			$Moderated = $_;
		}
		if ( $_ =~ /^Proposer:.*/i ) {
			s/^Proposer:\s*(.*)/$1/i;
			$Proposer = $_;
		}
		if ( $_ =~ /^Charter:.*/i ) {
			while ( <STDIN> ) {
				chomp;
				$Charter[$CNoL] = $_;
				$CNoL++;
			}
		}
	}
}

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

ReadCharter();

# Opens the template Call For Votes file and constructs the actual CFV file
# which is output to STDOUT
select(STDOUT);
$| = 1;

preprocess(STDOUT, "$BaseDir/conf/cfvtemplate.header");

if (!open(P, "|pgp -s -f")) {
	print STDERR "Unable to open a pipe to PGP: $!";
	exit(3);
}

preprocess(P, "$BaseDir/conf/cfvtemplate.body");
close(P);

