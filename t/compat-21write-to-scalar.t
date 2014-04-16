#!perl
use strict;
use warnings;
use lib 'inc';
use Test::More;
use Test::HTTP::Server;

BEGIN {
	eval 'use Net::Curl::Compat;';
	plan skip_all => $@ if $@;
}
use WWW::Curl::Easy;

my $server = Test::HTTP::Server->new;
plan skip_all => "Could not run http server\n" unless $server;
plan tests => 12;

my $url = $server->uri;

# Init the curl session
my $curl = WWW::Curl::Easy->new();

ok(! $curl->setopt(CURLOPT_NOPROGRESS, 1), "Setting CURLOPT_NOPROGRESS");
ok(! $curl->setopt(CURLOPT_FOLLOWLOCATION, 1), "Setting CURLOPT_FOLLOWLOCATION");
ok(! $curl->setopt(CURLOPT_TIMEOUT, 30), "Setting CURLOPT_TIMEOUT");
ok(! $curl->setopt(CURLOPT_ENCODING, undef), "Setting CURLOPT_ENCODING to undef");
ok(! $curl->setopt(CURLOPT_RESUME_FROM_LARGE, 0), "Setting CURLOPT_RESUME_FROM_LARGE to 0");
$curl->setopt(CURLOPT_HEADER, 1);

my $head = '';
ok(! $curl->setopt(CURLOPT_WRITEHEADER, \$head), "Setting CURLOPT_WRITEHEADER");

my $body = '';
ok(! $curl->setopt(CURLOPT_WRITEDATA, \$body), "Setting CURLOPT_WRITEDATA");

ok(! $curl->setopt(CURLOPT_URL, $url), "Setting CURLOPT_URL");

my $retcode = $curl->perform();

ok(! $retcode, "Curl return code ok");

my $bytes = $curl->getinfo(CURLINFO_SIZE_DOWNLOAD);
ok( $bytes, "getinfo returns non-zero number of bytes");
my $realurl = $curl->getinfo(CURLINFO_EFFECTIVE_URL);
ok( $realurl, "getinfo returns CURLINFO_EFFECTIVE_URL");
my $httpcode = $curl->getinfo(CURLINFO_HTTP_CODE);
ok( $httpcode, "getinfo returns CURLINFO_HTTP_CODE");

#note("Bytes: $bytes");
#note("realurl: $realurl");
#note("httpcode: $httpcode");
