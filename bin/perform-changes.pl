#!/usr/bin/perl

use lib 'bin';

use Vote;
use Newsgroup;

my $vote = shift @ARGV || usage();

my $v = new Vote(name => $vote);
my $change_lr = $v->read_file('change');

# Process the changes a paragraph at a time

my @change_list;
my $hr = { };

foreach (@$change_lr) {
	chomp;
	if (/^$/) {
		if (%$hr) {
			push(@change_list, $hr);
			$hr = { };
		}
		next;
	} 

	# Otherwise ...
	my($k,$v) = ($_ =~ /^([^:]+):\s+(.*)/);
	if ($k ne '') {
		$hr->{$k} = $v;
	}
}

if (%$hr) {
	push(@change_list, $hr);
}

# Now go through each change ...
my $ct_map = {
	'moderate' => \&do_moderate,
	'unmoderate' => \&do_unmoderate,
	'charter' => \&do_charter,
	'newgroup' => \&do_newgroup,
	'rmgroup' => \&do_rmgroup,
};

foreach my $c_hr (@change_list) {
	print "Change type: $c_hr->{type}\n";

	my $type = $c_hr->{type};

	if (exists $ct_map->{$type}) {

		my $coderef = $ct_map->{$type};
		&$coderef($v, $c_hr);
	} else {
		die "Unknown change type: $type\n";
	}
}

exit(0);

sub usage {
	die "Usage: perform-changes.pl vote-name\n";
}

sub do_moderate { die "Unimplemented moderate.\n"; }

sub do_unmoderate { die "Unimplemented unmoderate.\n"; }

sub do_charter {
	my $v = shift;
	my $c_hr = shift;

	my $newsgroup = $c_hr->{newsgroup};
	my $new_charter = $v->read_file("charter:$newsgroup");
	my $new_charter_string;
	foreach (@$new_charter) {
		$new_charter_string .= $_;
	}

	if ($new_charter ne '') {
		# Set the new charter
		my $ng = new Newsgroup(name => $newsgroup, datadir => "data/Newsgroups");
		$ng->set_attr('charter', $new_charter_string, "perform-changes.pl replaced charter");
	}
}

sub do_newgroup { die "Unimplemented newgroup.\n"; }

sub do_rmgroup { die "Unimplemented rmgroup.\n"; }
