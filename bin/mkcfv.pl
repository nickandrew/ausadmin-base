#!/usr/bin/perl -w

# Makes the Call For Votes post from a template and the group charter
# and outputs to STDOUT. Also creates a group configuration file with
# only one line - the end date (in system time (s))

# Info Needed to run the script
$VoteAddress = "vote\@aus.news-admin.org";
$HomeDir = "/virt/web/ausadmin";
$BaseDir = "$HomeDir/vote";

ReadCharter();

die "You fool it didn't work can't create a blank one." unless @newsgroup;

for my $newsgroup (@newsgroup) {

  die "You fool it didn't work can't create a blank one." unless $newsgroup;

  $ConfigFile ="$BaseDir/$newsgroup/endtime.cfg";
  chop($VotePeriod = `cat $BaseDir/$newsgroup/voteperiod`);
  
  # Find the finish date for votes according to the VD (vote duration)
  $VD = $VotePeriod * 86400;
  
  ($day, $mon, $mday, undef, $year) = split /\s+/, gmtime( time + $VD );
  $EndDate = "$day, $mday $mon $year 00:00:00 GMT";
  system("date --date '$day $mon $mday 00:00:00 GMT $year' +%s > $ConfigFile");
  
#  $ExpireDate = "$day, $mday $mon $year 00:00:00 GMT";
    
}

# Opens the template Call For Votes file and constructs the actual CFV file
# which is output to STDOUT
select(STDOUT);
$| = 1;

#preprocess(STDOUT, "$BaseDir/conf/cfvtemplate.header");

die "No distribution" unless $distribution;

print <<"EOHEADERS";
Subject: CFV: $newsgroup[0]
From: $VoteAddress
Newsgroups: $distribution
Followup-to: poster

EOHEADERS

if (!open(P, "|pgp -s -f")) {
	print STDERR "Unable to open a pipe to PGP: $!";
	exit(3);
}

if ($moderated{$newsgroup[0]}) {

print P <<"EOTOPBODY";
                           CALL FOR VOTES
                 Moderated newsgroup $newsgroup[0]

Newsgroups line(s)
EOTOPBODY

} else {

print P <<"EOTOPBODY";
                           CALL FOR VOTES
                 UnModerated newsgroup $newsgroup[0]

Newsgroups line(s)
EOTOPBODY

  
}

for my $group (@newsgroup) {
  print P $group," ",$NGLine{$group},"\n";
  local *NGLINE;
  open NGLINE,"$BaseDir/$newsgroup/ngline" or die "Unable to open ngline";
  print NGLINE,$NGLine{$group},"\n";
  close NGLINE;
}

print P <<"EOMIDBODY";

Votes must be received by $EndDate

This vote is being conducted by ausadmin. For voting questions contact 
ausadmin\@aus.news-admin.org. For questions about the proposed group contact 
$Proposer.

EOMIDBODY

for my $group (@newsgroup) {
  print P "RATIONALE: $group\n",join "\n",@{$Charter{$newsgroup}};
}

print P <<'EOMEND';
HOW TO VOTE

Send E-MAIL to: vote@aus.news-admin.org
Just Replying should work if you are not reading this on a mailing list.

Your mail message should contain only one of the following statements:
      I vote YES on aus.example.name
      I vote NO on aus.example.name

You must replace aus.example.name with the name of the newsgroup that you are 
voting for. If the poll is for multiple newsgroups you should include one vote
for each newsgroup, e.g.

I vote YES on aus.example.name
I vote NO on aus.silly.group
I vote YES on aus.good.group

You may also ABSTAIN in place of YES/NO - this will not affect the outcome.
Anything else may be rejected by the automatic vote counting program.  
ausadmin will respond to your received ballots with a personal
acknowledgement by E-mail - if you do not receive one within 24 hours, try
again. It's your responsibility to make sure your vote is registered
correctly.

Only one vote per person, no more than one vote per E-mail address.
Addresses of all voters will be published in the final voting results list.

[ Note: CFVs and control messages will be signed with the ausadmin key.
  Download it from http://aus.news-admin.org/ausadmin.asc now!   --nick ]

EOMEND


close(P);

for my $group (@newsgroup) {
  open(CHARTER, ">$BaseDir/$group/charter") or die "Unable to write charter";
  print CHARTER join "\n",@{$Charter{$newsgroup}};
}



# This sub grabs the required info from the RFD piped into the script.

sub ReadCharter {
     while ( <> ) {
	  chomp;
	  if ( $_ =~ /^Newsgroup line:/i ) {
GROUP:	       while (<>) {
		    chomp;
		    last GROUP if (/^rationale:.*/i);

		    if (/^([^\s]+)\s+(.*)/i) {
			 push @newsgroup,$1;
			 $newsgroup=$1;
			 $NGLine{$newsgroup}=$2;
		    } else {
			 last GROUP;
		    }
		    
	       }
	       
	  }
	  
	  if ( $_ =~ /^Moderated:.*/i ) {
	       s/^Moderator:\s*(.*)/$1/i;
	       $moderated{$newsgroup}=1;
	       while (<>) {
		    last if (/^End moderator info/i);
		    push @{$moderator{$newsgroup}},$_;
	       }
	       
	  }


	  if ($_ =~ /^DISTRIBUTION:(.*)/i) {
	       $distribution=$1;
DIST:	       while (<>) {
		    chomp;
		    last DIST if (/^Propo(?:nen?ts?|sers?):.*/i);
		    $distribution .= "$_," if not /^\s*$/;
	       }
	       $distribution =~ s/,$//;
	  }
#                      Propo   nent
	  if ( $_ =~ /^Propo(?:nen?ts?|sers?):/i ) {
	       m/^Propo(?:nen?ts?|sers?):\s*(.*)/i;
	       $Proposer .= "$1," if not /^\s*$/;
PROP:	       while (<>) {
		    chomp;
		    last PROP if (/^/i);
		    $Proposer .= "$_," if not /^\s*$/;
	       }
	  }

	  
	  if (/^rationale:.*/i ) {
	       while ( <> ) {
		    last if (/^END CHARTER/i);		 
		    chomp;
		    push @{$Charter{$newsgroup}},$_;
	       }
	  }
	  

     }

     $distribution = join ',',
	  grep /^\s*([\w.]+)\s*$/,
	       split '\s*\,\s*',$distribution;
	   
}

=pod




#Just commenting this out.
sub preprocess {
	my($fh, $path) = @_;

		     if (!open(TEMPLATE, $path)) {
						       print STDERR "Unable to open $path: $!";
						       return 1;
						  }
			  
			  while ( <TEMPLATE> ) {
			       chomp;
			       if ( $_ =~ /.*!CHARTER!/ ) {
				    for ( $i=0; $i<=$CNoL; $i++ ) {	
					 print $fh "$Charter[$i]\n";
				    }
			       }
			       elsif ( $_ =~ /.*![^!]+!/ ) {
				    s/!GROUPNAME!/$Newsgroup/g;
				    s/!GROUPLINE!/$NGLine/g;
				    s/!PROPOSER!/$Proposer/g;
				    s/!VOTEADDRESS!/$VoteAddress/g;
				    s/!MODERATED!/$Moderated/g;
				    s/!DATE!/$EndDate/g;
				    s/!EXPIRES!/$ExpireDate/g;
				    print $fh "$_\n";
			       }
			       else {
				    print $fh "$_\n";
			       }
			  }
	
	close(TEMPLATE);
	return 0;
   }

=cut
