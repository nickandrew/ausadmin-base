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

sub set_server {
	my $self = shift;
	my $conn = shift;

	die "Newsgroup::set_server must be given a reference" if (!ref $conn);

	$self->{nntp_server} = $conn;

	return $conn;
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

1;
