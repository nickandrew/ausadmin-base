#!/usr/bin/perl

use HTTP::Lite;

my $email = shift @ARGV;

my $query = "http://groups.google.com/groups?q=author:$email";

my $http = new HTTP::Lite();
my $req = $http->request($query) or die "Unable to get document: $!";

die "Request failed ($req): " . $http->status_message() if ($req ne '200');

my $body = $http->body();

print $body;
exit(0);
