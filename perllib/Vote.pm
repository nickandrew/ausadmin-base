#	@(#) Vote.pm - a vote of some kind
#
# $Id$

=head1 NAME

Vote - a Vote of some kind

=head1 SYNOPSIS

 use Vote;

 my $vote = new Vote(name => 'aus.history');
 $vote_dir = $vote->ng_dir();		# returns relative path of vote's dir
 $time = $vote->get_start_time();
 $time = $vote->get_end_time();
 $time = $vote->get_cancel_time();
 $list_ref = $vote->read_file($filename);
 $list_ref = $vote->get_distribution();
 $list_ref = $vote->get_tally();
 $string = $vote->state();		# return string representing vote's state

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

	if (exists $self->{ng_dir}) {
		return $self->{ng_dir};
	}

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

$Vote::expected_files = {
	'distribution' => 1,
	'charter' => 1,
	'rationale' => 1,
	'ngline' => 1,
	'proposer' => 1,
	'vote_start.cfg' => 1,
	'vote_cancel.cfg' => 1,
	'rfd_posted.cfg' => 1,
	'cfv-notes.txt' => 1,
	'cancel-email.txt' => 1,
	'cancel-notes.txt' => 1,
	'group.creation.date' => 1,
	'post.real' => 1,
	'post.fake.phil' => 1,
	'post.fake.robert' => 1,
	'control.msg' => 1,
	'rfd' => 1,
	'voterule' => 1,
	'endtime.cfg' => 1,
	'cfv' => 1,
	'posted.cfv' => 1,
	'posted.cfg' => 1,
	'result' => 1,
	'tally.dat' => 1,
};

# Return a list of unexpected filenames in a vote directory

sub check_files {
	my $self = shift;

	my $ng_dir = $self->ng_dir();

	opendir(D, $ng_dir);
	my @files = grep { ! /^\./ } readdir(D);
	closedir(D);

	my @list;

	foreach my $f (@files) {
		next if (exists $Vote::expected_files->{$f});
		push(@list, $f);
	}

	return \@list;
}


# $string = $vote->state() ...

sub state {
	my $self = shift;

	my $ng_dir = $self->ng_dir();

	if (!-f "$ng_dir/rfd") {
		return "new";
	}

	if (!-f "$ng_dir/voterule") {
		return "rfd";
	}

	if (!-f "$ng_dir/endtime.cfg") {
		return "vote/notsetup";
	}

	if (!-f "$ng_dir/cfv") {
		return "vote/nocfv";
	}

	if (!-f "$ng_dir/posted.cfv") {
		return "vote/unsignedcfv";
	}

	if (!-f "$ng_dir/posted.cfg") {
		return "vote/cfvnotposted";
	}

	my $state = "vote/running";

	my $end_time = $self->get_end_time();
	my $now = time();

	if ($now < $end_time) {
		return $state;
	}

	# Vote period must be finished.

	# note this is testing for presence of file, not absence
	if (-f "$ng_dir/result") {
		return "complete/result";
	}

	# cop-out
	return "complete/checking";
}

1;
