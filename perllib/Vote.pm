#	@(#) Vote.pm - a vote of some kind
#
# $Id$

=head1 NAME

Vote - a Vote of some kind

=head1 SYNOPSIS

 use Vote;

 my $vote = new Vote(name => 'aus.history');
 $vote_dir = $vote->ng_dir();		# returns relative path of vote's dir
 $config_path = $vote->ng_dir($filename) # returns rel path of this config file
 $time = $vote->get_start_time();
 $time = $vote->get_end_time();
 $time = $vote->get_cancel_time();
 $list_ref = $vote->read_file($filename);
 $list_ref = $vote->get_distribution();
 $list_ref = $vote->get_tally();
 $string = $vote->state();		# return string representing vote's state
 $string = $vote->get_state();		# read state from file first, calc 2nd
 $state = $vote->set_state($state);	# set state in file

 $vote->write_voterule($template);

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
		$self->{vote_dir} = "./vote";
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
	my $file = shift;

	if (!exists $self->{ng_dir}) {
		$self->{ng_dir} = "$self->{vote_dir}/$self->{name}";
	}

	if (defined $file) {
		return "$self->{ng_dir}/$file";
	}

	return $self->{ng_dir};
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


# $string = $vote->calc_state() ...

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

	if (-f "$ng_dir/control.signed") {
		return "complete/pass/signed";
	}

	if (-f "$ng_dir/control.msg") {
		return "complete/pass/unsigned";
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

	if (-f "$ng_dir/rfd_posted.cfg") {
		return "rfd/posted";
	}

	if (-f "$ng_dir/rfd") {
		return "rfd/unposted";
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

sub write_voterule {
	my $self = shift;
	my $template = shift;

	my $vote_dir = $self->ng_dir();
	my $vote_rule = "$vote_dir/voterule";
	if (!-f $vote_rule) {
		if (!-f $template) {
			die "write_voterule: $template does not exist!";
		}

		open(F, "<$template");
		my $vr = <F>;
		close(F);
		open(G, ">$vote_rule");
		print G $vr;
		close(G);
	}
}

sub get_state {
	my $self = shift;

	my $vote_dir = $self->ng_dir();
	my $state_file = "$vote_dir/state";

	if (-f $state_file) {
		my $state = read1line($state_file);
		return $state;
	}

	# Otherwise, calculate the state and save it in the file
	my $state = $self->state();

	return $self->set_state($state);
}

sub set_state {
	my $self = shift;
	my $new_state = shift;

	my $vote_dir = $self->ng_dir();
	my $state_file = "$vote_dir/state";

	open(F, ">$state_file");
	print F $new_state, "\n";
	close(F);

	return $new_state;
}

sub count_votes {
	my $self = shift;
	my $tally_file = $self->ng_dir("tally.dat");
	my $name = $self->{name};

	my $results = {
		yes => 0,
		no => 0,
		abstain => 0,
		forge => 0,
		informal => 0
	};

	my @voters;

	# Open the tally file and munch it
	if (!open(T, "<$tally_file")) {
		die "Vote $name has no tally file.\n";
	}

	while (<T>) {
		my($email,$ng,$v,$ts,$path) = split;

		$v=lc($v);

		if (!exists $results->{$v}) {
			# This is a vote type we don't know about
			$v = 'informal';
		}

		$results->{$v}++;

		push(@voters, [$email, $v]);

	}

	close(T);

	return($results, \@voters);
}

# returns 'pass' or 'fail'

sub calc_result {
	my $self = shift;

	my $voterule = $self->_read_config_line("voterule");
	my($numer,$denomer,$minyes) = split(/\s+/, $voterule);

	my($results,$voters) = $self->count_votes();

	if (($results->{yes} >= ($results->{yes} + $results->{no}) * $numer / $denomer) && ($results->{yes} - $results->{no} >= $minyes)) {
		return 'pass';
	}

	return 'fail';
}

1;
