#!/usr/bin/perl

use strict;
use utf8;

if (@ARGV < 2) {
  print "Usage $0 [-o offset] infile.bin outfile.bin [patch1.bdiff [patch2.bdiff [...]]]\n";
  exit 1;
}

my $offset = 0;
if ($ARGV[0] eq "-o" ) {
  $offset = $ARGV[1] + 0;
  shift;
  shift;
}

open(my $in,    "<:raw", $ARGV[0]) || die "Infile $ARGV[0] not found.\n";
open(my $out,   "+>:raw", $ARGV[1]) || die "Outfile $ARGV[1] cannot create.\n";

shift;
shift;

# first, copy $in to $out
use constant BUFSIZE => 16384;
my $buf;
my $len;
while($len = sysread($in, $buf, BUFSIZE)) {
    ($len == syswrite($out, $buf, $len)) || die("File write error.\n");
}
close($in);

# patch $out using $patch
my $fn;
foreach my $file (@ARGV) {
  open(my $fh, "<", $file) || die "Can't open < $file\n";
  while (<$fh>) {
    chomp;
    if (m/^([0-9a-f]+) ([0-9a-f]{2}) ([0-9a-f]{2})$/i) {
      my ($addr, $org, $new) = ($1, $2, $3);

      $addr = hex($addr) + $offset;
      $org  = hex($org);
      $new  = hex($new);

      printf("%08X: %02X -> %02X\n", $addr, $org, $new);
      sysseek $out, $addr, 'SEEK_SET' || die("File seek error\n");
      (1 == sysread($out, $buf, 1)) || die("File read error\n");
      $buf = unpack('C',$buf);
      if ($buf != $org) {
        printf STDERR "Expecting %02X, actual %02X\n", $org, $buf;
        exit 1;
      }
      sysseek $out, $addr, 'SEEK_SET' || die("File seek error\n");
      $buf = pack('C', $new);
      (1 == syswrite($out, $buf, 1)) || die("File write error\n");
    }
  }
}

close($out);
exit 0;
