#!/usr/bin/perl
#	@(#) test-newgroup.pl - Create a newgroup control message

use lib 'perllib';

use Newsgroup;

my $group = shift @ARGV || usage();

my $ng = new Newsgroup (name => $group);
if (!defined $ng) {
	die "Unable to create Newsgroup(name => $group)";
}

my $control_text = $ng->gen_newgroup('booster');

# Now sign it

my $control_signed = $ng->sign_control($control_text);

print "Here is the unsigned one:\n", $control_text;
print "Here is the signed one:\n", $control_signed;

exit(0);

sub usage {
	die "Usage: test-newgroup.pl group.name\n";
}
