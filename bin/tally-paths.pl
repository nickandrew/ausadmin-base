#!/usr/bin/perl
#	@(#) tally-paths.pl - Output (to STDOUT) a list of the paths in a
#	vote's tally.dat file

=head1 NAME

tally-paths.pl - Output (to STDOUT) a list of the paths in a
vote's tally.dat file

=head1 SYNOPSIS

tally-paths.pl 'email-regex' 'vote-regex' 'choice-regex' 'status-regex' < tally-pathname

=head1 DESCRIPTION

This program reads the tally contents (from stdin) and does the equivalent
of a 3-regex grep, emitting only the pathnames of those votes which match.

For example:

  tally-paths.pl '' '' 'no' '' < vote/aus.sport.pro-wrestling/tally.dat

will output (one to a line) the paths of all messages which registered
a NO vote.

Regexs are case-insensitive, and are not bound to the front or back of the
string. In other words, use ^ and $ if you want to bind your search.

=cut

my $email_regex = shift @ARGV;
my $vote_regex = shift @ARGV;
my $choice_regex = shift @ARGV;
my $status_regex = shift @ARGV;

my @path_list;

# Read the tally contents for this vote on stdin

while (<STDIN>) {
	chomp;
	my($email,$vote,$choice,$ts,$path,$status) = split(/\s/);
	next if ($path eq '');

	next if ($email_regex ne '' && $email !~ /$email_regex/oi);
	next if ($vote_regex ne '' && $vote !~ /$vote_regex/oi);
	next if ($choice_regex ne '' && $choice !~ /$choice_regex/oi);
	next if ($status_regex ne '' && $status !~ /$status_regex/oi);

	if (!-f $path) {
		print STDERR "tally-paths.pl: $path not found!\n";
		next;
	}

	push(@path_list, $path);
}

foreach (@path_list) {
	print $_, "\n";
}

exit(0);
