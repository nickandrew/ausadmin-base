#	@(#) $Id$

=head1 NAME

GroupList - a canonical list of currently existing newsgroups

=head1 SYNOPSIS

 use GroupList;

 $gl = new GroupList(hier => $hier);

 $gl->write($file_temp, $file_real);	Writes new group list to file

=cut

package GroupList;

use IO::File;
use IPC::Open2;

use Ausadmin qw();
use Newsgroup qw();

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;

	$self->{hier} ||= Newsgroup::defaultHierarchy();

	return $self;
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

	my $datadir = Newsgroups::datadir($self->{hier});
	my $fh = new IO::File;
	if (!open($fh, ">$datadir/$file_temp")) {
		die "Unable to open $datadir/$file_temp for writing: $!";
	}

	foreach (@nglines) {
		my $newsgroup = $_->[0];
		# Tab out to column 32 (all group names will line up)
		my $l = 4 - int(length($newsgroup)/8);
		$l = ($l < 1) ? 1 : $l;

		print $fh $newsgroup, "\t" x $l, $_->[1];
	}

	if (!close($fh)) {
		unlink("$datadir/$file_temp");
		die "Unable to write $datadir/$file_temp (unlinked): $!";
	}

	# Now rename from the temp file to the real file
	if (!rename("$datadir/$file_temp", "$datadir/$file_real")) {
		die "Unable to rename from $datadir/$file_temp to $datadir/$file_real : $!";
	}
}


1;
