#	@(#) $Id$

=head1 NAME

Checkgroups - a USENET message which contains the group list.

=head1 SYNOPSIS

 use Checkgroups;

 $gl = new Checkgroups(hier => $hier);

 $gl->write($file_temp, $file_real);	Writes checkgroup message to file

=cut

package Checkgroups;

use IO::File;
use IPC::Open2;

use Ausadmin qw();
use Newsgroup qw();

# ---------------------------------------------------------------------------
# Constructor
# ---------------------------------------------------------------------------

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;

	$self->{hier} ||= Newsgroup::defaultHierarchy();

	$self->{'signcmd'} ||= 'signcontrol';
	my $datadir = Newsgroup::datadir($self->{hier});
	$self->{'grouplist_file'} ||= "$datadir/checkgroups";
	$self->{'head_text'} ||= Ausadmin::readfile("$datadir/config/checkgroups.header");
	$self->{'foot_text'} ||= Ausadmin::readfile("$datadir/config/checkgroups.footer");

	return $self;
}

# ---------------------------------------------------------------------------
# Write the whole checkgroups out to a file.
# ---------------------------------------------------------------------------

sub write {
	my $self = shift;
	my $file_temp = shift;
	my $file_real = shift;

	my($sec,$min,$hour,$mday,$mon,$year,$wday,$isdst) = localtime(time());

	my $monthname=("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")[$mon];
	my $weekday = ("Sun","Mon","Tue","Wed","Thu","Fri","Sat","Sun")[$wday];

	$year += 1900; $mon++;
	my $today = sprintf "%d-%02d-%02d", $year, $mon, $mday;
	my $now = sprintf "%d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;


	# Generate the message, header first
	my $hier = $self->{hier};

	my %header = (
		'Subject' => "checkgroups for $hier.* groups on $today",
		'Newsgroups' => 'aus.net.news',
		'Control' => 'checkgroups',
		'Approved' => 'ausadmin@aus.news-admin.org',
		'Followup-To' => '',
		'X-PGPKey' => '',
		'Organization' => '',
		'Path' => 'aus.news-admin.org|ausadmin',
	#	Note: Message-ID is added automatically by signcontrol
	#	'Message-ID' => "$^T$$ausadmin\@aus.news-admin.org",
		'Date' => "$weekday, $mday $monthname $year $hour:$min:$sec",
	);

	my $grouplist = Ausadmin::readfile($self->{'grouplist_file'});

	my $fh = new IO::File;
	my $signcmd = $self->{'signcmd'};

	if (!open($fh, "|$signcmd > $file_temp")) {
		die "Unable to open pipe to $signcmd or $file_temp for writing: $!";
	}

	Ausadmin::print_header(\%header, $fh);

	print $fh "\n";

	if (defined $self->{'head_text'}) {
		print $fh $self->{'head_text'};
	}

	print $fh $grouplist;

	if (defined $self->{'foot_text'}) {
		print $fh $self->{'foot_text'};
	}

	if (!close($fh)) {
		unlink($file_temp);
		die "Unable to write $file_temp (unlinked): $!";
	}

	# Now rename from the temp file to the real file
	if (!rename($file_temp, $file_real)) {
		die "Unable to rename from $file_temp to $file_real : $!";
	}
}


1;
