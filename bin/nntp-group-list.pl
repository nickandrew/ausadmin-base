#!/usr/bin/perl -w
#	@(#) $Header$
#	(C) 2003, Nick Andrew <nick@nick-andrew.net>
#	Connect to a newsserver and get some group lists. Email back to me.
#	Released under GPL

use Net::NNTP qw();
use LWP::UserAgent qw();

my $cfg = {
	news_server => $ENV{NNTPSERVER} || 'news.example.com',
	my_email => $ENV{MAIL_FROM} || 'you@example.com',
	email_to => 'ausadmin@aus.news-admin.org',
	hier_url => 'http://aus.news-admin.org/data/monitor.txt',
	now => time(),
	vers => '$Revision$',
};

# Grab the list of hierarchies to monitor
my $ua = new LWP::UserAgent();
my $response = $ua->get($cfg->{hier_url});
if (! $response->is_success()) {
	die "Unable to connect to $cfg->{hier_url} to download the list of hierarchies";
}
my @hiers = split(/\s+/, $response->content());

my $svr = new Net::NNTP($cfg->{news_server}) || die "Unable to connect to $cfg->{news_server}";
$svr->reader() or die "mode reader command failed";

my $config = join(' ', (map { "$_=\"$cfg->{$_}\"" } (sort (keys %$cfg))));

my $s = qq~<grouplist $config >\n~;

foreach my $hier (@hiers) {
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

	next unless (%gl);

	# Now output all the group data
	$s .= qq~ <hier name="$hier">\n~;

	foreach my $ng (sort (keys %gl)) {
		my $r = $gl{$ng};
		my $desc = $r->{description} || '';
		$desc =~ s/%/%25/g;
		$desc =~ s/&/%26/g;
		$desc =~ s/"/%22/g;
		$desc =~ s/\+/%2b/g;
		$s .= qq~  <group name="$ng" description="$desc" flags="$r->{flags}" />\n~;
	}

	$s .= qq~ </hier>\n~;

}

$s .= qq~</grouplist>\n~;

my $ts;
{
	my($sec,$min,$hour,$mday,$mon,$year) = localtime($cfg->{now});
	$mon++; $year += 1900;
	$ts = sprintf ("%04d-%02d-%02d %02d:%02d",$year,$mon,$mday,$hour,$min);
}

open(P, "|/usr/sbin/sendmail $cfg->{email_to}") || die "Unable to open pipe to sendmail";
print P <<EOF;
From: $cfg->{my_email}
To: $cfg->{email_to}
Subject: Data for $cfg->{news_server} at $ts

$s
EOF
close(P);

exit(0);
