#	@(#) Newsgroup.pm - a newsgroup (existing or not)

=head1 NAME

Newsgroup - a newsgroup

=head1 SYNOPSIS

 use Newsgroup;

 $nntp = new Net::NNTP(...)

 $ng = new Newsgroup(name => 'aus.history', [nntp_server=>$nntp]);
 $bool = Newsgroup::valid_name('aus.history');
 $bool = Newsgroup::validate('aus.history');

 $ng->set_server($nntp)
 $flags = $ng->group_flags()  ... return the 'y' or 'm' status of the group
 
 $ng->set_datadir($path)	... Set the path for accessing newsgroup data
 $string = $ng->get_attr('charter') ... Read the charter data, return as string
 $ng->set_attr('charter', $string, 'Update reason') ...

 $string = $ng->gen_newgroup($control_type);	... Create a control msg

 $signed_text = $ng->sign_control($unsigned_text) ... Sign a control msg

 my @newsgroup_list = Newsgroup::list_newsgroups(datadir => $datadir);
 	# returns a list of newsgroups in that directory

 $ng->create();
	# Creates the directory for a new newsgroup

=cut

package Newsgroup;

use IO::File;
use IPC::Open2;
use Carp qw(confess);

use Ausadmin;

$Newsgroup::DEFAULT_NEWSGROUP_DIR	= './data/Newsgroups';

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;

	die "No name" if (!exists $self->{name});

	$self->{datadir} ||= $Newsgroup::DEFAULT_NEWSGROUP_DIR;

	return $self;
}

# ---------------------------------------------------------------------------
# Check the newsgroup name for compliance with international newsgroup standards.
# ---------------------------------------------------------------------------

sub valid_name {
	my $ng_name = shift;

	# NOTE ... this allows no single-group hierarchies
	return 1 if ($ng_name =~ /^[a-z0-9+-]+\.[a-z0-9+-]+(\.[a-z0-9+-]+)*$/);

	return 0;
}

# ---------------------------------------------------------------------------
# Check the newsgroup name for compliance with ausadmin naming (including a
# group date at the end, after a colon)
# ---------------------------------------------------------------------------

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
		if (!-f "$datadir/$self->{name}/RCS/$attr_name,v") {
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

# gen_newgroup() ... Generate a newgroup message for this group

sub gen_newgroup {
	my $self = shift;

	# $control_type = [booster|initial]
	my $control_type = shift || confess('Missing parameter in call to gen_newgroup');

	my $hier_name = $self->{hier_name};
	my $name = $self->{name};

	my $template_path = "config/${control_type}.template";
	my $template2_path = "config/${hier_name}.control.ctl";
	my $ngline_path = "$self->{datadir}/$self->{name}/ngline";

	if (! -f $template_path) {
		confess("$control_type template file does not exist");
	}

	if (! -f $ngline_path) {
		confess("$ngline_path does not exist, required for a newgroup");
	}

	my $template = Ausadmin::readfile($template_path);
	my $control_ctl = Ausadmin::readfile($template2_path);
	my $ngline = Ausadmin::read1line($ngline_path);

	my $moderated = 0;		# FIXME ... a safe assumption!

	my $control;
	my $modname;

	if ($moderated) {
		$control = "newgroup $name m";
		$modname = "a moderated";
	} else {
		$control = "newgroup $name";
		$modname = "an unmoderated";
	}

	my $post = eval $template;

	return $post;
}

sub sign_control {
	my $self = shift;
	my $unsigned = shift || confess("No message given to sign_control()");

	# I don't like calling perl code from other perl code. I prefer
	# putting it in a module. But signcontrol is too messy to include
	# verbatim, so I'll just use it as a filter.

	my $fh_r = new IO::File;
	my $fh_w = new IO::File;
	my $pid = open2($fh_r, $fh_w, "signcontrol");

	# Output the unsigned text to the write file handle

	print $fh_w $unsigned;

	# and close it to make the process's output available
	close($fh_w);

	my @return = <$fh_r>;

	return join('', @return);
}

# Return a list of all newsgroups in the directory
#
sub list_newsgroups {
	my $args = { @_ };

	my $datadir = $args->{datadir} || $Newsgroup::DEFAULT_NEWSGROUP_DIR;

	if (! $datadir) {
		confess "No datadir";
	}

	# Ignore newsgroup names not containing a dot, and . and ..
	opendir(D, $datadir);
	my @files = grep { ! /^\.|^[a-zA-Z0-9-]+$/ } readdir(D);
	closedir(D);

	my @list;

	foreach my $f (sort @files) {
		my $path = "$datadir/$f";
		next if (! -d $path);
		# It is not a newsgroup if there's no "ngline" file
		# (later) next if (! -f "$path/ngline");
		push(@list, $f);
	}

	return @list;
}

sub create {
	my $self = shift;

	die "Newsgroup: create() needs prior call to set_datadir()\n" if (!exists $self->{datadir});

	my $dir = "$self->{datadir}/$self->{name}";

	if (!-d $dir) {
		mkdir($dir, 0755);
	}

	if (!-d "$dir/RCS") {
		mkdir("$dir/RCS", 0755);
	}

}

1;
