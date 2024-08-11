#!/usr/bin/perl

use strict;
use utf8;

if (@ARGV < 1) {
  print "Usage $0 infile.mzt\n";
  exit 1;
}

open(my $in,    "<:raw", $ARGV[0]) || die "Infile $ARGV[0] not found.\n";
sysseek $in, 1+16+1, 'SEEK_SET' || die("File seek error\n");
my $buf;
(6 == sysread($in, $buf, 6)) || die("File read error\n");
my ($siz, $adr, $exe) = unpack("v3", $buf);

printf("SIZE = %04X\n", $siz);
printf("FROM = %04X\n", $adr);
printf("EXEC = %04X\n", $exe);

printf("Header sum = %02X\n", sum($buf,6) & 0xff);

sysseek $in, 128, 'SEEK_SET' || die("File seek error\n");
($siz == sysread($in, $buf, $siz)) || die("File read error\n");
printf("Body sum = %04X\n", sum($buf,$siz) & 0xffff);

close($in);
exit 0;


sub sum($$)
{
  my $buf = shift;
  my $size = shift;
  my $sum = 0;

  for (my $i = 0; $i < $size; $i++) {
    my $c = ord(substr($buf, $i, 1));
    for (my $j = 1; $j < 0x100; $j += $j) {
      $sum++ if ($c & $j);
    } 
  }
  return $sum;
}
