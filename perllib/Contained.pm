#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
#  A superclass for contained objects

package Contained;

use strict;

sub new {
	my $class = shift;
	my $self = { @_ };

	$self->{vars} = { };

	bless $self, $class;
	return $self;
}

sub setVars {
	my ($self, %hr) = @_;

	if (!defined $self->{vars}) {
		$self->{vars} = { };
	}

	my $vars = $self->{vars};

	foreach my $k (keys %hr) {
		$vars->{$k} = $hr{$k};
	}
}

sub getVar {
	my ($self, $name) = @_;

	my $value = $self->{vars}->{$name};
	if (!defined $value) {
		return '';
	}

	return $value;
}

sub getSQLDB {
	my $self = shift;
	return $self->{container}->getSQLDB();
}

sub getUserName {
	my $self = shift;
	return $self->{container}->getUserName();
}

1;
