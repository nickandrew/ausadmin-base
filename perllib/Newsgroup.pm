#	@(#) Newsgroup.pm - a newsgroup (existing or not)

=head1 NAME

Newsgroup - a newsgroup

=head1 SYNOPSIS

use Newsgroup;

my $vote = new Newsgroup(name => 'aus.history');

my $bool = Newsgroup::validate('aus.history');

=cut

package Newsgroup;

use IO::File;

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;

	die "No name" if (!exists $self->{name});

	return $self;
}

sub validate {
	my $ng_name = shift;

	return 1 if ($ng_name =~ /^[a-z0-9+-]+\.[a-z0-9+-]+(\.[a-z0-9+-]+)*$/);
	return 0;
}

1;
