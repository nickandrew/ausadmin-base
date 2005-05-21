#!/usr/bin/perl
#	SQLdb.pm - An SQL database connection
#
# $Source$
# $Revision$
# $Date$
#
# Rationale: Environment variables dictate which database is being accessed
# (local/remote and userid). Password is derived from control file (the
# unix per-user access rules limit access here).

package SQLdb;

use Carp qw(carp croak confess);
use DBI;

# ---------------------------------------------------------------------------
# Create a new instance of SQLdb and return it
# ---------------------------------------------------------------------------

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;

	$self->{database} ||= $ENV{SQL_DATABASE};
	$self->{user} ||= $ENV{SQL_USER};
	$self->{password} ||= $ENV{SQL_PASSWORD};

	$self->{database} || croak "Need database";

	$self->getDBH();

	return $self;
}

sub getDBH {
	my($self) = @_;

	if (defined $self->{dbh}) {
		return $self->{dbh};
	}

	my $database = $self->{database} || die "Need database";

	my $dbh = DBI->connect(
		"dbi:mysql:database=$self->{database}",
		$self->{user},
		$self->{password},
		{ PrintError => 0, RaiseError => 1, AutoCommit => 0, }
	);

	if (!defined $dbh) {
		die "Unable to connect";
	}

	$self->{dbh} = $dbh;

	return $dbh;
}

sub load_rows {
	my($self, $table, $args, @args) = @_;

	my $dbh = $self->getDBH();
	my $stmt = "SELECT * FROM $table";
	$stmt .= " WHERE $args->{cond}" if ($args->{cond});
	$stmt .= " ORDER BY $args->{order}" if ($args->{order});
	$stmt .= " LIMIT $args->{limit}" if ($args->{limit});

	return $self->fetchall_hashref($stmt, @args);
}


sub select {
	my($self, $stmt, @args) = @_;

	my $dbh = $self->getDBH();

	my $sth = $dbh->prepare("SELECT " . $stmt);
	my $rows;
	eval {
		$rows = $sth->execute(@args);
	};
	if ($@) {
		confess $@;
	}

	my $results = $sth->fetchall_arrayref();

	$sth->finish();

	return $results;
}

sub extract {
	my($self, $stmt, @args) = @_;

	my $dbh = $self->getDBH();

	my $sth = $dbh->prepare($stmt);
	my $rows;
	eval {
		$rows = $sth->execute(@args);
	};
	if ($@) {
		confess $@;
	}

	my $results = $sth->fetchall_arrayref();

	$sth->finish();

	return $results;
}


sub fetchall_hashref {
	my($self, $stmt, @args) = @_;

	my $dbh = $self->{dbh};

	my $sth = $dbh->prepare($stmt);
	eval {
		$sth->execute(@args);
	};

	if ($@) {
		confess "execute($stmt) failed: " . $sth->errstr();
	}

	my @rows;
	my $row;

	while ($row = $sth->fetchrow_hashref()) {
		push(@rows, $row);
	}

	$sth->finish();

	return \@rows;
}

sub execute {
	my($self, $stmt, @args) = @_;

	my $dbh = $self->getDBH();

	my $sth = $dbh->prepare($stmt);
	my $rc = $sth->execute(@args);

	$sth->finish();

	return $rc;
}

sub fetch1 {
	my $self = shift;
	my $stmt = shift;

	my $dbh = $self->{dbh};

	my $sth = $dbh->prepare($stmt);
	if (! $sth) {
		confess "Unable to prepare ($stmt): " . $dbh->errstr();
	}

	eval {
		$sth->execute(@_);
	};

	if ($@) {
		croak "Statement execute failed: ($stmt) (@_): ($@)";
	}

	my $row = $sth->fetchrow_arrayref();
	$sth->finish();
	if ($row) {
		return $row->[0];
	}
	return undef;
}


sub DESTROY {
	my $self = shift;

	if ($self->{dbh}) {
		$self->{dbh}->disconnect();
	}
}

# ---------------------------------------------------------------------------
# $sqldb->insert($table, %data) ... insert a row
# ---------------------------------------------------------------------------

sub insert {
	my($self, $table, %data) = @_;

	my $dbh = $self->{dbh};

	# Build an SQL insert statement
	my @fields = sort (keys %data);

	my $sql = "INSERT INTO $table (" .
		join(',', @fields) .
		') values (' .
		join(',',
			(map { '?' } @fields)) .
		')';

	my $sth = $dbh->prepare($sql);
	die "SQL error ($sql)" if (!defined $sth);

	# Now build the bind list
	my @bindlist = map { $data{$_} } @fields;

	my $rc;
	eval {
		$rc = $sth->execute(@bindlist);
	};

	if ($@ || $rc != 1) {
		my $bl = join(',', map { defined $_ ? $_ : 'undef' } @bindlist);
		croak "Insert $table (@fields) failed ($@), bindlist ($bl)";
	}

	return $dbh->{mysql_insertid};
}

sub commit {
	$_[0]->{dbh}->commit();
}

1;
