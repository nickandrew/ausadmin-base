#	@(#) Vote.pm - a vote of some kind
#
# $Id$

=head1 NAME

Vote - a Vote of some kind

=head1 SYNOPSIS

 use Vote;

 my @vote_list = Vote::list_votes(vote_dir => $vote_dir);
 		# returns a list of vote names in that directory

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
 $string = $vote->update_state();	# calc state then update file
 $state = $vote->set_state($state);	# set state in file

 $vote->write_voterule($template);

 $vote->audit($string);			# Append $string to the audit.log for this vote

=cut

package Vote;

use Carp qw(confess);
use IO::File qw(O_RDONLY O_WRONLY O_APPEND O_CREAT O_EXCL);
use Newsgroup ();
use Ausadmin ();
use DateFunc ();

use vars qw($result_discuss_days);

$Vote::DEFAULT_VOTE_DIR	= './vote';

my $result_discuss_days = 5;

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;

	die "No name" if (!exists $self->{name});

	if (!exists $self->{vote_dir}) {
		$self->{vote_dir} = $Vote::DEFAULT_VOTE_DIR;
	}

	return $self;
}

# Return the name of this vote

sub getName {
	my $self = shift;

	return $self->{name};
}

# Return a list of all votes in the directory

sub list_votes {
	my $args = { @_ };

	my $vote_dir = $args->{vote_dir} || $Vote::DEFAULT_VOTE_DIR;

	opendir(D, $vote_dir);
	my @files = grep { ! /^\./ } readdir(D);
	closedir(D);

	my @list;

	foreach my $f (@files) {
		my $path = "$vote_dir/$f";
		next if (! -d $path);
		# It is not a vote if there's no "change" file
		# (later) next if (! -f "$path/change");
		push(@list, $f);
	}

	return @list;
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
	confess("Unable to open $ng_dir/$filename: $!") if (!defined $fh);

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
# $v = { email => email_address, group => newsgroup, vote => YES|NO|ABSTAIN, ts => 987654321, path => messages/... , status => NEW|FORGE|MULTI-nnnnn }

sub get_tally {
	my $self = shift;

	if (exists $self->{tally_ref}) {
		return $self->{tally_ref};
	}

	# returns a ref to an array of unchomped lines
	my $ref = $self->read_file('tally.dat');

	my @list;

	foreach (@$ref) {
		chomp;
		my($email, $group, $vote, $ts, $p, $status) = split(/\s/);
		my $r = {
			email => $email,
			group => $group,
			vote => $vote,
			ts => $ts,
			path => $p,
			status => $status
		};

		push(@list, $r);
	}

	return $self->{tally_ref} = \@list;
}

$Vote::expected_files = {
	'cancel-email.txt' => 1,
	'cancel-notes.txt' => 1,
	'cfv' => 1,
	'cfv-notes.txt' => 1,
	'change' => 1,
	'charter' => 1,
	'control.msg' => 1,
	'distribution' => 1,
	'endtime.cfg' => 1,
	'group.creation.date' => 1,
	'ngline' => 1,
	'post.fake.phil' => 1,
	'post.fake.robert' => 1,
	'post.real' => 1,
	'posted.cfg' => 1,
	'cfv.signed' => 1,
	'proposer' => 1,
	'rationale' => 1,
	'result' => 1,
	'rfd' => 1,
	'rfd_posted.cfg' => 1,
	'state' => 1,
	'tally.dat' => 1,
	'vote_cancel.cfg' => 1,
	'vote_start.cfg' => 1,
	'voterule' => 1,
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


# $string = $vote->calc_state() ... Calculate the state from file existence

sub calc_state {
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

		my $posting_date = Ausadmin::read1line("$ng_dir/result_posted.cfg");

		if (DateFunc::days_between($posting_date, Ausadmin::today()) < $result_discuss_days) {
			return "complete/result-wait";
		}

		# Otherwise check the vote_result file to see what comes next

		if (!-f "$ng_dir/vote_result") {
			return "complete/no-vote-result";
		}

		my $result = Ausadmin::read1line("$ng_dir/vote_result");
		my($vote_result, $yes, $no, $abstain, $invalid) = split(/\s+/, $result);

		if ($vote_result eq 'PASS') {
			return "complete/pass/unprocessed";
		}

		if ($vote_result eq 'FAIL') {
			# Probably nothing more to do, so don't go into detail
			return "complete/fail";
		}

		# Should not happen
		return "complete/result-unknown";
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

		if (-f "$ng_dir/cfv.signed") {
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
		# Really need to check here for the time delay since the
		# RFD was posted. At least 21 days need to pass before
		# it can be turned into a vote. action does this
		# checking right now.
		return "rfd/posted";
	}

	if (-f "$ng_dir/rfd") {
		return "rfd/unposted";
	}

	if (-f "$ng_dir/rfd.unsigned") {
		return "rfd/unsigned";
	}

	if (-f "$ng_dir/change") {
		return "new/norfd";
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

# Methods to read from the state file first, or if it does not exist
# then calculate the state.

sub state {
	my $self = shift;

	my $vote_dir = $self->ng_dir();
	my $state_file = "$vote_dir/state";

	# Calculate the state
	my $state = $self->calc_state();

	return $state;
}

# Get the current state only, from the file or calculate it

sub update_state {
	my $self = shift;

	# Otherwise, calculate the state and save it in the file
	my $state = $self->calc_state();

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

	$self->audit("Set state to $new_state");

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

# abandon() ... Abandons an RFD, by creating a control-file with the
# abandonment date.

sub abandon {
	my $self = shift;
	my $rfd_posted_fn = $self->ng_dir("rfd_posted.cfg");
	my $cancel_fn = $self->ng_dir("rfd_cancel.cfg");
	my $name = $self->{name};

	if (!-f $rfd_posted_fn) {
		die "Augh. Vote::abandon() expected rfd_posted.cfg";
	}

	if (-f $cancel_fn) {
		die "Augh. Vote for $name already cancelled";
	}

	my $today = Ausadmin::today();
	my $fh = new IO::File($cancel_fn, O_WRONLY|O_APPEND|O_CREAT|O_EXCL, 0644);
	die "Unable to create $cancel_fn" if (!defined $fh);

	$fh->print($today, "\n");
	$fh->close();

	# FIXME ... there really should be a post generated to announce the
	# abandonment.

	$self->audit("Abandoned RFD");
}


sub get_message_paths {
	my $self = shift;

	my $tally_ref = $self->get_tally();

	foreach my $r (@$tally_ref) {
		if (!exists $r->{path}) {
			my($sec,$min,$hour,$mday,$mon,$year) = localtime($r->{ts});
			$mon++; $year += 1900;
			$r->{path} = sprintf "messages/%d%02d%02d-%02d%02d%02d", $year, $mon, $mday, $hour, $min, $sec;
		}
	}

	return $tally_ref;
}

=head1 METHOD - setup_vote()

A vote is started if certain control files exist in the vote/newsgroup
directory. These control files are:

	vote_start.cfg (contains the timestamp of the vote start time)
	endtime.cfg (contains the timestamp of the vote cutoff time)
	voterule (the parameters against which this ballot will be judged)

This program creates endtime.cfg for the chosen newsgroups
if it does not already exist.
The duration of the vote is taken from the first file found:

	vote/$newsgroup/voteperiod (duration in days)
	config/voteperiod

The automated vote taker can accept a vote as soon as endtime.cfg
exists (it must contain a timestamp later than the current time).

After this program has been run, use mkcfv.pl to create the
pgp-signed Call-For-Votes (CFV) message and post it, so everybody
knows they can vote.

=cut

# setup_vote() ... Create the necessary control files for a vote to be run

sub setup_vote {
	my $self = shift;

	my $vote_dir = $self->ng_dir();

	$self->write_voterule("config/voterule");

	my $endtime_cfg = "$vote_dir/endtime.cfg";
	my $start_file = "$vote_dir/vote_start.cfg";

	if (-f $endtime_cfg) {
		die "$endtime_cfg already exists";
		next;
	}

	my $vp_file = "$vote_dir/voteperiod";
	if (!-f $vp_file) {
		$vp_file = "config/voteperiod";
	}

	my $vote_period;

	if (open(VP, "<$vp_file")) {
		$vote_period = <VP>;
		chomp($vote_period);
		close(VP);
	} else {
		die "No $vp_file";
	}

	# Find the finish date for votes according to the VD (vote duration)
	my $vote_seconds = $vote_period * 86400;
	my $start_time = time();

	# Find the gmt end time
	my($sec,$min,$hour,$mday,$mon,$year) = gmtime($start_time + $vote_seconds);

	# Extend it to nearly midnight
	($hour,$min,$sec) = (23,59,59);
	my $then = timegm($sec,$min,$hour,$mday,$mon,$year);

	# Now make the human-readable one
	my $endtime = gmtime($then);

	# And write to control file
	open(T, ">$endtime_cfg");
	print T $then + 1, "\n";
	close(T);

	open(T, ">$start_file");
	print T $start_time, "\n";
	close(T);

	$self->audit("Setup vote to end at $endtime");
	$self->set_state("vote/nocfv");
}

# create_rfd ... Make an "rfd.unsigned" file from the components

sub create_rfd {
	my $self = shift;

	my $vote_dir = $self->ng_dir();
	my $vote_name = $self->{name} || die "This vote has no name!";

	# FIXME ... move all this executed code into the method!
	my $rc = system("make-rfd.pl $vote_name > $vote_dir/rfd-temp.$$");

	if ($rc) {
		$self->audit("RFD creation failed, code $rc");
		die "RFD creation failed";
	}

	rename("$vote_dir/rfd-temp.$$", "$vote_dir/rfd.unsigned");

	$self->audit("Created unsigned RFD");
	$self->set_state("rfd/unsigned");
}

# post_rfd ... Post the signed RFD file.

sub post_rfd {
	my $self = shift;

	my $vote_dir = $self->ng_dir();
	my $vote_name = $self->{name} || die "This vote has no name!";

	# FIXME ... move all this executed code into the method!
	my $rc = system("post.pl < $vote_dir/rfd");

	if ($rc) {
		$self->audit("RFD posting failed, code $rc");
		die "RFD posting failed";
	}

	$self->audit("Posted signed RFD");

	# Now note the date the RFD was posted
	#
	my $yyyymmdd = Ausadmin::today();

	open(F, ">$vote_dir/rfd_posted.cfg");
	print F $yyyymmdd, "\n";
	close(F);

	$self->set_state("rfd/posted");
}


1;
