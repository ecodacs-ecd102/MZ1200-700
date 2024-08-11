#!/usr/bin/perl

use strict;

while (@ARGV)
{
  open(my $fh, "<", $ARGV[0]) || die "Can't open '$ARGV[0]': $!\n";
  binmode($fh);
  shift;

  # header
  my $header;
  sysread($fh, $header, 128);
  my ($typ, $fname, $cr, $size, $from, $exec) = unpack("C1A16C1v1v1v1", $header);
  die sprintf("File type error: 0x%02X, expected 0x03, 0x04 or 0x16\n", $typ) if ($typ != 3 && $typ != 4 && $typ != 0x16);

  # block No. expected (if $size == 0)
  my $seq = 0;
  # length to read
  my $left = $size;
  while (1) {
    my $bn;
    my $str;
    if ($size == 0) {
      $bn = getword($fh);
      if ($bn != 0xffff && $seq != $bn) {
        die "Block sequence number error: $bn, expected: $seq\n";
      }
      $seq++;
      sysread($fh, $str, 256) || die "Unexpected EOF\n";
      $str =~ s/\x1a.*$// if ($bn == 0xffff);
    }
    else {
      my $r = ($left >= 256) ? 256 : $left;
      sysread($fh, $str, $r) || die "Unexpected EOF\n";
      $left -= $r;
    }
    $str =~ s/\r/\n/g;
    printf("%s", $str);
    last if (($size == 0 && $bn == 0xffff) || ($size > 0 && $left == 0));
  }
  close($fh);
}

sub getword($)
{
  my $fh = shift;
  my $buf;

  sysread($fh, $buf, 2) || die "Unexpected EOF\n";
  return unpack("v", $buf);	# v: unsigned short, VAX order (little endian)
}
