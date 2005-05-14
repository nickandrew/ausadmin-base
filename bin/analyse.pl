#!/usr/bin/perl
#	@(#) analyse.pl - Produce a slow, bulky analysis of common
#	characteristics of votes received for a newsgroup.

=head1 NAME

analyse.pl - Analyse vote messages to find patterns

=head1 SYNOPSIS

analyse.pl vote-name

=head1 DESCRIPTION

This program performs a very slow and thorough analysis of the votes
received for the specified vote.

=cut

use Getopt::Std;
use lib 'perllib';
use Message;
use Vote;

use vars qw($opt_d);

getopts('d');

my $votename = shift @ARGV;

# Make sure this vote exists
my $v = new Vote(name => $votename);

# First of all, grab all the messages for this vote
my $tally_ref = $v->get_message_paths();

foreach my $r (@$tally_ref) {
	my $m = new Message();
	$m->parse_file($r->{path});
	$r->{message} = $m;
}

# Now find some interesting facts about these messages...

# Go through every message
foreach my $r (@$tally_ref) {
	my $m = $r->{message};

	my $id_lr = ids_of($m);
}

exit(0);

=pod

ids_of($message) ...

Find the interesting identifiers (e.g. IP address) related to a message

=cut

sub ids_of {
	my $message = shift;
}

