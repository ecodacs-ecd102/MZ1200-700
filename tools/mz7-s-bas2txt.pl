#!/usr/bin/perl

#
# Dump MZ-700 Hu-BASIC binary file to plain text
#

use strict;
use utf8;
use Encode;

my @sta;
my @staFE;
my @funFF;

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
  die sprintf("File type error: %02X, expected 05\n", $typ) if ($typ != 5);

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
    while (length($l)) {
      my $c = substr($l, 0, 1);
      my $cc = ord($c);
      $l = substr($l, 1);

      # EOL $00
      if ($cc == 0) {
        last if (length($l) == 0);
        printf("<<%02x>>", $cc);
      }
      # : and ' comment, ELSE
      elsif ($c eq ':') {
        my $c2 = substr($l,0,1);
        my $cc2 = ord($c2);
        $c2 = $sta[$cc2] if ($cc2 >= 0x80 && exists($sta[$cc2]));
        if ($c2 eq "'") {
          print "'";
          $l = substr($l, 1);
          $raw=2;
        }
        # :ELSE = ELSE
        elsif ($cc2 eq "ELSE") {
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
        # statement 80-FD
        elsif ($cc >= 0x80 && $cc <= 0xfd) {
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
        # statement FE80-
        elsif ($cc == 0xfe) {
          $c = substr($l, 0, 1);
          $cc = ord($c);
          $l = substr($l, 1);
          if (defined($staFE[$cc])) {
            print $staFE[$cc];
          }
          else {
            printf("<<FE%02x>>", $cc);
          }
        }
        # function FF80-
        elsif ($cc == 0xff) {
          $c = substr($l, 0, 1);
          $cc = ord($c);
          $l = substr($l, 1);
          if (defined($funFF[$cc])) {
            print $funFF[$cc];
          }
          else {
            printf("<<FF%02x>>", $cc);
          }
        }
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
$sta[0x80] = 'GOTO';
$sta[0x81] = 'GOSUB';
$sta[0x83] = 'RUN';
$sta[0x84] = 'RETURN';
$sta[0x85] = 'RESTORE';
$sta[0x86] = 'RESUME';
$sta[0x87] = 'LIST';
$sta[0x89] = 'DELETE';
$sta[0x8A] = 'RENUM';
$sta[0x8B] = 'AUTO';
$sta[0x8D] = 'FOR';
$sta[0x8E] = 'NEXT';
$sta[0x8F] = 'PRINT';
$sta[0x91] = 'INPUT';
$sta[0x93] = 'IF';
$sta[0x94] = 'DATA';
$sta[0x95] = 'READ';
$sta[0x96] = 'DIM';
$sta[0x97] = 'REM';
$sta[0x98] = 'END';
$sta[0x99] = 'STOP';
$sta[0x9A] = 'CONT';
$sta[0x9B] = 'CLS';
$sta[0x9D] = 'ON';
$sta[0x9E] = 'LET';
$sta[0x9F] = 'NEW';
$sta[0xA0] = 'POKE';
$sta[0xA1] = 'OFF';
$sta[0xA2] = 'MODE';
$sta[0xA3] = 'SKIP';
$sta[0xA4] = 'PLOT';
$sta[0xA5] = 'LINE';
$sta[0xA6] = 'RLINE';
$sta[0xA7] = 'MOVE';
$sta[0xA8] = 'RMOVE';
$sta[0xA9] = 'TRON';
$sta[0xAA] = 'TROFF';
$sta[0xAB] = 'INP#';
$sta[0xAD] = 'GET';
$sta[0xAE] = 'PCOLOR';
$sta[0xAF] = 'PHOME';
$sta[0xB0] = 'HSET';
$sta[0xB1] = 'GPRINT';
$sta[0xB2] = 'KEY';
$sta[0xB3] = 'AXIS';
$sta[0xB4] = 'LOAD';
$sta[0xB5] = 'SAVE';
$sta[0xB6] = 'MERGE';
$sta[0xB8] = 'CONSOLE';
$sta[0xBA] = 'OUT#';
$sta[0xBB] = 'CIRCLE';
$sta[0xBC] = 'TEST';
$sta[0xBD] = 'PAGE';
$sta[0xC0] = 'ERASE';
$sta[0xC1] = 'ERROR';
$sta[0xC3] = 'USR';
$sta[0xC4] = 'BYE';
$sta[0xC7] = 'DEF';
$sta[0xCE] = 'WOPEN';
$sta[0xCF] = 'CLOSE';
$sta[0xD0] = 'ROPEN';
$sta[0xD9] = 'KILL';
$sta[0xE0] = 'TO';
$sta[0xE1] = 'STEP';
$sta[0xE2] = 'THEN';
$sta[0xE3] = 'USING';
$sta[0xE6] = 'TAB';
$sta[0xE7] = 'SPC';
$sta[0xEB] = 'OR';
$sta[0xEC] = 'AND';
$sta[0xEE] = '><';
$sta[0xEF] = '<>';
$sta[0xF0] = '=<';
$sta[0xF1] = '<=';
$sta[0xF2] = '=>';
$sta[0xF3] = '>=';
$sta[0xF4] = '=';
$sta[0xF5] = '>';
$sta[0xF6] = '<';
$sta[0xF7] = '+';
$sta[0xF8] = '-';
$sta[0xFB] = '/';
$sta[0xFC] = '*';
$sta[0xFD] = '^';
$staFE[0x81] = 'SET';
$staFE[0x82] = 'RESET';
$staFE[0x83] = 'COLOR';
$staFE[0xA2] = 'MUSIC';
$staFE[0xA3] = 'TEMPO';
$staFE[0xA4] = 'CURSOR';
$staFE[0xA5] = 'VERIFY';
$staFE[0xA6] = 'CLR';
$staFE[0xA7] = 'LIMIT';
$staFE[0xAE] = 'BOOT';
$funFF[0x80] = 'INT';
$funFF[0x81] = 'ABS';
$funFF[0x82] = 'SIN';
$funFF[0x83] = 'COS';
$funFF[0x84] = 'TAN';
$funFF[0x85] = 'LN';
$funFF[0x86] = 'EXP';
$funFF[0x87] = 'SQR';
$funFF[0x88] = 'RND';
$funFF[0x89] = 'PEEK';
$funFF[0x8A] = 'ATN';
$funFF[0x8B] = 'SGN';
$funFF[0x8C] = 'LOG';
$funFF[0x8E] = 'PAI';
$funFF[0x8F] = 'RAD';
$funFF[0x95] = 'EOF';
$funFF[0x9E] = 'JOY';
$funFF[0xA0] = 'CHR$';
$funFF[0xA1] = 'STR$';
$funFF[0xA2] = 'HEX$';
$funFF[0xAB] = 'ASC';
$funFF[0xAC] = 'LEN';
$funFF[0xAD] = 'VAL';
$funFF[0xB3] = 'ERN';
$funFF[0xB4] = 'ERL';
$funFF[0xB5] = 'SIZE';
$funFF[0xBA] = 'LEFT$';
$funFF[0xBB] = 'RIGHT$';
$funFF[0xBC] = 'MID$';
$funFF[0xC3] = 'STRING$';
$funFF[0xC4] = 'TI$';
$funFF[0xC7] = 'FN';
}
