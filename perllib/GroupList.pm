#	@(#) $Id$

=head1 NAME

GroupList - a canonical list of currently existing newsgroups

=head1 SYNOPSIS

 use GroupList;

 $gl = new GroupList();

 $gl->write($file_temp, $file_real);	Writes new group list to file

=cut

package GroupList;

use IO::File;
use IPC::Open2;

use Ausadmin;
use Newsgroup;

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;

	if ($self->{hier}) {
		$self->{datadir} = "$self->{hier}.data";
	}

	return $self;
}

# Set the data directory from which we obtain data about this newsgroup

sub set_datadir {
	my $self = shift;
	my $datadir = shift;

	die "No such directory: $datadir" if (!-d $datadir);

	$self->{datadir} = $datadir;

	return $datadir;
}

sub write {
	my $self = shift;
	my $file_temp = shift;
	my $file_real = shift;

	my $hier = $self->{hier};
	my @ng_list = Newsgroup::list_newsgroups(hier => $hier);
	my @nglines;

	foreach my $newsgroup (@ng_list) {
		my $ng = new Newsgroup(name => $newsgroup, hier => $hier);
		if (!defined $ng) {
			die "Unable to get info for $newsgroup\n";
		}

		my $ngline = $ng->get_attr('ngline');
		push(@nglines, [$newsgroup, $ngline]);
	}

	my $fh = new IO::File;
	if (!open($fh, ">$file_temp")) {
		die "Unable to open $file_temp for writing: $!";
	}

	foreach (@nglines) {
		my $newsgroup = $_->[0];
		# Tab out to column 32 (all group names will line up)
		my $l = 4 - int(length($newsgroup)/8);
		$l = ($l < 1) ? 1 : $l;

		print $fh $newsgroup, "\t" x $l, $_->[1];
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
