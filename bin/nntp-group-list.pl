#!/usr/bin/perl -w
#	@(#) $Header$
#	(C) 2003, Nick Andrew <nick@nick-andrew.net>
#	Connect to a newsserver and get some group lists. Email back to me.
#	Released under GPL

use Net::NNTP qw();

my $cfg = {
	news_server => 'freenews.iinet.net.au',
	my_email => 'you@example.com',
	email_to => 'ausadmin@aus.news-admin.org',
	hier_url => 'http://aus.news-admin.org/monitor.txt',
	now => time(),
};

my @hiers = ('aus.*', 'bne.*', 'canb.*');

my $svr = new Net::NNTP($cfg->{news_server}) || die "Unable to connect to $cfg->{news_server}";
$svr->reader() or die "mode reader command failed";

my $config = join(' ', (map { "$_=\"$cfg->{$_}\"" } (sort (keys %$cfg))));

my $s = qq~<grouplist $config >\n~;


foreach my $hier (@hiers) {
	$s .= qq~ <hier name="$hier">\n~;
	my %gl;

	my $active = $svr->active($hier);
	if ($active) {
		foreach my $ng (keys %$active) {
			my $r = $active->{$ng};
			$gl{$ng}->{'last'} = $r->[0];
			$gl{$ng}->{first} = $r->[1];
			$gl{$ng}->{flags} = $r->[2];
		}
	}

	my $ngs = $svr->newsgroups($hier);
	if ($ngs) {
		foreach my $ng (keys %$ngs) {
			$gl{$ng}->{description} = $ngs->{$ng};
		}
	}

	# Now output all the group data

	foreach my $ng (sort (keys %gl)) {
		my $r = $gl{$ng};
		my $desc = $r->{description};
		$desc =~ s/%/%25/g;
		$desc =~ s/&/%26/g;
		$desc =~ s/"/%22/g;
		$desc =~ s/\+/%2b/g;
		$s .= qq~  <group name="$ng" description="$desc" flags="$r->{flags}" />\n~;
	}

	$s .= qq~ </hier>\n~;

}

$s .= qq~</grouplist>\n~;

print $s;
exit(0);
