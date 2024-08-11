#!/usr/bin/perl

#
# Dump MZ-700 Hu-BASIC binary file to plain text
#

use strict;
use utf8;
use Encode;

my @sta;
#my @staFE;
#my @funFF;

setkeyword();

if (@ARGV == 0) {
  print STDERR 
"Usage: $0 [-r] source.mzt
        -r: raw mode

";
}

my $cooked = 1;
if ($ARGV[0] eq '-r') {
  $cooked = 0;
  shift;
}

my $lower = 0;

while (@ARGV)
{
  open(my $fh, "<", $ARGV[0]) || die "Can't open '$ARGV[0]': $!\n";
  binmode($fh);
  shift;

  # header
  my $header;
  sysread($fh, $header, 128);
  my ($typ, $fname, $flen, $ffrom, $fexec) = unpack("C1A17v1", $header);
  die sprintf("File type error: %02X, expected 02\n", $typ) if ($typ != 2);

  # read body
  my $body;
  die "Can't read.\n" if (! sysread($fh, $body, $flen));
  close($fh);

  # decode
  while (1) {
    # length
    my $len = unpack("v1", $body);
    $body = substr($body, 2);
    last if ($len == 0);

    # line number
    my $ln = unpack("v1", $body);
    $body = substr($body, 2);
    printf "%5d ", $ln;

    # get this line
    my $l = substr($body, 0, $len - 4);
    # go to next line
    $body = substr($body, $len - 4);

    # decode this line
    my $raw=0;
    #my $skipok = 1;
    while (length($l)) {
      my $c = substr($l, 0, 1);
      my $cc = ord($c);
      $l = substr($l, 1);

#      # skip 0x80
#      if ($skipok && $cc == 0x80) {
#        next;
#      }
#      $skipok = 0;
      

      # EOL $0D
      if ($cc == 0x0D) {
        last if (length($l) == 0);
        printf("<<%02x>>", $cc);
      }
      # : and ' comment, ELSE
      elsif ($c eq ':') {
        my $c2 = substr($l,0,1);
        my $cc2 = ord($c2);
        $c2 = $sta[$cc2] if ($cc2 >= 0x80 && exists($sta[$cc2]));
#        if ($c2 eq "'") {
#          print "'";
#          $l = substr($l, 1);
#          $raw=2;
#        }
        # :ELSE = ELSE
        if ($cc2 eq "ELSE") {
          print "ELSE";
          $l = substr($l, 1);
        }
        else {
          print ':';
        }
      }
      # inside ""
      elsif ($c eq '"') {
        $raw = (1 - $raw);
        print $c;
      }
      # ascii
      elsif ($cc >= 0x20 && $cc <= 0x7e) {
        disp_char($c, $cooked);
      }
      elsif (!$raw) {
        # $01-$0A: 0-9
        if ($cc >= 0x1 && $cc <= 10) {
        print $cc-1;
        }
        # $0B: line number
        elsif ($cc == 0x0b) {
          my $n = unpack("v1", $l);
          $l = substr($l, 2);
          printf("%d", $n)
        }
        #$0d: &O
        elsif ($cc == 0x0d) {
          my $n = unpack("v1", $l);
          $l = substr($l, 2);
          printf("&O%o", $n)
        }
        #$0e: &B
        elsif ($cc == 0x0e) {
          my $n = unpack("v1", $l);
          $l = substr($l, 2);
          printf("&B");
          my $i;
          for ($i = 0x8000; $i > 1 && !($n & $i); $i >>= 1) { 1; };
          for (; $i; $i >>= 1) { print (i & j) ? "1" : "0"; }
        }
        #$0f: &H
        elsif ($cc == 0x0f) {
          my $n = unpack("v1", $l);
          $l = substr($l, 2);
          #printf("$%04X", $n)
          printf("&H%X", $n)
        }
        #$11: $xxxx
        elsif ($cc == 0x11) {
          my $n = unpack("v1", $l);
          $l = substr($l, 2);
          printf("\$%04X", $n)
        }
        # short
        elsif ($cc == 0x12) {
          my $n = unpack("v1", $l);
          $l = substr($l, 2);
          if ($n > 0x7fff) {
            $n = 0x10000 - $n;
          }
          printf("%d", $n)
        }
        # $14 MZ 4-byte float
        elsif ($cc == 0x14) {
          my ($exp, $manh, $manl) = unpack("C1n1C1", $l);
          $l = substr($l, 4);
          my $man = $manh << 8 | $manl;
          my $s = ($man & 0x800000) ? -1.0 : 1.0;
          $man |= 0x800000;
          if ($exp == 0) {
            printf("%g",0.0);
          }
          else {
            $exp = $exp - 128 - 24;
            printf("%g", $s * $man * (2.0 ** $exp));
          }
        }
        # $15 MZ float
        elsif ($cc == 0x15) {
          my ($exp, $man) = unpack("C1N", $l);
          $l = substr($l, 5);
          my $s = ($man & 0x80000000) ? -1.0 : 1.0;
          $man |= 0x80000000;
          if ($exp == 0) {
            printf("%g",0.0);
          }
          else {
            $exp = $exp - 128 - 32;
            printf("%g", $s * $man * (2.0 ** $exp));
          }
        }
        # $18 MZ double
        elsif ($cc == 0x18) {
          my ($exp, $manh, $manl) = unpack("C1N2", $l);
          $l = substr($l, 9);
          my $s = ($manh & 0x80000000) ? -1.0 : 1.0;
          $manh |= 0x80000000;
          if ($exp == 0) {
            printf("%g",0.0);
          }
          else {
            $exp = $exp - 128 - 32;
            printf("%g", $s * ($manh * (2.0 ** $exp) + $manl * (2.0 ** ($exp - 24))));
          }
        }
        # statement 80-FE
        elsif ($cc >= 0x80 && $cc <= 0xfe) {
          if (defined($sta[$cc])) {
            print $sta[$cc];
            if ($sta[$cc] eq "REM" || $sta[$cc] eq "DATA") {
              $raw = 2;
            }
          }
          else {
            printf("<<%02x>>", $cc);
          }
        }
#        # statement FE80-
#        elsif ($cc == 0xfe) {
#          $c = substr($l, 0, 1);
#          $cc = ord($c);
#          $l = substr($l, 1);
#          if (defined($staFE[$cc])) {
#            print $staFE[$cc];
#          }
#          else {
#            printf("<<FE%02x>>", $cc);
#          }
#        }
#        # function FF80-
#        elsif ($cc == 0xff) {
#          $c = substr($l, 0, 1);
#          $cc = ord($c);
#          $l = substr($l, 1);
#          if (defined($funFF[$cc])) {
#            print $funFF[$cc];
#          }
#          else {
#            printf("<<FF%02x>>", $cc);
#          }
#        }
        else {
          printf("<<%02x>>", $cc);
        }
      }
      else { # $raw
        disp_char($c, $cooked);
      }
    }
    print "\n";
  }
}


sub disp_char($, $)
{
  my $c = shift;
  my $cooked = shift;
  my $cc = ord($c);

  if (!$cooked) {
    print "$c";
    return;
  }
  # cook
  elsif ($cc == 0x10) {
    $lower = 1;
    return;
  }
  elsif ($cc == 0x11) {
    $lower = 0;
    return;
  }
  elsif ($cc >= 0x20 && $cc <= 0x7d) {
    if ($lower && ($cc >= 0x41 && $cc <= 0x5a)) {
      $c = chr($cc + 0x20);
    }
    print "$c";
    return;
  }
  elsif ($cc >= 0x81 && $cc <= 0xbf) {
    $c = decode("cp932", chr($cc + 0x20));
    if ($lower) {
      $cc = ord($c);
      $c = chr($cc + (ord('あ') - ord('ア')));
    }
    print encode("utf-8", "$c");
    return;
  }
  elsif ($cc >= 0x70 && $cc <= 0x7e) {
    $cc -= 0x70;
    my @k = ("日","月","火","水","木","金","土","生","年","時","分","秒","円","￥","￡");
    print encode("utf-8", $k[$cc]);
    return;
  }
  elsif ($cc == 0xff) {
    print encode("utf-8", "π");
    return;
  }
  printf("{%02X}", $cc);


}


sub setkeyword()
{
$sta[0x80] = 'REM';
$sta[0x81] = 'DATA';
$sta[0x82] = 'LIST';
$sta[0x83] = 'RUN';
$sta[0x84] = 'NEW';
$sta[0x85] = 'PRINT';
$sta[0x86] = 'LET';
$sta[0x87] = 'FOR';
$sta[0x88] = 'IF';
$sta[0x89] = 'GOTO';
$sta[0x8A] = 'READ';
$sta[0x8B] = 'GOSUB';
$sta[0x8C] = 'RETURN';
$sta[0x8D] = 'NEXT';
$sta[0x8E] = 'STOP';
$sta[0x8F] = 'END';
$sta[0x90] = 'ON';
$sta[0x91] = 'LOAD';
$sta[0x92] = 'SAVE';
$sta[0x93] = 'VERIFY';
$sta[0x94] = 'POKE';
$sta[0x95] = 'DIM';
$sta[0x96] = 'DEF FN';
$sta[0x97] = 'INPUT';
$sta[0x98] = 'RESTORE';
$sta[0x99] = 'CLR';
$sta[0x9A] = 'MUSIC';
$sta[0x9B] = 'TEMPO';
$sta[0x9C] = 'USR(';
$sta[0x9D] = 'WOPEN';
$sta[0x9E] = 'ROPEN';
$sta[0x9F] = 'CLOSE';
$sta[0xA0] = 'BYE';
$sta[0xA1] = 'LIMIT';
$sta[0xA2] = 'CONT';
$sta[0xA3] = 'SET';
$sta[0xA4] = 'RESET';
$sta[0xA5] = 'GET';
$sta[0xA6] = 'INP#';
$sta[0xA7] = 'OUT#';
$sta[0xA8] = 'CURSOR';
$sta[0xAD] = 'THEN';
$sta[0xAE] = 'TO';
$sta[0xAF] = 'STEP';
$sta[0xB0] = '><';
$sta[0xB1] = '<>';
$sta[0xB2] = '=<';
$sta[0xB3] = '<=';
$sta[0xB4] = '=>';
$sta[0xB5] = '>=';
$sta[0xB6] = '=';
$sta[0xB7] = '>';
$sta[0xB8] = '<';
$sta[0xB9] = 'AND';
$sta[0xBA] = 'OR';
$sta[0xBB] = 'NOT';
$sta[0xBC] = '+';
$sta[0xBD] = '-';
$sta[0xBE] = '*';
$sta[0xBF] = '/';
$sta[0xC0] = 'LEFT$(';
$sta[0xC1] = 'RIGHT$(';
$sta[0xC2] = 'MID$(';
$sta[0xC3] = 'LEN(';
$sta[0xC4] = 'CHR$(';
$sta[0xC5] = 'STR$(';
$sta[0xC6] = 'ASC(';
$sta[0xC7] = 'VAL(';
$sta[0xC8] = 'PEEK(';
$sta[0xC9] = 'TAB(';
$sta[0xCA] = 'SPC(';
$sta[0xCB] = 'SIZE';
$sta[0xCF] = '^';
$sta[0xD0] = 'RND(';
$sta[0xD1] = 'SIN(';
$sta[0xD2] = 'COS(';
$sta[0xD3] = 'TAN(';
$sta[0xD4] = 'ATN(';
$sta[0xD5] = 'EXP(';
$sta[0xD6] = 'INT(';
$sta[0xD7] = 'LOG(';
$sta[0xD8] = 'LN(';
$sta[0xD9] = 'ABS(';
$sta[0xDA] = 'SGN(';
$sta[0xDB] = 'SQR(';
}
