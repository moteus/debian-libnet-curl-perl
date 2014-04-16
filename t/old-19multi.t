#!perl

use strict;
use warnings;
use lib 'inc';
use Test::More;
use Test::HTTP::Server;
use Net::Curl::Easy qw(:constants);
use Net::Curl::Multi qw(:constants);
use File::Temp qw/tempfile/;

my $server = Test::HTTP::Server->new;
plan skip_all => "Could not run http server\n" unless $server;
plan tests => 22;

my $header = tempfile();
my $header2 = tempfile();
my $body = tempfile();
my $body2 = tempfile();

my $url = $server->uri;

my $last_fdset = "";
my $last_cnt = 0;
sub print_fdset
{
	return;
	my $cnt = unpack( "%32b*", join "", @_ );
	my $n = join ", ", map { unpack( "H*", $_ ) } @_;
	my $diag = "fdset is $cnt: ( $n )";
	if ( $diag eq $last_fdset ) {
		$last_cnt++;
	} else {
		if ( $last_cnt ) {
			if ( $last_cnt == 1 ) {
				diag( $last_fdset );
			} else {
				diag( "... and $last_cnt more" );
			}
		}
		$last_fdset = $diag;
		$last_cnt = 0;
		diag( $diag );
	}
}

sub action_wait {
	my $curlm = shift;
	my ($rin, $win, $ein) = $curlm->fdset;
	print_fdset( $rin, $win, $ein );
	my $timeout = $curlm->timeout;
	if ( $timeout > 0 ) {
		my ($nfound,$timeleft) = select($rin, $win, $ein, $timeout / 1000);
	}
}


    my $curl = new Net::Curl::Easy;
    $curl->setopt( CURLOPT_URL, $url);
    ok(! $curl->setopt(CURLOPT_WRITEHEADER, $header), "Setting CURLOPT_WRITEHEADER");
    ok(! $curl->setopt(CURLOPT_WRITEDATA,$body), "Setting CURLOPT_WRITEDATA");
    ok( $curl->{private} = "foo" , "Setting private data");

    my $curl2 = new Net::Curl::Easy;
    $curl2->setopt( CURLOPT_URL, $url);
    ok(! $curl2->setopt(CURLOPT_WRITEHEADER, $header2), "Setting CURLOPT_WRITEHEADER");
    ok(! $curl2->setopt(CURLOPT_WRITEDATA,$body2), "Setting CURLOPT_WRITEDATA");
    ok( $curl2->{private} = 42, "Setting private data");

    my $curlm = new Net::Curl::Multi;
    my @fds = $curlm->fdset;
    print_fdset( @fds );
    ok( @fds == 3 && ref($fds[0]) eq '' && ref($fds[1]) eq '' && ref($fds[2]) eq '', "fdset returns 3 vectors");
    ok( ! $fds[0] && ! $fds[1] && !$fds[2], "The three returned vectors are empty");
    $curlm->perform;
    @fds = $curlm->fdset;
    print_fdset( @fds );
    ok( ! $fds[0] && ! $fds[1] && !$fds[2] , "The three returned vectors are still empty after perform");
    $curlm->add_handle($curl);
    @fds = $curlm->fdset;
    print_fdset( @fds );
    ok( ! $fds[0] && ! $fds[1] && !$fds[2] , "The three returned vectors are still empty after perform and add_handle");
    $curlm->perform;
    @fds = $curlm->fdset;
    my $cnt;
    $cnt = unpack( "%32b*", $fds[0].$fds[1] );
    print_fdset( @fds );
    ok( 1, "The read or write fdset contains one fd (is $cnt)");
    $curlm->add_handle($curl2);
    @fds = $curlm->fdset;
    $cnt = unpack( "%32b*", $fds[0].$fds[1] );
    print_fdset( @fds );
    ok( 1, "The read or write fdset still only contains one fd (is $cnt)");
    $curlm->perform;
    @fds = $curlm->fdset;
    $cnt = unpack( "%32b*", $fds[0].$fds[1] );
    print_fdset( @fds );
    ok( 2, "The read or write fdset contains two fds (is $cnt)");
    my $active = 2;
    while ($active != 0) {
	my $ret = $curlm->perform;
	if ($ret != $active) {
		while (my ($msg, $curl, $result) = $curlm->info_read) {
			is( $msg, CURLMSG_DONE, "Message is CURLMSG_DONE" );
			$curlm->remove_handle( $curl );
			ok( $curl && ( $curl->{private} eq "foo" || $curl->{private}  == 42 ), "The stored private value matches what we set ($curl->{private})");
		}
		$active = $ret;
	}
        action_wait($curlm);
    }
    @fds = $curlm->fdset;
    ok( ! $fds[0] && ! $fds[1] && !$fds[2] , "The three returned arrayrefs are empty after we have no active transfers");
    ok($header, "Header reply exists from first handle");
    ok($body, "Body reply exists from second handle");
    ok($header2, "Header reply exists from second handle");
    ok($body2, "Body reply exists from second handle");
