#!/usr/bin/perl

use lib 'bin';

use Newsgroup;

my $n = new Newsgroup(name => 'aus.tv');

my $charter = "A sample charter.\n";

$n->set_datadir("data/Newsgroups");
$n->set_attr('charter', $charter, 'Sample charter');
exit(0);
