#!/usr/bin/perl -w
#	@(#) $Header$

package VoterState;

use strict;

my $voters_file = "$ENV{HOME}/data/voter-state";

sub randomCheckID {

	if (!open(RAND, "</dev/urandom")) {
		die "Unable to open /dev/urandom for read: $!";
	}

	my $bytes_left = 5;
	my $check_id = '';

	while ($bytes_left > 0) {
		my $buffer;
		my $n = sysread(RAND, $buffer, $bytes_left);
		if ($n < 0) {
			die "Read error on /dev/urandom: $!";
		}
		elsif ($n > 0) {
			$bytes_left -= $n;
			$check_id .= unpack("H*", $buffer);
		}

	}
	close(RAND);

	return $check_id;
}

sub new {
	my $class = shift;
	my $self = { };

	$self->{voters_file} ||= $voters_file;

	bless $self, $class;
	return $self;
}

sub load {
	my $self = shift;

	return if (defined $self->{data});

	my $path = $self->{voters_file};

	my $data = { };

	if (!open(VF, "<$path")) {
		die "Unable to open $path for read: $!";
	}

	while (<VF>) {
		chomp;
		my($email,$timestamp,$state,$check_id) = split;

		$data->{$email} = {
			timestamp => $timestamp,
			state => $state,
			check_id => $check_id,
		};
	}
	close(VF);

	$self->{data} = $data;
}

sub save {
	my $self = shift;

	return if (!defined $self->{data});
	return if (!$self->{updated});

	my $path = $self->{voters_file};

	my $data = $self->{data};

	if (!open(VF, ">$path.$$")) {
		die "Unable to open $path.$$ for write: $!";
	}

	foreach my $email (sort (keys %$data)) {

		my $r = $data->{$email};

		print VF join(' ',
			$email,
			$r->{timestamp},
			$r->{state},
			$r->{check_id}
		), "\n";
	}

	close(VF);

	rename("$path.$$", "$path");

	$self->{updated} = 0;
}

sub checkEmail {
	my ($self, $email) = @_;

	$self->load();

	return $self->{data}->{$email};
}

sub getCheckRef {
	my ($self, $email) = @_;

	$self->load();

	my $r = $self->{data}->{$email};

	if (defined $r && ($r->{check_id} eq '' || $r->{check_id} eq '-OLD-')) {
		# Assign only check_id
		$r->{check_id} = randomCheckID();
		$self->{updated} = 1;
	}

	if (!defined $r) {
		$self->{data}->{$email} = $r = {
			timestamp => time(),
			state => 'NEW',
			check_id => randomCheckID(),
		};
		$self->{updated} = 1;
	}

	return $r;
}

sub idToEmail {
	my($self, $check_id) = @_;

	$self->load();

	foreach my $email (keys %{$self->{data}}) {
		if ($self->{data}->{$email}->{check_id} eq $check_id) {
			return $email;
		}
	}

	return undef;
}

sub setState {
	my($self, $email, $state) = @_;

	$self->load();

	if (exists $self->{data}->{$email}) {
		$self->{data}->{$email}->{state} = $state;
		return;
	}

	die "No state known for $email";
}

sub getState {
	my($self, $email) = @_;

	if (exists $self->{data}->{$email}) {
		return $self->{data}->{$email}->{state};
	}

	return undef;
}

sub set {
	my($self, $email, $key, $value) = @_;

	if (!exists $self->{data}->{$email}) {
		die "No such voter: $email";
	}

	$self->{data}->{$email}->{$key} = $value;
}

1;
