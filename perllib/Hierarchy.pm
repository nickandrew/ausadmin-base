#	@(#) Hierarchy.pm - a managed hierarchy

=head1 NAME

Hierarchy - a managed hierarchy

=head1 SYNOPSIS

 use Hierarchy;

 my @hierarchy_list = Hierarchy::list();
	# returns a list of hierarchies
=cut

package Hierarchy;

use Carp qw(confess);


# ---------------------------------------------------------------------------
# Return a list of all managed hierarchies
# ---------------------------------------------------------------------------

sub list {
	my $args = { @_ };

	# Ignore newsgroup names not containing a dot, and . and ..
	opendir(D, '.');
	my @files = grep { /^.*\.data$/ } readdir(D);
	closedir(D);

	my @list;

	foreach my $f (sort @files) {

		next if (! -d $f);
		next if (! -d "$f/Newsgroups");

		if ($f =~ /(.*)\.data$/) {
			push(@list, $1);
		}
	}

	return @list;
}

1;
