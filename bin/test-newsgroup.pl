#!/usr/bin/perl

use lib 'bin';

use Newsgroup;

my $n = new Newsgroup(name => 'aus.test.tv', hier => 'aus');

my $charter = "A sample charter.\n";

$n->set_datadir("data");
$n->set_attr('charter', $charter, 'Sample charter');
exit(0);
