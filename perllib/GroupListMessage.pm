#!/usr/bin/perl
#	@(#) $Id$

=head1 NAME

GroupListMessage - a USENET message which contains the group list.

=head1 SYNOPSIS

 use GroupListMessage;

 $gl = new GroupListMessage();

 $gl->write($file_temp, $file_real);	Writes grouplist message to file

=cut

package GroupListMessage;

use IO::File;
use IPC::Open2;

use Ausadmin;
use Newsgroup;

$GroupListMessage::DEFAULT_GROUPLISTMESSAGE_DIR	= './data';

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;

	$self->{'datadir'} ||= $GroupListMessage::DEFAULT_GROUPLISTMESSAGE_DIR;

	$self->{'signcmd'} ||= 'pgp-sign';
	$self->{'grouplist_file'} ||= 'data/checkgroups';
	$self->{'head_text'} ||= Ausadmin::readfile('config/grouplist.header');
	$self->{'foot_text'} ||= Ausadmin::readfile('config/grouplist.footer');

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

	my($sec,$min,$hour,$mday,$mon,$year,$wday,$isdst) = localtime(time());

	my $monthname=("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")[$mon];
	my $weekday = ("Sun","Mon","Tue","Wed","Thu","Fri","Sat","Sun")[$wday];

	$year += 1900; $mon++;
	my $today = sprintf "%d-%02d-%02d", $year, $mon, $mday;
	my $now = sprintf "%d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;


	# Generate the message, header first

	my %header = (
		'Subject' => "List of aus.* newsgroups at $now",
		'Newsgroups' => 'aus.net.news,news.admin.hierarchies',
		'Followup-To' => '',
	);

	my $grouplist = Ausadmin::readfile($self->{'grouplist_file'});

	my $fh = new IO::File;
	my $signcmd = $self->{'signcmd'};

	if (!open($fh, "|$signcmd > $file_temp")) {
		die "Unable to open pipe to $signcmd or $file_temp for writing: $!";
	}

	Ausadmin::print_header(\%header, $fh);

	if (defined $self->{'head_text'}) {
		print $fh $self->{'head_text'};
	}

	print $fh $grouplist;

	if (defined $self->{'foot_text'}) {
		print $fh $self->{'foot_text'};
	}

	if (! close($fh)) {
		unlink($file_temp);
		die "Unable to write $file_temp (unlinked): $!";
	}

	# Now rename from the temp file to the real file
	if (!rename($file_temp, $file_real)) {
		die "Unable to rename from $file_temp to $file_real : $!";
	}
}


1;
