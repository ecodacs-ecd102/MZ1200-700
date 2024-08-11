#!/usr/bin/perl

use strict;
use File::Basename;

my $typ = 4;
my $ensq = 1;

my $s = 0;
my $i = 0;
for ($i = 0; $i < @ARGV; $i++)
{
  if ($ARGV[$i] eq "-t") {
    $i++;
    $typ = $ARGV[$i];
    $typ += 0;
    $s += 2;
  }
  elsif ($ARGV[$i] eq "-s") {
    $ensq = 0;
    $s++;
  }
  elsif ($ARGV[$i] eq "-S") {
    $ensq = 1;
    $s++;
  }
}
for ($i = 0; $i < $s; $i++) { shift; }

if (!@ARGV) {
  print STDERR
"Plain Text file to MZT converter

Usage:
        $0 [-t (3|4|0x16)] [-s|-S] filename > outname.mzt
          -t: file type
            3: MZ-80K/1300, QD
            4: MZ-700 HuBASIC BSD (default)
         0x16: MZ-80K HuBASIC 1.1

          -s: Supress seq, with total size in header : TEXT EDITOR SP-2201
          -S: Enable seq, size=0 in header, CTRL-Z   : MZ-700 HuBASIC BSD (default)

";
  exit 1;
}

while (@ARGV)
{
  open(my $fh, "<", $ARGV[0]) || die "Can't open '$ARGV[0]': $!\n";
  binmode($fh);
  binmode(STDOUT);

  # create header
  my $header;
  my $fname = basename($ARGV[0]);
  my $size = (stat $ARGV[0])[7];
  $fname =~ s/\.(txt|bas)$//i;
  $fname =~ s/[^-0-9a-z!"#\$%&()+=,.;:\[\ ]/ /ig;
  $fname =~ tr/[a-z]/[A-Z]/;
  $fname = unpack("A16", $fname);

  if ($ensq) {
    $size = 0;	# when use seq, size = 0
  }

  $header = pack("C1C16C1v3C104", $typ, unpack("C16", $fname . "\r" x 16), 0x0d, $size, 0, 0, (0));
  print $header;

  # block No.
  my $seq = 0;
  my $buf = "";
  while (<$fh>) {
    chomp; chomp;
    my $l = "$_\r";
    while (length($l) > 0) {
      my $blen = length($buf);
      if (($blen + length($l)) > 256) {
        $buf .= substr($l, 0, 256-$blen);
        $l = substr($l, 256-$blen, length($l)-256+$blen);
      }
      else {
        $buf .= $l;
        $l = "";
      }
      if (length($buf) == 256) {
        print pack("v1", $seq) if ($ensq);
        print pack("C256", unpack("C256", $buf . "\0" x 256));
        $buf = "";
        $seq++;
      }
    }
  }
  $buf .= "\x1a" if ($ensq);
  if (length($buf) > 0) {
    print pack("v1", 0xffff) if ($ensq);
    print pack("C256", unpack("C256", $buf . "\0" x 256));
    $buf = "";
  }
  close($fh);
  shift;
}
