#!/usr/bin/perl

#
# Dump MZ-80K Hu-BASIC V1.1, V1.3 binary file to plain text
#

use strict;
use utf8;
use Encode;

my @sta;
#my @staFE;
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
        elsif ($cc == 0x0d) {
          my $n = unpack("v1", $l);
          $l = substr($l, 2);
          printf("&B");
          my $i;
          for ($i = 0x8000; $i > 1 && !($n & $i); $i >>= 1) { 1; };
          for (; $i; $i >>= 1) { print (i & j) ? "1" : "0"; }
        }
        #$11: &H, (S-BASIC: "$")
        elsif ($cc == 0x11) {
          my $n = unpack("v1", $l);
          $l = substr($l, 2);
          #printf("$%04X", $n)
          printf("&H%X", $n)
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
            print "0.0";
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
            print "0.0";
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
            print "0.0";
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
  elsif ($cc >= 0x20 && $cc <= 0x7d) {
    print "$c";
    return;
  }
  elsif ($cc >= 0x81 && $cc <= 0xbf) {
    $c = decode("cp932", chr($cc + 0x20));
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
$sta[0x81] = 'GOTO';
$sta[0x82] = 'GOSUB';
$sta[0x83] = 'RUN';
$sta[0x84] = 'RETURN';
$sta[0x85] = 'RESTORE';
$sta[0x86] = 'LIST';
$sta[0x87] = 'LIST#1';
$sta[0x88] = 'AUTO';
$sta[0x89] = 'DELETE';
$sta[0x8A] = 'FOR';
$sta[0x8B] = 'NEXT';
$sta[0x8C] = 'PRINT';
$sta[0x8D] = 'INPUT';
$sta[0x8E] = 'IF';
$sta[0x8F] = 'DATA';
$sta[0x90] = 'READ';
$sta[0x91] = 'DIM';
$sta[0x92] = 'REM';
$sta[0x93] = 'EDIT';
$sta[0x94] = 'STOP';
$sta[0x95] = 'CONT';
$sta[0x96] = 'CLS';
$sta[0x97] = 'CLEAR';
$sta[0x98] = 'ON';
$sta[0x99] = 'LET';
$sta[0x9A] = 'NEW';
$sta[0x9B] = 'POKE';
$sta[0x9C] = 'OFF';
$sta[0x9D] = 'WHILE';
$sta[0x9E] = 'WEND';
$sta[0x9F] = 'REPEAT';
$sta[0xA0] = 'UNTIL';
$sta[0xA1] = 'TRACE';
$sta[0xA2] = 'END';
$sta[0xA3] = 'PLAY';
$sta[0xA4] = 'BEEP';
$sta[0xA5] = 'DEFINT';
$sta[0xA6] = 'DEFSNG';
$sta[0xA7] = 'DEFDBL';
$sta[0xA8] = 'DEFSTR';
$sta[0xA9] = 'DEF';
$sta[0xAA] = 'DUMP';
$sta[0xAB] = 'LOAD';
$sta[0xAC] = 'SAVE';
$sta[0xAD] = 'MERGE';
$sta[0xAE] = 'CONSOLE';
$sta[0xAF] = 'OUT';
$sta[0xB0] = 'SEARCH';
$sta[0xB3] = 'SWAP';
$sta[0xB5] = 'ERROR';
$sta[0xB6] = 'RESUME';
$sta[0xB7] = 'RENUM';
$sta[0xB8] = 'ELSE';
$sta[0xB9] = 'CALL';
$sta[0xBA] = 'LOCATE';
$sta[0xBC] = 'MON';
$sta[0xBE] = 'KEY';
$sta[0xBF] = 'PUSH';
$sta[0xC0] = 'POP';
$sta[0xC2] = 'LABEL';
$sta[0xC5] = 'LINE';
$sta[0xC7] = 'PSET';
$sta[0xC8] = 'PRESET';
$sta[0xCD] = 'ROPEN';
$sta[0xCE] = 'WOPEN';
$sta[0xCF] = 'CLOSE';
$sta[0xDF] = 'TO';
$sta[0xE0] = 'STEP';
$sta[0xE1] = 'THEN';
$sta[0xE2] = 'USING';
$sta[0xE7] = 'TAB';
$sta[0xE8] = 'SPC';
$sta[0xEB] = 'XOR';
$sta[0xEC] = 'OR';
$sta[0xED] = 'AND';
$sta[0xEE] = 'NOT';
$sta[0xEF] = '><';
$sta[0xF0] = '<>';
$sta[0xF1] = '=<';
$sta[0xF2] = '=>';
$sta[0xF3] = '<=';
$sta[0xF4] = '>=';
$sta[0xF5] = '=';
$sta[0xF6] = '>';
$sta[0xF7] = '<';
$sta[0xF8] = '+';
$sta[0xF9] = '-';
$sta[0xFA] = 'MOD';
$sta[0xFB] = '}';
$sta[0xFC] = '/';
$sta[0xFD] = '*';
$sta[0xFE] = '^';
$funFF[0x81] = 'INT';
$funFF[0x82] = 'ABS';
$funFF[0x83] = 'SIN';
$funFF[0x84] = 'COS';
$funFF[0x85] = 'TAN';
$funFF[0x86] = 'LOG';
$funFF[0x87] = 'EXP';
$funFF[0x88] = 'SQR';
$funFF[0x89] = 'RND';
$funFF[0x8A] = 'PEEK';
$funFF[0x8B] = 'ATN';
$funFF[0x8C] = 'SGN';
$funFF[0x8D] = 'FRAC';
$funFF[0x8E] = 'FIX';
$funFF[0x8F] = 'PAI';
$funFF[0x90] = 'RAD';
$funFF[0x91] = 'INP';
$funFF[0x92] = 'CDBL';
$funFF[0x93] = 'CSNG';
$funFF[0x94] = 'CINT';
$funFF[0x9A] = 'POS';
$funFF[0x9B] = 'LPOS';
$funFF[0x9C] = 'FAC';
$funFF[0x9D] = 'SUM';
$funFF[0xA0] = 'CHR$';
$funFF[0xA1] = 'STR$';
$funFF[0xA2] = 'HEX$';
$funFF[0xA3] = 'OCT$';
$funFF[0xA4] = 'MKI$';
$funFF[0xA5] = 'MKS$';
$funFF[0xA6] = 'MKD$';
$funFF[0xA7] = 'SPACE$';
$funFF[0xA9] = 'ASC';
$funFF[0xAA] = 'LEN';
$funFF[0xAB] = 'VAL';
$funFF[0xAC] = 'CVS';
$funFF[0xAD] = 'CVD';
$funFF[0xAE] = 'CVI';
$funFF[0xAF] = 'STAT';
$funFF[0xB0] = 'PAR';
$funFF[0xB2] = 'LEFT$';
$funFF[0xB3] = 'RIGHT$';
$funFF[0xB4] = 'MID$';
$funFF[0xB5] = 'INKEY$';
$funFF[0xB6] = 'INSTR';
$funFF[0xB7] = 'FRE';
$funFF[0xB8] = 'MEM$';
$funFF[0xB9] = 'SCRN$';
$funFF[0xBA] = 'VARPTR';
$funFF[0xBB] = 'STRING$';
$funFF[0xBC] = 'TIME$';
$funFF[0xBD] = 'FN';
$funFF[0xBE] = 'USR';
$funFF[0xBF] = 'ERR';
$funFF[0xC0] = 'ERL';
$funFF[0xC1] = 'CSRLIN';
}
