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

=head1 METHOD - setup_vote()

A vote is started if certain control files exist in the vote/$newsgroup
directory. These control files are:

	vote_start.cfg (contains the timestamp of the vote start time)
	endtime.cfg (contains the timestamp of the vote cutoff time)
	voterule (the parameters against which this ballot will be judged)

This function creates endtime.cfg for the chosen newsgroups
if it does not already exist.
The duration of the vote is taken from the first file found:

	vote/$newsgroup/voteperiod (duration in days)
	config/voteperiod

The automated vote taker can accept a vote as soon as endtime.cfg
exists (it must contain a timestamp later than the current time).

=cut

package Vote;

use Carp qw(confess);
use IO::File qw(O_RDONLY O_WRONLY O_APPEND O_CREAT O_EXCL);
use Time::Local qw(timegm);

use Newsgroup qw();
use Ausadmin qw();
use DateFunc qw();
use Post qw();

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

	$self->{rfd_min_days} ||= 21;

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

	my $line = $ts . " proposal/$self->{name} " . $message . "\n";
	$fh->print($line);
	$fh->close();

	# Also write to combined audit log
	$fh = new IO::File("tmp/combined-audit.log", O_WRONLY|O_APPEND|O_CREAT, 0644);
	if ($fh) {
		$fh->print($line);
		$fh->close();
	}
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
	my $cancel_config = $self->ng_dir("rfd_cancel.cfg");
	my $cancel_file = $self->ng_dir("rfd_cancel.txt");
	my $name = $self->{name};

	if (!-f $rfd_posted_fn) {
		die "Augh. Vote::abandon() expected rfd_posted.cfg";
	}

	if (-f $cancel_config) {
		die "Augh. Vote for $name already cancelled";
	}

	if (! -f $cancel_file) {
		die "Augh. Need CANCELREASON in $cancel_file";
	}

	my $cancel_text = Ausadmin::readfile($cancel_file);

	# -------------------------------------------------------------------
	# Send a cancel post
	# -------------------------------------------------------------------
	my $post = new Post(template => "$ENV{AUSADMIN_HOME}/config/rfd-cancel.template");
	my $distrib = $self->get_distribution();
	$post->substitute('!DISTRIBUTION!', join(',', @$distrib));
	$post->substitute('!NEWSGROUP!', $self->getName());
	$post->substitute('!CANCELREASON!', $cancel_text);
	$post->send();

	# -------------------------------------------------------------------
	# Update state
	# -------------------------------------------------------------------

	my $today = Ausadmin::today();
	my $fh = new IO::File($cancel_config, O_WRONLY|O_APPEND|O_CREAT|O_EXCL, 0644);
	die "Unable to create $cancel_config" if (!defined $fh);

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

# setup_vote() ... Create the necessary control files for a vote to be run

sub setup_vote {
	my $self = shift;

	my $vote_dir = $self->ng_dir();

	my $endtime_cfg = "$vote_dir/endtime.cfg";
	my $start_file = "$vote_dir/vote_start.cfg";

	if (-f $endtime_cfg) {
		die "$endtime_cfg already exists";
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

	$self->write_voterule("config/voterule");

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
	eval {
		$self->make_rfd();
	};

	if ($@) {
		$self->audit("RFD creation failed: $@");
		die "RFD creation failed: $@";
	}

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

	# Now note the date the RFD was posted
	#
	my $yyyymmdd = Ausadmin::today();

	open(F, ">$vote_dir/rfd_posted.cfg");
	print F $yyyymmdd, "\n";
	close(F);

	my $future = DateFunc::addday($yyyymmdd, $self->{rfd_min_days});

	open(F, ">$vote_dir/rfd_enddate.cfg");
	print F $future, "\n";
	close(F);

	$self->audit("Posted signed RFD, discuss until: $future");

	$self->set_state("rfd/posted");
}

sub revise_rfd {
	my($self) = shift;

	my $state = $self->calc_state();

	my $ok_states = {
		'new/norfd' => 1,
		'rfd/unsigned' => 1,
		'rfd/unposted' => 1,
		'rfd/posted' => 1,
	};

	if (! $ok_states->{$state}) {
		die "Cannot revise RFD with vote $self->{name} in state $state\n";
	}

	my $dir = $self->ng_dir();

	unlink("$dir/rfd_posted.cfg", "$dir/rfd", "$dir/rfd.unsigned");
	$self->audit("Reverted vote state to revise RFD");
	$self->make_rfd();
}

# ---------------------------------------------------------------------------
# Create the text of an RFD
# ---------------------------------------------------------------------------

sub gen_rfd_string {
	my($self) = @_;

	my $ng_dir = $self->ng_dir();

	if (!-d $ng_dir) {
		die "No $ng_dir directory for $self->{name}";
	}

	foreach my $i (qw/change rationale proposer distribution/) {
		if (!-f "$ng_dir/$i") {
			die "No $ng_dir/$i";
		}
	}

	my $change = Ausadmin::read_keyed_file("$ng_dir/change");

	my $rationale = Ausadmin::readfile("$ng_dir/rationale");
	my $proposer = Ausadmin::read1line("$ng_dir/proposer");
	my $distribution = Ausadmin::readfile("$ng_dir/distribution");
	my $rfd_notes = Ausadmin::readfile("$ng_dir/rfd-notes.txt");

	my $data = { };
	my $newsgroup = $change->{'newsgroup'};

	$data->{ngline} = Ausadmin::read1line("$ng_dir/ngline:$newsgroup");
	$data->{charter} = Ausadmin::readfile("$ng_dir/charter:$newsgroup");
	$data->{modinfo} = Ausadmin::readfile("$ng_dir/modinfo:$newsgroup");

	# Now read the template
	my $procedure = Ausadmin::readfile("config/rfd-procedure.txt");

	# Now put it all together
	my @lines;

	push(@lines, "REQUEST FOR DISCUSSION");

	# Now key on which kind of change it is
	my $change_descr;
	my $change_type = $change->{'type'};

	if ($change_type eq 'newgroup') {
		if ($change->{'mod_status'} eq 'm') {
			push(@lines, "Creation of Moderated newsgroup $newsgroup");
			$change_descr = "the creation of a new Australian moderated newsgroup $newsgroup";
		} else {
			push(@lines, "Creation of Unmoderated newsgroup $newsgroup");
			$change_descr = "the creation of a new Australian unmoderated newsgroup $newsgroup";
		}
	} elsif ($change_type eq 'rmgroup') {
		push(@lines, "Remove newsgroup $newsgroup");
		$change_descr = "the removal of the existing newsgroup $newsgroup";
	} elsif ($change_type eq 'moderate') {
		push(@lines, "Change $newsgroup to moderated");
		$change_descr = "the change of $newsgroup to moderated";
	} elsif ($change_type eq 'unmoderate') {
		push(@lines, "Change $newsgroup to unmoderated");
		$change_descr = "the change of $newsgroup to unmoderated";
	} elsif ($change_type eq 'charter') {
		push(@lines, "Change charter of $newsgroup");
		$change_descr = "changing the charter of $newsgroup";
	} else {
		die "Unknown change type $change_type";
	}


	@lines = Ausadmin::centred_text(@lines);	# yuk
	push(@lines, "\n");

	my $x = <<EOF;
This is a formal Request For Discussion (RFD) for
$change_descr.
This is not a Call For Votes (CFV); you cannot vote at this time.
EOF

	# Now format the paragraph
	my @fmt = Ausadmin::format_para($x);
	push(@lines, join("\n", @fmt), "\n\n");

	if ($change_type =~ /^(newgroup|moderate)$/) {
		push(@lines, "Newsgroup line:\n");
		push(@lines, $data->{ngline} . "\n");
		push(@lines, "\n");
	}

	if ($rfd_notes) {
		push(@lines, "RFD NOTES:\n\n", $rfd_notes);
		push(@lines, "\nEND RFD NOTES.\n\n");
	}

	push(@lines, "RATIONALE:\n\n", $rationale);
	push(@lines, "\nEND RATIONALE.\n\n");

	# Now we loop through, emitting all the per-newsgroup information we have
	if (exists $data->{charter}) {
		if ($change->{'charter'} =~ /html/i) {
			# Use lynx to reformat HTML charters
			push(@lines, "CHARTER: $newsgroup\n\n");
			my $cmd = "cat vote/$newsgroup/charter:$newsgroup | lynx -dump -stdin -force_html";
			my $charter_text = `$cmd`;
			push(@lines, $charter_text);
			push(@lines, "\nEND CHARTER.\n\n");
		} else {
			# Other types (or unspecified) assumed plain text
			push(@lines, "CHARTER: $newsgroup\n\n", $data->{charter});
			push(@lines, "\nEND CHARTER.\n\n");
		}
	}

# Do the same thing for mod_status (probably not required)
#	if (exists $data->{modinfo}) {
#		push(@lines, "MODERATOR INFO: $newsgroup\n\n", $modinfo);
#		push(@lines, "\nEND MODERATOR INFO.\n\n");
#		push(@lines, "SUBMISSION EMAIL: $change->{'submission_email'}\n");
#		push(@lines, "REQUEST EMAIL: $change->{'request_email'}\n");
#		push(@lines, "\n");
#	}

	push(@lines, "PROPOSER: $proposer\n\n");

	push(@lines, "PROCEDURE:\n\n", $procedure, "\n");

	push(@lines, "DISTRIBUTION:\n\n", $distribution);

	# Print first, the message header ...

	my %header = (
		Subject => "Request For Discussion (RFD): $newsgroup",
		Newsgroups => join(',', split("\n", $distribution))
	);

	my $s = Ausadmin::make_header(\%header);

	foreach (@lines) {
		$s .= $_;
	}

	return $s;
}

# ---------------------------------------------------------------------------
# Make and save an RFD
# ---------------------------------------------------------------------------

sub make_rfd {
	my $self = shift;

	my $state = $self->calc_state();

	die "State must be new/norfd not $state\n" if ($state ne 'new/norfd');

	my $s = $self->gen_rfd_string();

	my $ng_dir = $self->ng_dir();

	open(RFD, ">$ng_dir/rfd.unsigned") || die "Unable to write to rfd.unsigned: $!";
	print RFD $s;
	close(RFD);

	$self->audit("Created unsigned RFD");
}

1;
