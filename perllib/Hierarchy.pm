#	@(#) Hierarchy.pm - a managed hierarchy

=head1 NAME

Hierarchy - a managed hierarchy

=head1 DESCRIPTION

Create and maintain all the necessary data structures for a hierarchy

=head1 SYNOPSIS

 use Hierarchy;

 my @hierarchy_list = Hierarchy::list();
	# returns a list of hierarchies
=cut

package Hierarchy;

use strict;

use Carp qw(confess);


# ---------------------------------------------------------------------------
# Return a list of all managed hierarchies
# ---------------------------------------------------------------------------

sub list {
	my $args = { @_ };

	# Ignore newsgroup names not containing a dot, and . and ..
	my $top_directory = "$ENV{AUSADMIN_HOME}/data";
	opendir(D, $top_directory);
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

# ---------------------------------------------------------------------------
# Create all the data structures for a hierarchy
# ---------------------------------------------------------------------------

sub create {
	my $args = { @_ };

	die "Need hier" if (! $args->{hier});

	my $hier = $args->{hier};

	my $data_dir = Newsgroup::datadir($hier);

	if (-e $data_dir) {
		die "$data_dir exists already!";
	}

	foreach my $subdir ('', '/Html', '/Newsgroups', '/RCS') {
		mkdir("$data_dir$subdir", 0755);
	}
}

1;
