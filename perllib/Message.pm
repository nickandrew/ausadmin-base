#	@(#) Message.pm - class for an email message

=head1 NAME

Message.pm - class for an email message

=head1 SYNOPSIS

	use Message;
	my $m = new Message();
	$m->parse_file($filename);
	$m->parse_string($string);

=head1 DESCRIPTION

Use this to read and parse an email message - determine the voting
instructions (if any) and establish information identifying the source
of the message.

=cut

package Message;

sub new {
	my $class = shift;
	my $self = { };
	bless $self, $class;

	return $self;
}

sub parse_string {
	my $self = shift;
	my $string = shift;

	$self->{data} = $string;

	$self->{path} = 'string';

	$self->parse();
}

sub parse_file {
	my $self = shift;
	my $path = shift;

	if (!open(F, "<$path")) {
		die "Unable to open $path for read: $!";
	}

	my $string;

	while (<F>) {
		$string .= $_;
	}

	close(F);

	$self->parse_string($string);

	$self->{path} = $path;

	return 1;
}

sub parse {
	my $self = shift;

	die "Nothing for Message to parse!" if (!defined $self->{data});

	my @lines = split(/\n/, $self->{data});
	my $head = 1;
	my $header;
	my @headers;
	my @votes;

	# Grab the From header
	foreach (@lines) {

		if ($head) {
			if ($_ eq '') {
				push(@headers, $header) if ($header ne '');
				$head = 0;
				next;
			}

			if (/^\s+(.+)/) {
				$header .= ' ' . $1;
				next;
			}

			if (/^((\S+):.*)/) {
				push(@headers, $header) if ($header ne '');
				$header = $1;
			}
		} else {
			# Body
			if (/I vote (\S+) on (\S+)/) {
				push(@votes, [$1, $2]);
			}
		}
	}

	$self->{headers} = \@headers;
	$self->{votes} = \@votes;
}

sub print_headers {
	my $self = shift;

	return if (!$self->{headers});

	foreach (@{$self->{headers}}) {
		print "Hdr: $_\n";
	}
}

=pod

	@header_list = $m->headers();

Return a list of all headers appearing in the message, in their order of
appearance. Extension lines beginning with whitespace are concatenated to
the main header with a single space.

=cut

sub headers {
	my $self = shift;

	return @{$self->{headers}};
}

# lowercase names of headers which we will use to extract info ...

$Message::interesting_headers = {
	'from' => [0, 5, 'name and email of sender', '(.*)', ['junk']],
	'message-id' => [0, 5, 'message id', '(.*)', ['junk']],
	'x-fastmail-ip' => [0, 5, 'ip address of sender', '(.*)', ['ip']],
	'x-freemailid' => [0, 5, 'userid of sender', '(.*)', ['uid']],
	'x-funmail-uid' => [0, 5, 'userid of sender', '(.*)', ['uid']],
	'x-mail-from-ip' => [0, 5, 'ip address of sender', '\[(.*)\]', ['ip']],
	'x-mailer' => [0, 5, 'mail program of sender', '(.*)', ['mailer']],
	'x-mdremoteip' => [0, 5, 'inside firewall source ip', '(.*)', ['ip']],
	'x-originating-ip' => [0, 5, 'ip address of sender', '\[(.*)\]', ['ip']],
	'x-sender-ip' => [0, 5, 'ip address of sender', '(.*)', ['ip']],
	'x-sender' => [0, 5, 'email address of sender', '(.*)', ['email']],
	'x-senders-ip' => [0, 5, 'ip address of sender', '(.*)', ['ip']],
	'x-sent-from' => [0, 5, 'email address of sender'],
	'x-version' => [0, 5, 'freemail software version', '(.*)', ['fm_vers']],
	'x-webmail-userid' => [0, 5, 'userid of sender', '(.*)', ['uid']],
};

# List of IPs which are known to have multiple users (e.g. caches)

my $proxy_ips = [
	['165.228.130.11', 'lon-cache1-1.cache.telstra.net'],
	['203.108.0.57', 'netcachesyd1.ozemail.com.au'],
	['203.164.3.179', 'cfw4-2.rdc1.nsw.excitehome.net.au'],
	['198.142.200.243', 'cache06.syd.optusnet.com.au'],
];

my $freemail_regexes = [
	'Get Your Private, Free E-mail from MSN Hotmail',
	'http://www.start.com.au',
	'http://www.hotmail.com',
	'Do You Yahoo!?',
	'Get your free .* address at',
	'Send a cool gift with your E-Card',
	'--== Sent via Deja.com ==--',
	'http://www.eudoramail.com',
	'http://www.netaddress.com/',
	'20 email addresses from',
	'http://www.another.com',
	'Express yourself @ another.com',
	'http://another.com',
	'http://www.MyOwnEmail.com',
	'Free email with personality! Over 200 domains!',
	'http://www.canoe.ca/CanoeMail',
	'This message was sent using OzBytes Webmail',
	'http://www.evilemail.com',
	'http://mbox.com.au',
	'http://webmail.netscape.com/',
	'http://www.zzn.com',
	'Get your free email from',
	'Get free email and a permanent address at',
	'Get Your Private, Free Email at',
	'http://www.burningmail.com',
	'http://www.icq.com/icqmail/signup.html',
	'Get a FREE email address',
	'http://www.WildEmail.com',
	'http://email.tbwt.com',
	'Get Your FREE E-mail Address',
	'http://www.today.com.au',
	'http://www.cubuffs.com',
];

# Notes on Received headers ... ultraman (qmail) at least, seems to use
# one of the following types:
#  from dns-discovered-hostname (ident-lookup@src-ip-address) by ultra...
#  from some-hostname (src-ip-address) by ultra...
#  from dns-discovered-hostname (HELO what-they-say) (src-ip-address) by ul...
#  from dns-discovered-hostname (HELO what-they-say) (ident-lookup@src-ip-address) by ultra...
#  from unknown (HELO what-they-say) (src-ip-address) by ultra...

# So the general form is:
# from some-hostname (HELO \S+) (\S+@\S+) by \S+ with E?SMTP

my $received_regex = [
	['\(qmail (\d+) invoked from network\);', ['qmail-qid']],
	['\(cpmta (\d+) invoked from network\);', ['cpmta-qid']],
	['\(qmail (\d+) invoked by uid (\d+)\);', ['qmail-qid', 'sender-uid']],

	['\(from (\S+)\) by (\S+) \([0-9./]+\)', ['src-userid', 'dst-hostname']],

	['from mail pickup service by ([a-zA-Z0-9.-]+) with Microsoft SMTPSVC', ['webmail-domain']],

	['from ccMail by (\S+) \(IMA', []],

	# from [a.b.c.d]

	['from  \[([0-9.]+)\] by ([a-zA-Z0-9.-]+);', ['src-ip', 'dst-hostname']],
	['from  \[([0-9.]+)\] by ([a-zA-Z0-9.-]+) ', ['src-ip', 'dst-hostname']],
	['from \[([0-9.]+)\] by (\S+) \(SMTPD32', []],
	['from \[([0-9.]+)\] by (\S+) \(SMTPD32', []],
	['from \[([0-9.]+)\] by (\S+) \(NTMail', []],
	['from \[([0-9.]+)\] by ([a-zA-Z0-9.-]+) with ESMTP', ['src-ip', 'dst-hostname']],

	['from \[([0-9.]+)\] \(helo=(\S+)\) by ([a-zA-Z0-9.-]+)', ['src-ip', 'src-name', 'dst-hostname']],
	['from \[([0-9.]+)\] by ([a-zA-Z0-9.-]+)', ['src-ip', 'dst-hostname']],

	# from hostname(something)

	['from (\S+)\((\S+) ([0-9.]+)\) by ([a-zA-Z0-9.-]+) via smap', ['src-name', 'src-name', 'src-ip']],
	['from (\S+)\((\S+)\), claiming to be "\S+".* by ([a-zA-Z0-9.-]+),', []],
	['from (\S+)\((\S+)\) by ([a-zA-Z0-9.-]+) via smap', []],

	['from (\S+)\(([0-9.]+)\) via SMTP by ([a-zA-Z0-9.-]+),', ['src-name', 'src-ip', 'dst-hostname']],


	['from (\S+) \(\[(.*)\]\) by ([a-zA-Z0-9.-]+)\(', ['src-hostname', 'src-ip', 'dst-hostname']],
	['from (\S+) \[(.*)\] by ([a-zA-Z0-9.-]+) \[(\S+)\] with ', []],

	['from ([a-zA-Z0-9.-]+) \[([0-9.]+)\] by ([a-zA-Z0-9.-]+) with ', ['src-name', 'src-ip', 'dst-hostname']],

	['from ([a-zA-Z0-9.-]+) \[([0-9.]+)\] by ([a-zA-Z0-9.-]+) \((.*)\) .*;', ['src-name', 'src-ip', 'dst-hostname']],

	# this is a webmail thingy
	['from ([0-9.]+) by ([a-zA-Z0-9.-]+) for \[([0-9.]+)\]', ['src-ip', 'dst-hostname', 'src-ip']],

	['from (\S+) by (\S+) \(PMDF', []],
	['from ([0-9.]+) by ([a-zA-Z0-9.-]+) with (HTTP)', ['src-ip', 'dst-hostname', 'webmail-proto']],

	# from something (something [a.b.c.d])

	['from ([a-zA-Z0-9.-]+) \((\S+)@([a-zA-Z0-9.-]+) \[([0-9.]+)\]\) by ([a-zA-Z0-9.-]+)', ['src-name', 'src-userid', 'src-domain', 'src-ip', 'dst-hostname']],
	['from ([a-zA-Z0-9.-]+) \(([a-zA-Z0-9.-]+) \[([0-9.]+)\] \(may be forged\)\) by ([a-zA-Z0-9.-]+)', ['src-name', 'src-hostname', 'src-ip', 'dst-hostname']],
	['from ([a-zA-Z0-9.-]+) \(([a-zA-Z0-9.-]+) \[([0-9.]+)\]\) by ([a-zA-Z0-9.-]+)', ['src-name', 'src-hostname', 'src-ip', 'dst-hostname']],

	# from something (HELO something) (user@a.b.c.d) by something

	['from ([a-zA-Z0-9.-]+) \(HELO ([^)]+)\) \((\S+)@([0-9.]+)\) by ([a-zA-Z0-9.-]+) .*with ', ['src-hostname', 'src-name', 'src-ident', 'src-ip', 'dst-hostname']],
	['from ([a-zA-Z0-9.-]+) \(HELO ([^)]+)\) \(([0-9.]+)\) by ([a-zA-Z0-9.-]+) .*with ', ['src-hostname', 'src-name', 'src-ip', 'dst-hostname']],

	['from ([a-zA-Z0-9.-]+) \((\S+)@([0-9.]+)\) by ([a-zA-Z0-9.-]+) .*with ', ['src-name', 'src-ident', 'src-ip', 'dst-hostname']],

	['from ([a-zA-Z0-9.-]+) \(([0-9.]+)\) by ([a-zA-Z0-9.-]+) .*with ', ['src-name', 'src-ip', 'dst-hostname']],

	# from something ([a.b.c.d])

	['from ([a-zA-Z0-9.-]+) \(\[([0-9.]+)\] helo=([^)]+)\) by ([a-zA-Z0-9.-]+)', ['src-hostname', 'src-ip', 'src-name', 'dst-hostname']],

	['from ([a-zA-Z0-9.-]+) \(\[([0-9.]+)\]\) by ([a-zA-Z0-9.-]+) .*with ', ['src-name', 'src-ip', 'dst-hostname']],

	# from something (a.b.c.d) by something

	['from ([a-zA-Z0-9.-]+) \(([0-9.]+)\) by ([a-zA-Z0-9.-]+) ', ['src-hostname', 'src-ip', 'dst-hostname']],

	['from (\S+) by ([a-zA-Z0-9.-]+) with local', ['src-userid', 'dst-hostname']],


	['from ([a-zA-Z0-9.-]+) \(\[([0-9.]+)\]\) by ([a-zA-Z0-9.-]+) ', ['src-name', 'src-ip', 'dst-hostname']],

	['from \[([0-9.]+)\] \(\[([0-9.]+)\]\) by ([a-zA-Z0-9.-]+)', ['src-fw-ip', 'src-ip', 'dst-hostname']],

	['from ([0-9.]+) by ([0-9.]+) \((WinProxy)\)', ['src-fw-ip', 'dst-fw-ip', 'fw-software']],


	['from ([a-zA-Z0-9.-]+) \(unverified\) by ([a-zA-Z0-9.-]+)', ['src-name', 'dst-hostname']],
	['from ([a-zA-Z0-9.-]+) \(([a-zA-Z0-9.-]+)\) by ([a-zA-Z0-9.-]+)', ['src-name', 'src-hostname', 'dst-hostname']],


	['from localhost \((\S+)@localhost\) by ([a-zA-Z0-9.-]+)', ['src-userid', 'dst-hostname']],


	# this is for AOL

	['from (\S+)@(\S+) by ([a-zA-Z0-9.-]+)', ['src-userid', 'src-domain', 'dst-hostname']],

	['from (\S+) by (\S+) with ', []],
	['from (.*) by ([a-zA-Z0-9.-]+);', [undef, 'dst-hostname']],

	['^by (\S+) \([0-9./]+\)', []],
	['^by ([a-zA-Z0-9.-]+);', ['dst-hostname']],
	['^by (\S+) with Internet Mail Service', ['dst-hostname']],
	['^by (\S+) with Microsoft MAPI', []],
	['^by (\S+) with Microsoft Mail', []],
	['^by (\S+)\(Lotus SMTP MTA', []],
	['^by ([a-zA-Z0-9.-]+) \(Fastmailer, from userid (\d+)\)', ['dst-hostname', 'fastmailer-uid']],
	['^by ([a-zA-Z0-9.-]+) \(Postfix, from userid (\d+)\)', ['dst-hostname', 'postfix-uid']],
	['^by (\S+) \([0-9.]+.*SMI', []],

	['^..by (\S+) ', ['dst-hostname']],
];

sub check_received {
	my $self = shift;
	my $header = shift;
	my $data_hr = { };

	$header =~ s/^Received: //;
	$data_hr->{header} = $header;
	$data_hr->{match} = 0;

	foreach my $r (@$received_regex) {
		my $regex = $r->[0];
		my $hash_map = $r->[1];

		if ($header =~ /$regex/) {

			$data_hr->{match} = 1;
			$data_hr->{regex} = $regex;
			$data_hr->{references} = "$1, $2, $3";

			# Ok, we got something. Now grab the contents and stick in hashref
			my @refs = ($1,$2,$3,$4,$5,$6,$7,$8,$9);

			foreach (@$hash_map) {
				if ($_) {
					push(@{$data_hr->{$_}}, shift @refs);
				} else {
					# This substring match was not required
					shift @refs;
				}
			}

			last;
		}
	}

	return $data_hr;
}

=pod

 print_received_data($data_hash) ...

Print to STDOUT the interesting information we gleaned from a Received header

=cut

sub print_received_data {
	my $self = shift;
	my $data_hash = shift;

	if (!$data_hash->{match}) {
		print "No match: ", $data_hash->{header};
		print "\n";
		return;
	}

	print "Header: ", $data_hash->{header}, "\n";
	print "Matched this regex: ", $data_hash->{regex}, "\n";
	print "References: ", $data_hash->{references}, "\n";

	if ($data_hash->{references} eq ', , ') {
		print "No references (header): ", $data_hash->{header}, "\n";
		print "No references (regex): ", $data_hash->{regex}, "\n";
	}

	# Print out the useful data

	print "The data we got was:\n";
	my $data_count = 0;
	foreach my $v (sort (keys %$data_hash)) {

		# Ignore these ones which are info about the header and not
		# about the data gleaned from it
		next if ($v eq 'header' || $v eq 'match' || $v eq 'references' || $v eq 'regex');


		$data_count++;
		printf "\t%-20s :", $v;
		foreach my $l (@{$data_hash->{$v}}) {
			print ' ', $l;
		}
		print "\n";
	}

	if (!$data_count) {
		print "No data!\n";
	}

	print "\n";
}

=pod

$info_hr = Message::parse_header($string, $how_lr, $data_hr) ...

Extract useful information from this string, using $how_lr (it's a
reference to a list, which is defined in $Message::interesting_headers).

The $string is the value of the header, sans its name.

Update the supplied hashref argument, and return 1 if all this worked,
or 0 if the value didn't match the regex.

=cut

sub parse_header {
	my $string = shift;
	my $how_lr = shift;
	my $data_hr = shift;

	my $regex = $how_lr->[3];
	my $hash_map = $how_lr->[4];

	return undef if (!defined $regex);
	return undef if (!defined $hash_map);

	if ($string =~ /$regex/) {
		# Ok, we got something. Now grab the contents and stick in hashref
		my @refs = ($1,$2,$3,$4,$5,$6,$7,$8,$9);
		foreach (@$hash_map) {
			if ($_) {
				push(@{$data_hr->{$_}}, shift @refs);
			} else {
				# This substring match was not required
				shift @refs;
			}
		}

		return 1;
	}

	# Oops, nothing matched
	return 0;
}


=pod

 header_info() ...

Check every interesting header and extract the data contained in it.
Organise all data by name and return a reference to a hash: the key
is the identifier for the data's meaning, and the value is a reference
to a list of extracted strings for that identifier.

=cut

sub header_info {
	my $self = shift;

	my @header_l = $self->headers();
	my $int_hr = $Message::interesting_headers;
	my $data_hr = { };

	foreach (@header_l) {
		if (/^([^:]+): (.*)/) {
			my $hdr_name = lc($1);
#			print "Checking: $hdr_name\n";
			if (!exists $int_hr->{$hdr_name}) {
				# Not interesting
				next;
			}

			# Hmm. How do we get the data out? A regex!
			Message::parse_header($2, $int_hr->{$hdr_name}, $data_hr);
		} else {
			print "Invalid header: $_\n";
		}
	}

	return $data_hr;
}

=pod

 $data_hr->{'interesting-datatype'} = [ 'value', 'value', ... ]
 print_interesting($data_hr) ...

Output the contents of this interesting data to STDOUT.

=cut

sub print_interesting {
	my $data_hr = shift;

	if (ref $data_hr) {
		print " WOW ...\n";
		foreach my $r (sort (keys %$data_hr)) {
			printf "  %s: ", $r;
			if (ref $data_hr->{$r}) {
				# Value is a list
				foreach (@{$data_hr->{$r}}) {
					printf "%s | ", $_;
				}
				print "\n";
			} elsif (!defined $data_hr->{$r}) {
				print "?\n";
			} else {
				print $data_hr->{$r}, "\n";
			}
		}
		print "\n";
	}
}

1;
