#!/usr/bin/perl -w
#	@(#) $Id$
#	vim:sw=4:ts=4:
#
#  SignControl.pm - Nick Andrew
#
#  Based on version 1.8 of signcontrol
#    written April 1996, tale@isc.org (David C Lawrence)
#    Currently maintained by Russ Allbery <rra@stanford.edu>

package SignControl;

use strict;

use Data::Dumper qw(Dumper);
use Fcntl qw(F_SETFD);
use FileHandle;
use IPC::Open3 qw(open3);
use POSIX qw(setlocale strftime LC_TIME);
use Text::Tabs;                 # to get 'expand' for tabs in checkgroups

# ---------------------------------------------------------------------------
# Create a new instance of a signing object
# ---------------------------------------------------------------------------

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;

	$self->{pgpsigner} ||= 'ausadmin@aus.news-admin.org';

	# STORING YOUR PASS PHRASE IN A FILE IS A POTENTIAL SECURITY HOLE.
	# make sure you know what you're doing if you do it.
	# if you don't use pgppassfile, you can only use this script interactively.
	# if you DO use pgppassfile, it is possible that someone could steal
	#  your passphrase either by gaining access to the file or by seeing
	#  the environment of a running pgpverify program.

	$self->{pgppassfile} ||= '';      # file with pass phrase for $pgpsigner

	# pgp_command can be set to the path to GnuPG to use GnuPG instead.  The program
	# name needs to end in gpg so that signcontrol knows GnuPG is being used.
	$self->{pgp_command} ||= "/usr/bin/gpg";

	# pgplock is used because pgp does not guard itself against concurrent
	# read/write access to its randseed.bin file.  A writable file is needed;
	# The default value is to use the .pgp/config.txt file in the home
	# directory of the user running the program.  Note that this will only
	# work to lock against other instances of signcontrol, not all pgp uses.
	# pgplock is not used if $pgp ends in 'gpg' since GnuPG doesn't need
	# this.

	$self->{pgplock} ||= (getpwuid($<))[7] . '/.pgp/config.txt';

	# these headers are acceptable in input, but they will be overwritten with
	# these values.  no sanity checking is done on what you put here.  also,
	# Subject: is forced to be the Control header prepending by "cmsg".  also,
	# Newsgroups: is forced to be just the group being added/removed.
	#             (but is taken as-is for checkgroups)
	$self->{force}->{'Path'} = 'bounce-back';
	$self->{force}->{'From'} = 'aus Newsgroups Administration <ausadmin@aus.news-admin.org>';
	$self->{force}->{'Approved'} = 'ausadmin@aus.news-admin.org';
	$self->{force}->{'X-Info'}='ftp://ftp.isc.org/pub/pgpcontrol/README.html' . "\n\t" . 'ftp://ftp.isc.org/pub/pgpcontrol/README';
	$self->{force}->{'X-Aussies'} = 'See http://aus.news-admin.org/ for Australian newsgroup information';

	# host for message-id; this could be determined automatically based on
	# where it is run, but consistency is the goal here

	$self->{id_host} ||= 'aus.news-admin.org';

	# this program tries to help you out by not letting you sign erroneous
	# names, especially ones that are so erroneous they run afoul of naming
	# standards.
	#
	# set to match only hierarchies you will use it on
	# include no '|' for a single hierarchy (eg, "$hierarchies = 'uk';").

	$self->{hierarchies} ||= 'aus|bne|canb|melb|syd|wa';

	return $self;
}

# headers to sign.  Sender is included because non-PGP authentication uses
# it.  The following should always be signed:
#  Subject    -- some older news systems use it to identify the control action.
#  Control    -- most news systems use this to determine what to do.
#  Message-ID -- guards against replay attacks.
#  Date       -- guards against replay attacks.
#  From       -- used by news systems as part of authenticating the message.
#  Sender     -- used by news systems as part of authenticating the message.
my @signheaders = ('Subject', 'Control', 'Message-ID', 'Date', 'From', 'Sender');

# headers to remove from real headers of final message.
# If it is a signed header, it is signed with an empty value.
# set to () if you do not want any headers removed.
my @ignoreheaders = ('Sender');

# headers that will appear in final message, and their order of
# appearance.  all _must_ be set, either in input or via the $force{} and
# $use_or_add{} variables above.
# (exceptions: Date, Lines, Message-ID are computed by this program)
# if header is in use_or_add with a null value, it will not appear in output.
# several are required by the news article format standard; if you remove
# these, your article will not propagate:
#   Path, From, Newsgroups, Subject, Message-ID, Date
# if you take out these, your control message is not very useful:
#   Control, Approved
# any headers in @ignoreheaders also in @orderheaders are silently dropped.
# any non-null header in the input but not in @orderheaders or @ignoreheaders
#   is an error.
# null headers are silently dropped.
my @orderheaders =
  ('Path', 'From', 'Newsgroups', 'Subject', 'Control', 'Approved',
   'Message-ID', 'Date', 'Lines', 'X-Info', 'X-PGP-Sig');

# the draft news article format standard says:
#   "subsequent components SHOULD begin with a letter"
# where "SHOULD" means:
#   means that the item is a strong recommendation: there may be
#   valid reasons to ignore it  in  unusual  circumstances,  but
#   this  should  be  done  only after careful study of the full
#   implications and a firm conclusion  that  it  is  necessary,
#   because  there are serious disadvantages to doing so. 
# as opposed to "MUST" which means:
#   means that the item is an absolute requirement of the specification
# MUST is preferred, but might not be acceptable if you have legacy
# newsgroups that have name components that begin with a letter, like
# news.announce.newgroups does with comp.sys.3b1 and 17 other groups.

my $start_component_with_letter = 'MUST';

## END CONFIGURATION

sub signMessage {
	my ($self, $headers, $body) = @_;

	my $pgp = $self->{pgp_command};
	my $pgplock = $self->{pgplock};

	if ($pgp !~ /gpg$/) {
		open(LOCK, ">>$pgplock") || die "$0: open $pgplock: $!, exiting\n";
		flock(LOCK, 2);               # block until locked
	}

	$self->setgrouppat();

	$self->readhead($headers);
	$self->readbody($headers, $body);

	my $message = $self->signit($headers, $body);

	if ($pgp !~ /gpg$/) {
		close(LOCK) || warn "$0: close $pgplock: $!\n";
	}

	return $message;
}

# ---------------------------------------------------------------------------
# Create a regex to match a newsgroup name within the allowed hierarchies.
# ---------------------------------------------------------------------------

sub setgrouppat {
	my $self = shift;

	# newsgroup name checks based on RFC 1036bis (not including encodings) rules:
	#  "component MUST contain at least one letter"
	#  "[component] MUST not contain uppercase letters"
	#  "[component] MUST begin with a letter or digit"
	#  "[component] MUST not be longer than 14 characters"
	#  "sequences 'all' and 'ctl' MUST not be used as components"
	#  "first component MUST begin with a letter"
	# and enforcing "subsequent components SHOULD begin with a letter" as MUST
	# and enforcing at least a 2nd level group (can't use to newgroup "general")
	#
	# DO NOT COPY THIS PATTERN BLINDLY TO OTHER APPLICATIONS!
	#   It has special construction based on the pattern it is finally used in.

	my $plain_component = '[a-z][-+_a-z\d]{0,13}';
	my $no_component = '(.*\.)?(all|ctl)(\.|$)';
	my $must_start_letter = '(\.' . $plain_component . ')+';
	my $should_start_letter = '(\.(?=\d*[a-z])[a-z\d]+[-+_a-z\d]{0,13})+';

	my $hierarchies = $self->{hierarchies};
	$self->{grouppat} = "(?!$no_component)($hierarchies)";
	if ($start_component_with_letter eq 'SHOULD') {
		$self->{grouppat} .= $should_start_letter;
	} elsif ($start_component_with_letter eq 'MUST') {
		$self->{grouppat} .= $must_start_letter;
	} else {
		die "$0: unknown value configured for \$start_component_with_letter\n";
	}

	foreach my $hierarchy (split(/\|/, $hierarchies)) {
		if ($hierarchy !~ /^$plain_component$/o) {
			die "$0: hierarchy name $hierarchy not standards-compliant\n"
		}
	}

	my $grouppat = $self->{grouppat};
	my $eval = "\$_ = 'test'; /$grouppat/;";
	eval $eval;
	die "$0: bad regexp for matching group names:\n $@" if $@;
}


sub readhead {
	my ($self, $headers) = @_;

	foreach my $k (keys %$headers) {
		if (!defined $headers->{$k}) {
			die "Header $k is undefined";
		}
		$headers->{$k} =~ s/^\s+//;
		$headers->{$k} =~ s/\s+$//;
	}

	my $id_host = $self->{id_host};
	$headers->{'Message-ID'} = '<' . time . ".$$\@$id_host>";

	setlocale(LC_TIME, "C");
	$headers->{'Date'} = strftime("%a, %d %h %Y %T -0000", gmtime());

	foreach (@ignoreheaders) {
		die "ignored header $_ also has forced value set\n" if ($self->{force}->{$_});
		$headers->{$_} = '';
	}

	foreach (@orderheaders) {
		$headers->{$_} = $self->{force}->{$_} if defined($self->{force}->{$_});
	}

	my $action = '';
	my $group = '';
	my $moderated = '';
	my $grouppat = $self->{grouppat};

	if ($headers->{'Control'}) {
		if ($headers->{'Control'} =~ /^(new)group (\S+)( moderated)?$/o ||
				$headers->{'Control'} =~ /^(rm)group (\S+)()$/o ||
				$headers->{'Control'} =~ /^(check)groups()()$/o) {
			($action, $group, $moderated) = ($1, $2, $3);
			die "group name $group is not standards-compliant\n"
				if $group !~ /^$grouppat$/ && $action eq 'new';
			die "no group to rmgroup on Control: line\n"
				if ! $group && $action eq 'rm';
			$headers->{'Subject'} = "cmsg $headers->{'Control'}";
			$headers->{'Newsgroups'} = $group unless $action eq 'check';
		} else {
			die "$0: bad Control format: $headers->{'Control'}\n";
		}
	} else {
		die "$0: can't verify message content; missing Control header\n";
	}

	$self->{action} = $action;
	$self->{group} = $group;
	$self->{moderated} = $moderated;

}

sub readbody {
	my ($self, $headers, $body) = @_;

	$headers->{'Lines'} = $body =~ tr/\n/\n/ if $body;

	my $action = $self->{action};
	my $group = $self->{group};
	my $moderated = $self->{moderated};

	# the following tests are based on the structure of a
	# news.announce.newgroups newgroup message; even if you comment out the
	# "first line" test, please leave the newsgroups line and moderators
	# checks

	if ($action eq 'new') {
		my $status = $moderated ? 'a\smoderated' : 'an\sunmoderated';
		die "nonstandard first line in body for $group\n"
			if ! ($body =~ /^\Q$group\E\sis\s$status\snewsgroup\b/);

		my $intro = "For your newsgroups file:\n";
		# my $regexp = "$intro\Q$group\E[ \t]+(.+)";
		my $regexp = "For your newsgroups file:\n";
		if ($body !~ /$regexp/mi) {
			die "body ($body) does not comply with regexp ($regexp)\n";
		}

		my $ngline =
			($body =~ /$intro\Q$group\E[ \t]+(.+)\n(\n|\Z(?!\n))/mi)[0];

		if ($ngline) {
			$_ = $group;
			my $desc = $1;

			my $fixline = $_;
			$fixline .= "\t" x ((length) > 23 ? 1 : (4 - ((length) + 1) / 8));

			my $used = (length) < 24 ? 24 : (length) + (8 - (length) % 8);
			$used--;

			$desc =~ s/ \(Moderated\)//i;
			$desc =~ s/\s+$//;
			$desc =~ s/\w$/$&./;
			die "$0: $group description too long\n" if $used + length($desc) > 80;

			$fixline .= $desc;
			$fixline .= ' (Moderated)' if $moderated;
			$body =~ s/^$intro(.+)/$intro$fixline/mi;
		} else {
			die "$group newsgroup line not formatted correctly ($intro) ($group) ($body)\n";
		}

		# moderator checks are disabled; some sites were trying to
		# automatically maintain aliases based on this, which is bad policy.

		if (0 && $moderated) {
			die "$group submission address not formatted correctly\n"
				if $body !~ /\nGroup submission address:   ?\S+@\S+\.\S+\n/m;
			my $mods = "( |\n[ \t]+)\\([^)]+\\)\n\n";
			die "$group contact address not formatted correctly\n"
				if $body !~ /\nModerator contact address:  ?\S+@\S+\.\S+$mods/m;
		}
	}

	# rmgroups have freeform bodies

	# checkgroups have structured bodies
	if ($action eq 'check') {
		for (split(/\n/, $body)) {
			my ($group, $description) = /^(\S+)\t+(.+)/;
			die "no group:\n  $_\n"           unless $group;
			die "no description:\n  $_\n"     unless $description;
			my $grouppat = $self->{grouppat};
			die "bad group name \"$group\"\n" if $group !~ /^$grouppat$/;
			die "tab in description\n"        if $description =~ /\t/;
			s/ \(Moderated\)$//;
			die "$group line too long\n"      if length(expand($_)) > 90;
		}
	}
}

# Create a detached signature for the given data.  The first argument
# should be a key id, the second argument the PGP passphrase (which may be
# null, in which case PGP will prompt for it), and the third argument
# should be the complete message to sign.
#
# In a scalar context, the signature is returned as an ASCII-armored block
# with embedded newlines.  In array context, a list consisting of the
# signature and the PGP version number is returned.  Returns undef in the
# event of an error, and the error text is then stored in @ERROR.
#
# This function is taken almost verbatim from PGP::Sign except the PGP
# style is determined from the name of the program used.

sub pgp_sign {
  my ($self, $keyid, $passphrase, $message) = @_;

  # Ignore SIGPIPE, since we're going to be talking to PGP.
  local $SIG{PIPE} = 'IGNORE';

  # Determine the PGP style.
  my $pgpstyle = 'PGP2';
  my $pgp = $self->{pgp_command};

  if    ($pgp =~ /pgps$/) { $pgpstyle = 'PGP5' }
  elsif ($pgp =~ /gpg$/)  { $pgpstyle = 'GPG'  }

  # Figure out what command line we'll be using.  PGP v6 and PGP v2 use
  # compatible syntaxes for what we're trying to do.  PGP v5 would have,
  # except that the -s option isn't valid when you call pgps.  *sigh*
  my @command;
  if ($pgpstyle eq 'PGP5') {
    @command = ($pgp, qw/-baft -u/, $keyid);
  } elsif ($pgpstyle eq 'GPG') {
    @command = ($pgp, qw/--detach-sign --armor --textmode -u/, $keyid,
                qw/--force-v3-sigs --pgp2/);
  } else {
    @command = ($pgp, qw/-sbaft -u/, $keyid);
  }

  # We need to send the password to PGP, but we don't want to use either
  # the command line or an environment variable, since both may expose us
  # to snoopers on the system.  So we create a pipe, stick the password in
  # it, and then pass the file descriptor to PGP.  PGP wants to know about
  # this in an environment variable; GPG uses a command-line flag.
  # 5.005_03 started setting close-on-exec on file handles > $^F, so we
  # need to clear that here (but ignore errors on platforms where fcntl or
  # F_SETFD doesn't exist, if any).
  #
  # Make sure that the file handles are created outside of the if
  # statement, since otherwise they leave scope at the end of the if
  # statement and are automatically closed by Perl.
  my $passfh = new FileHandle;
  my $writefh = new FileHandle;
  local $ENV{PGPPASSFD};
  if ($passphrase) {
    pipe ($passfh, $writefh);
    eval { fcntl ($passfh, F_SETFD, 0) };
    print $writefh $passphrase;
    close $writefh;
    if ($pgpstyle eq 'GPG') {
      push (@command, '--batch', '--passphrase-fd', $passfh->fileno);
    } else {
      push (@command, '+batchmode');
      $ENV{PGPPASSFD} = $passfh->fileno;
    }
  }

  # Fork off a pgp process that we're going to be feeding data to, and tell
  # it to just generate a signature using the given key id and pass phrase.
  my $pgp_fh = new FileHandle;
  my $signature = new FileHandle;
  my $errors = new FileHandle;
  my $pid = eval { open3 ($pgp_fh, $signature, $errors, @command) };
  if ($@) {
    die "$@ Execution of $command[0] failed.\n";
    return undef;
  }

  # Write the message to the PGP process.  Strip all trailing whitespace
  # for compatibility with older pgpverify and attached signature
  # verification.
  $message =~ s/[ \t]+\n/\n/g;
  print $pgp_fh $message;

  # All done.  Close the pipe to PGP, clean up, and see if we succeeded.
  # If not, save the error output and return undef.
  close $pgp_fh;

  local $/ = "\n";
  my @errors = <$errors>;
  my @signature = <$signature>;
  close $signature;
  close $errors;
  close $passfh if $passphrase;
  waitpid ($pid, 0);
  if ($? != 0) {
    die "@errors $command[0] returned exit status $?";
  }

  # Now, clean up the returned signature and return it, along with the
  # version number if desired.  PGP v2 calls this a PGP MESSAGE, whereas
  # PGP v5 and v6 and GPG both (more correctly) call it a PGP SIGNATURE,
  # so accept either.
  while ((shift @signature) !~ /-----BEGIN PGP \S+-----\n/) {
    unless (@signature) {
      die "No signature from PGP (command not found?)";
    }
  }
  my $version;
  while ($signature[0] ne "\n" && @signature) {
    $version = $1 if ((shift @signature) =~ /^Version:\s+(.*?)\s*$/);
  }
  shift @signature;
  pop @signature;
  $signature = join ('', @signature);
  chomp $signature;
  return wantarray ? ($signature, $version) : $signature;
}

sub signit {
	my ($self, $headers, $body) = @_;

  # Form the message to be signed.
  my $signheaders = join(",", @signheaders);
  my $head = "X-Signed-Headers: $signheaders\n";
  foreach my $header (@signheaders) {
    $head .= "$header: $headers->{$header}\n";
  }

  my $message = "$head\n$body";

  # Get the passphrase if available.
  my $passphrase;
  my $pgppassfile = $self->{pgppassfile};

  if ($pgppassfile && -f $pgppassfile) {
    $pgppassfile =~ s%^(\s)%./$1%;
    if (open (PGPPASS, "< $pgppassfile\0")) {
      $passphrase = <PGPPASS>;
      close PGPPASS;
      chomp $passphrase;
    }
  }

	$message .= "\n";
	$message .= $body;

  # Sign the message, getting the signature and PGP version number.
  my $pgpsigner = $self->{pgpsigner};
  my ($signature, $version) = $self->pgp_sign($pgpsigner, $passphrase, $message);
  unless ($signature) {
    die "Could not generate signature\n";
  }

  # GnuPG has version numbers containing spaces, which breaks our header
  # format.  Find just some portion that contains a digit.
  ($version) = ($version =~ /(\S*\d\S*)/);

  # Put the signature into the headers.
  $signature =~ s/^/\t/mg;
  $headers->{'X-PGP-Sig'} = "$version $signheaders\n$signature";

  for (@ignoreheaders) {
    delete $headers->{$_} if defined $headers->{$_};
  }

  foreach my $header (@orderheaders) {
    $head .= "$header: $headers->{$header}\n" if $headers->{$header};
    delete $headers->{$header};
  }

  foreach my $header (keys %$headers) {
    die "unexpected header $header left in header array\n";
  }

	return $head . "\n" . $body;
}

1;

__END__

# Our lawyer told me to include the following.  The upshot of it is that
# you can use the software for free as much as you like.

# Copyright (c) 1996 UUNET Technologies, Inc.
# All rights reserved.
# Copyright (c) 2006 Nick Andrew <nick@nick-andrew.net>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#      This product includes software developed by UUNET Technologies, Inc.
# 4. The name of UUNET Technologies ("UUNET") may not be used to endorse or
#    promote products derived from this software without specific prior
#    written permission.
#
# THIS SOFTWARE IS PROVIDED BY UUNET ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL UUNET BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
