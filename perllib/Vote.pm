#	@(#) Vote.pm - a vote of some kind

=head1 NAME

Vote - a Vote of some kind

=head1 SYNOPSIS

use Vote;

my $vote = new Vote(name => 'aus.history');

=cut

package Vote;

use IO::File;
use Newsgroup;

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;

	die "No name" if (!exists $self->{name});

	if (!exists $self->{vote_dir}) {
		$self->{vote_dir} = "vote";
	}

	return $self;
}

sub _read_config_line {
	my $self = shift;
	my $filename = shift;

	my $ng_dir = "$self->{vote_dir}/$self->{name}";
	my $fh = new IO::File("$ng_dir/$filename", O_RDONLY);
	die "Expected $ng_dir/$filename" if (!defined $fh);

	my $t = <$fh>;
	chomp($t);
	$fh->close();

	return $t;
}

sub _read_file {
	my $self = shift;
	my $filename = shift;

	my $ng_dir = "$self->{vote_dir}/$self->{name}";
	my $fh = new IO::File("$ng_dir/$filename", O_RDONLY);
	die "Expected $ng_dir/$filename" if (!defined $fh);

	my @lines = <$fh>;

	$fh->close();

	return \@lines;
}

sub ng_dir {
	my $self = shift;

	my $ng_dir = "$self->{vote_dir}/$self->{name}";

	return $ng_dir;
}

sub get_start_time {
	my $self = shift;
	return $self->_read_config_line("vote_start.cfg");
}

sub get_end_time {
	my $self = shift;
	return $self->_read_config_line("endtime.cfg");
}

sub get_cancel_time {
	my $self = shift;
	return $self->_read_config_line("vote_cancel.cfg");
}

sub read_file {
	my $self = shift;
	my $filename = shift;
	return $self->_read_file($filename);
}

# my $list_ref = $vote->get_distribution();

sub get_distribution {
	my $self = shift;

	# returns a ref to an array of unchomped lines
	my $ref = $self->read_file('distribution');

	my @g = grep { chomp; Newsgroup::validate($_) } @$ref;

	return \@g;
}

# my $list_ref = $vote->get_tally()
# $vote_list = [$v, $v, $v, ...]
# $v = { email => email_address, group => newsgroup, vote => YES|NO|ABSTAIN, ts => 987654321 }

sub get_tally {
	my $self = shift;

	# returns a ref to an array of unchomped lines
	my $ref = $self->read_file('tally.dat');

	my @list;

	foreach (@$ref) {
		chomp;
		my($email, $group, $vote, $ts) = split(/\s+/);
		my $r = {
			email => $email,
			group => $group,
			vote => $vote,
			ts => $ts
		};

		push(@list, $r);
	}

	return \@list;
}

1;
