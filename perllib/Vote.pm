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
	my $state = "unknown";

	if (-f "$ng_dir/vote_cancel.cfg") {
		return "cancelled";
	}

	if (-f "$ng_dir/rfd_cancel.cfg") {
		return "abandoned";
	}

	if (-f "$ng_dir/group.creation.date") {
		return "complete/pass";
	}

	if (-f "$ng_dir/result_posted.cfg") {
		return "complete/result";
	}

	if (-f "$ng_dir/result") {
		return "complete/resultnotposted";
	}

	if (-f "$ng_dir/result.unsigned") {
		return "complete/resultnotsigned";
	}

	if (-f "$ng_dir/endtime.cfg") {

		my $end_time = $self->get_end_time();
		my $now = time();

		if (-f "$ng_dir/posted.cfg") {
			if ($now >= $end_time) {
				return "vote/checking";
			}
			return "vote/running";
		}

		if (-f "$ng_dir/posted.cfv") {
			return "vote/cfvnotposted";
		}

		if (-f "$ng_dir/cfv") {
			return "vote/cfvnotsigned";
		}

		if (-f "$ng_dir/voterule") {
			return "vote/nocfv";
		}

		# The vote must be incompletely setup

		return "vote/notsetup";
	}

	if (-f "$ng_dir/voterule") {
		return "vote/notsetup";
	}

	if (-f "$ng_dir/rfd") {
		return "rfd";
	}

	return "unknown";
}

# Append to an audit trail of something we did

sub audit {
	my $self = shift;
	my $message = shift;

	my $ng_dir = $self->ng_dir();

	my($sec,$min,$hour,$mday,$mon,$year) = localtime(time());
	$mon++; $year += 1900;
	my $ts = sprintf "%d-%02d-%02d %02d:%02d:%02d", $year,$mon,$mday,$hour,$min,$sec;

	my $fh = new IO::File("$ng_dir/audit.log", O_WRONLY|O_APPEND|O_CREAT, 0644);
	die "Unable to create $ng_dir/audit.log" if (!defined $fh);

	$fh->print($ts, ' ', $message, "\n");
	$fh->close();
}


1;
