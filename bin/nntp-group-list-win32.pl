#!/usr/bin/perl -w
#	@(#) $Header$
#	(C) 2003, Nick Andrew <nick@nick-andrew.net>
#	Connect to a newsserver and get some group lists. Email back to me.
#	Released under GPL
#
#   WIN32 Modifications by Shaun Turner <sajt@tvsched.com> (C) 2003
#	WIN32 modifications require Net::SMTP to function
#	Alter the statement below "mail.example.com" to your ourgoing email server.
#	Check your email client if unsure

use Net::NNTP qw();
use LWP::UserAgent qw();
use Net::SMTP; 

my $cfg = {	
	news_server => $ENV{NNTPSERVER} || 'news.example.com',
	my_email => $ENV{MAIL_FROM} || 'you@example.com',
	my_email_server => $(MAIL_SERVER) || 'mail.example.com'
	email_to => 'ausadmin@aus.news-admin.org',
	hier_url => 'http://aus.news-admin.org/data/monitor.txt',
	now => time(),
	vers => '1.11',
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

	# Change the fileglob type hier name (aus.*)
	# into a proper regex (aus\..*)
	my $hier_regex = $hier;
	$hier_regex =~ s/\./\\./g;
	$hier_regex =~ s/\*/.*/g;

	my $active = $svr->active($hier);

	if ($active) {
		foreach my $ng (keys %$active) {
			next unless ($ng =~ /^$hier_regex$/);
			my $r = $active->{$ng};
			$gl{$ng}->{'last'} = $r->[0];
			$gl{$ng}->{first} = $r->[1];
			$gl{$ng}->{flags} = $r->[2];
		}
	}

	my $ngs = $svr->newsgroups($hier);
	if ($ngs) {
		foreach my $ng (keys %$ngs) {
			next unless (exists $gl{$ng});
			$gl{$ng}->{description} = $ngs->{$ng};
		}
	}

	# Now output all the group data
	$s .= qq~ <hier name="$hier">\n~;

	foreach my $ng (sort (keys %gl)) {
		my $r = $gl{$ng};
		my $desc = $r->{description} || '';
		my $flags = $r->{flags} || '';
		$desc =~ s/%/%25/g;
		$desc =~ s/&/%26/g;
		$desc =~ s/"/%22/g;
		$desc =~ s/\+/%2b/g;
		$s .= qq~  <group name="$ng" description="$desc" flags="$flags" />\n~;
	}

	$s .= qq~ </hier>\n~;

}

$s .= qq~</grouplist>~;

my $ts;
{
	my($sec,$min,$hour,$mday,$mon,$year) = localtime($cfg->{now});
	$mon++; $year += 1900;
	$ts = sprintf ("%04d-%02d-%02d %02d:%02d",$year,$mon,$mday,$hour,$min);
}

sendMailWin($cfg, $s);

exit(0);

sub sendMail {
	my ($cfg, $s) = @_;

	my $smtp = Net::SMTP->new( $cfg->(my_email_server) );
	die "Couldn't connect to server" unless $smtp;

	$smtp->mail( $cfg->{email_to} );  
	$smtp->to( $cfg->{my_email} ); 
	$smtp->data();
	$smtp->datasend("Subject: Data for $cfg->{news_server} at $ts\n");
	$smtp->datasend("\n");
	$smtp->datasend($s);
	$smtp->dataend();
	$smtp->quit();
}
