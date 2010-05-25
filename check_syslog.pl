#!/usr/bin/perl -w

use Getopt::Long;
use Sys::Syslog qw( :DEFAULT setlogsock);
use Sys::Hostname;
use IO::Socket;
use threads;
use Digest::MD5 qw(md5 md5_base64 md5_hex);
use warnings;
use strict;

my $timeout = 10;
my $syslog_server = "127.0.0.1";
my $local_port = 2000;
my $syslog_facility = "local6";
my $syslog_level = "info";

GetOptions("timeout=i" => \$timeout, "ip=s" => \$syslog_server, "facility=s" => \$syslog_facility, "level=s" => \$syslog_level, "local-port=i" => \$local_port);

my $syslog_ident = "nagios_syslog_check";
my $message = md5_hex("nagios" . hostname  . time);

sub udp_socket {
  my $server = IO::Socket::INET->new(LocalPort => $local_port, Proto => "udp")
    or die "Couldn't be a udp server on port $local_port : $@\n";

  my $MAX_TO_READ=1024;
  my $datagram = "";
  while ($server->recv($datagram, $MAX_TO_READ)) {
    return 1 if ($datagram =~ m/$message/);
  } 
}

sub send_log {
  setlogsock("udp", $syslog_server);
  openlog($syslog_ident, "nofatal", $syslog_facility);
  syslog($syslog_level, $message);
  closelog;
}

my $t = threads->new(\&udp_socket);
sleep 1;
send_log;
sleep $timeout;

if ($t->is_joinable()) {
  if ($t->join()) {
    print "Syslog in $syslog_server OK\n";
    exit 0;
  }
  else {
    print "Invalid response from Syslog in $syslog_server\n";
    exit 1;
  }
}
else {
  $t->detach();
  print "No response from the Syslog in $syslog_server\n";
  exit 1;
}
