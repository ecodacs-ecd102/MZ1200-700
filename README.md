# MZ1200-700

C104で発表した、MZ-700っぽいMZ-1200 です。

ディレクトリ一覧
- 2732+ExFontSelect
  PCG用フォントROM下駄
- 27512on2332socket
  モニタROMソケットに27512を載せるための下駄
- 2764onCGROMsocket
  PCG無し用フォントROM下駄(2716ソケットに2764を載せる)
- BASIC-PATCH
  BASICパッチ用差分
- BankRAM
  MZ-700互換バンクRAMボード
- ColourBoard
  MZ-700互換カラーRAMボード
- DoubleClock
  倍速基板＋PCG-700互換サブボード
- KBIF
  USBキーボードアダプタ
- MONITOR
  モニタROMパッチ用差分
- MZ-1R12modoki
  MZ-1R12互換バッテリーバックアップS-RAMボード
- PCG
  PCG-700互換メインボード(2種)
- RGB2HDMI
  スキャンコンバータ RGB2HDMI 用のプロファイル
- tools
  細々したツール類

----
 - ROMやBASICの元データは、差分の元バイトを除きここにはありません。各自容易してください。
 - GALのビルドには galette ( https://arbitrary.name/blog/all/galette.html ) が必要です。
 - Z80のアセンブルには、zasm ( https://www.vector.co.jp/soft/dos/prog/se010314.html )をlinux上の MZ-DOS エミュレータ emu2 ( https://github.com/dmsc/emu2 )で動かしています。
