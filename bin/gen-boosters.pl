#!/usr/bin/perl
#	@(#) gen-boosters.pl - Generate booster control msgs for all newsgroups
#
# Usage:	gen-boosters.pl [-s] [-l limit]
#
# 	-s	Sign any new or different booster control messages
# 		(If not given and the current message differs from the
# 		old one, then the new one will _not_ be saved)

use Getopt::Std;

use lib 'perllib';

use Newsgroup;

my %opts;

getopts('h:sl:', \%opts);

my($hier_name, $datadir);

if ($opts{'h'}) {
	$hier_name = $opts{'h'};
} else {
	$hier_name = "aus";
}

my @groups = Newsgroup::list_newsgroups(hier => $hier_name);

my $limit = $opts{'l'} || 99999;

foreach my $group (sort @groups) {
	my $ng = new Newsgroup(hier => $hier_name, name => $group);
	if (!defined $ng) {
		print STDERR "Unable to instantiate Newsgroup(name => $group)";
	}

	# Read current newgroup.booster.ctl, if any
	my $current_booster = $ng->get_attr('newgroup.booster.ctl');

	# Generate a new one
	my $control_text = $ng->gen_newgroup('booster');

	# Replace/rename if they differ
	if ($control_text ne $current_booster) {
		if ($opts{'s'}) {
			# Save the current (or new) one
			$ng->set_attr('newgroup.booster.ctl', $control_text, "Changed booster newgroup");
		} else {
			if (defined $current_booster) {
				print STDERR "NOT saving newgroup.booster.ctl because -s option not given!\n";
			}
		}
	}

	# FIXME ... big errors here, if the user chooses to not sign,
	# and there is an existing signed booster from a previous template.

	# Now read the signed one
	my $signed_booster = $ng->get_attr('newgroup.booster.sctl');

	# Don't bother to sign if '-s' not given
	next unless ($opts{'s'});

	if (!defined $signed_booster || $control_text ne $current_booster) {

		print "Sign newgroup.booster.ctl for $group? [y/N] ";
		my $sign_it = <STDIN>;
		if ($sign_it =~ /^y/i) {
			# Sign the new one, and save it
			my $control_signed = $ng->sign_control($control_text);

			if (defined $control_signed) {
				$ng->set_attr('newgroup.booster.sctl', $control_signed, "Changed signed booster newgroup");
			}
		}
	}

	if ($limit-- == 0) {
		last;
	}

}

exit(0);

sub usage {
	die "Usage: gen-boosters.pl\n";
}
