#	@(#) Newsgroup.pm - a newsgroup (existing or not)

=head1 NAME

Newsgroup - a newsgroup

=head1 SYNOPSIS

 use Newsgroup;

 $nntp = new Net::NNTP(...)

 $ng = new Newsgroup(name => 'aus.history', [nntp_server=>$nntp]);
 $bool = Newsgroup::validate('aus.history');

 $ng->set_server($nntp)
 $flags = $ng->group_flags()  ... return the 'y' or 'm' status of the group
 
 $ng->set_datadir($path)	... Set the path for accessing newsgroup data
 $string = $ng->get_attr('charter') ... Read the charter data, return as string
 $ng->set_attr('charter', $string, 'Update reason') ...

=cut

package Newsgroup;

use IO::File;

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;

	die "No name" if (!exists $self->{name});

	return $self;
}

sub validate {
	my $ng_name = shift;

	return 1 if ($ng_name =~ /^[a-z0-9+-]+\.[a-z0-9+-]+(\.[a-z0-9+-]+)*(:\d\d\d\d-\d\d-\d\d)?$/);
	return 0;
}

# Set the open connection to an NNTP server

sub set_server {
	my $self = shift;
	my $conn = shift;

	die "Newsgroup::set_server must be given a reference" if (!ref $conn);

	$self->{nntp_server} = $conn;

	return $conn;
}

# Set the data directory from which we obtain data about this newsgroup

sub set_datadir {
	my $self = shift;
	my $datadir = shift;

	die "No such directory: $datadir" if (!-d $datadir);

	$self->{datadir} = $datadir;

	return $datadir;
}

# Get newsgroup info. Return a hash ref: art_high, art_low, flags

sub group_info {
	my $self = shift;

	die "Newsgroup::group_info() called without a server set" if (!ref $self->{nntp_server});

	my $name = $self->{name};

	my $ref = $self->{nntp_server}->active($name);

	return undef if (!ref $ref);

	my $list = $ref->{$name};

	$self->{group_info} = {
		art_high => $list->[0],
		art_low => $list->[1],
		flags => $list->[2]
	};

	return $ref->{$self->{name}};
}

# return 'y' for unmoderated, or 'm' for moderated group

sub group_flags {
	my $self = shift;

	if (!exists $self->{group_info}) {
		$self->group_info();
	}

	return $self->{group_info}->{flags};
}

# temp procedure

sub debug_it {
	my $ref = shift;
	print "Ref is $ref\n";
	foreach my $v (keys %$ref) {
		print "Key: $v ";
		my $l = $ref->{$v};
		foreach (@$l) {
			print " val $_";
		}
		print "\n";
	}
	print "\n";
}

# Read data from a file, store it in a string and this object's attributes

sub get_attr {
	my $self = shift;
	my $attr_name = shift;

	return $self->{$attr_name} if (exists $self->{$attr_name});

	die "Newsgroup: get_attr() needs prior call to set_datadir()\n" if (!exists $self->{datadir});

	# TODO ...
	my $path = $self->{datadir} . '/' . $self->{name} . '/' . $attr_name;
	return undef if (!-f $path);

	my $fh = new IO::File;
	if (!open($fh, "<$path")) {
		die "Unable to open $path: $!\n";
	}

	my $s;

	while (<$fh>) {
		$s .= $_;
	}

	close($fh);

	return $s;
}

sub set_attr {
	my $self = shift;
	my $attr_name = shift;
	my $string = shift;
	my $reason = shift;

	die "Newsgroup: set_attr() needs prior call to set_datadir()\n" if (!exists $self->{datadir});

	# TODO ...
	my $datadir = $self->{datadir};
	my $path = $datadir . '/' . $self->{name} . '/' . $attr_name;
	my $exists;
	if (-f $path) {
		$exists = 1;
		if (!-f "$path/RCS/$attr_name") {
			# check it in for the first time
			system("ci -l $path < /dev/null");
		}
	} else {
		$exists = 0;
	}

	my $fh = new IO::File;
	if (!open($fh, ">$path")) {
		die "Unable to open $path for write: $!\n";
	}

	print $fh $string;
	
	close($fh);

	if ($exists) {
		# Check in an update, with that message
		system("ci", "-l", "-m$reason", $path);
	} else {
		# Check in initial version, use -t-string
		system("ci", "-l", "-t-$reason", $path);
	}

	# Now write an audit log that we did it ... TODO

	return 0;
}


1;
