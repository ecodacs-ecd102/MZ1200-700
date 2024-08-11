;
; 共通部
;

;0D8H PORTA 送信データ(下位4ビット)
;0D9H PORTB 受信データ(8ビット)
;
;0DAH PORTC Bit
;7 IN  CHK
;6 IN
;5 IN
;4 IN 
;3 OUT
;2 OUT FLG
;1 OUT
;0 OUT
;
;0DBH コントロールレジスタ

;**** 8255初期化 ****
;PORTC下位BITをOUTPUT、上位BITをINPUT、PORTBをINPUT、PORTAをOUTPUT
INIT:
		LD		A,8AH
		OUT		(0DBH),A
;出力BITをリセット
INIT2:
		LD		A,00H			;PORTA <- 0
		OUT		(0D8H),A
		OUT		(0DAH),A		;PORTC <- 0
		RET

;**** 1BYTE受信 ****
;受信DATAをAレジスタにセットしてリターン
RCVBYTE:
		CALL		F1CHK			;PORTC BIT7が1になるまでLOOP
		LD		A,05H
		OUT		(0DBH),A		;PORTC BIT2 <- 1
		IN		A,(0D9h)		;PORTB -> A
		PUSH 		AF
		CALL		F2CHK			;PORTC BIT7が0になるまでLOOP
		LD		A,04H
		OUT		(0DBH),A		;PORTC BIT2 <- 0
		POP		AF
		RET

;**** 1BYTE送信 ****
;Aレジスタの内容をPORTA下位4BITに4BITずつ送信
SNDBYTE:
		PUSH		AF
		RRA
		RRA
		RRA
		RRA
		AND		0FH
		CALL		SND4BIT
		POP		AF
		AND		0FH
		CALL		SND4BIT
		RET

;**** 4BIT送信 ****
;Aレジスタ下位4ビットを送信する
SND4BIT:
		OUT		(0D8H),A
		LD		A,05H
		OUT		(0DBH),A		;PORTC BIT2 <- 1
		CALL		F1CHK			;PORTC BIT7が1になるまでLOOP
		LD		A,04H
		OUT		(0DBH),A		;PORTC BIT2 <- 0
		CALL		F2CHK
		RET

;**** BUSYをCHECK(1) ****
; 82H BIT7が1になるまでLOP
F1CHK:
		IN		A,(0DAH)
		AND		80H			;PORTC BIT7 = 1?
		JR		Z,F1CHK
		RET

;**** BUSYをCHECK(0) ****
; 82H BIT7が0になるまでLOOP
F2CHK:		IN		A,(0DAH)
		AND		80H			;PORTC BIT7 = 0?
		JR		NZ,F2CHK
		RET

;*** BC==128? ***
; Z: yes
;NZ: no
IS_BC_128:
		LD		A,B
		OR		A
		RET		NZ
		LD		A,C
		CP		128
		RET

;*** ファイル名後ろTrim用 ***
;IN:
;  HL: ファイル名PTR
;   B: 残り文字数
;OUT:
;  Z: 最後((HL)が後ろに何も無い" "または0DH)
; NZ: 最後ではない
IS_LAST:
		PUSH		HL
		PUSH		BC
IS_LAST_10:
		LD		A,(HL)
		CP		0DH
		JR		Z,IS_LAST_30		; ZF,RET
		CP		05H
		JR		Z,IS_LAST_20		; look next
		CP		06H
		JR		Z,IS_LAST_20		; look next
		CP		' '			; Other than SP ?
		JR		NZ,IS_LAST_30		; NZ,RET
IS_LAST_20:
		INC		HL
		DEC		B			; Need ZF, do not use DJNZ
		JR		NZ,IS_LAST_10
IS_LAST_30:
		POP		BC
		POP		HL
		RET

;**** LBUFをきれいにする ****
;LBUFを0DHで埋めファイルネームが指定されなかったことにする
CLRLBUF:
		PUSH		BC
		PUSH		HL

		LD		B,80
		LD		HL,LBUF
CLB10:
		LD		(HL),0DH
		INC		HL
		DJNZ		CLB10

		POP		HL
		POP		BC
		RET

;*********************** 0436H MONITOR ライト インフォメーション代替処理 ************
;HL: addr
;BC: size
MSHED:
		DI
		PUSH		DE
		PUSH		BC
		PUSH		HL

		CALL		IS_BC_128		;サイズ128バイト以外はエラー
		JP		NZ,MERRD

		LD		A,91H			;HEADER SAVEコマンド91H
		CALL		MCMD			;コマンドコード送信
;;		AND		A			;00以外ならERROR
		JP		NZ,MERRD

;インフォメーション ブロック送信
;;		LD		HL,IBUFE
;ATTR
		LD		A,(HL)
		CALL		SNDBYTE
		INC		HL
;FNAME
		LD		B,16			;ファイル名16+0DHの17バイト送信
		CALL		SNDFN			;Trimして送信, HLを進める
;OTHERS
		LD		B,128-1-17
MSH40:
		LD		A,(HL)
		CALL		SNDBYTE
		INC		HL
		DJNZ		MSH40

		CALL		RCVBYTE			;状態取得(00H=OK)
		AND		A			;00以外ならERROR
		JP		NZ,MERRD

		JP		MRET			;正常RETURN

;******************** 0475H MONITOR ライト データ代替処理 **********************
;HL: addr
;BC: size
MSDAT:
		DI
		PUSH		DE
		PUSH		BC
		PUSH		HL

		LD		A,92H			;DATA SAVEコマンド92H
		CALL		MCMD			;コマンドコード送信
;;		AND		A			;00以外ならERROR
		JP		NZ,MERRD

;FSIZE送信
		LD		A,C
		CALL		SNDBYTE
		LD		A,B
		CALL		SNDBYTE

		CALL		RCVBYTE			;状態取得(00H=OK)
		AND		A			;00以外ならERROR
		JP		NZ,MERRD
;データ送信
;HL: addr
;BC: size
MSD1:
		LD		A,(HL)
		CALL		SNDBYTE			;HLからBC Byteを送信
		DEC		BC
		LD		A,B
		OR		C
		INC		HL
		JR		NZ,MSD1			;BC=0までLOOP

		JP		MRET			;正常RETURN

;************************** 04D8H MONITOR リード インフォメーション代替処理 *****************
;HL: addr
;BC: size
MLHED:
		DI
		PUSH		DE
		PUSH		BC
		PUSH		HL

		CALL		IS_BC_128		;サイズ128バイト以外はエラー
		JP		NZ,MERRD

;以下のファイル名を指定した場合、コマンド実行
;"*L" : DIRLIST
;"*M" : MKDIR
;"*C" : CHDIR
		LD		HL,FNAME
		LD		A,(HL)
		CP		'*'
		JP		NZ,MLH10
		INC		HL			;HL=*の次の文字
		LD		A,(HL)
		CP		'L'			;*L: DIRLIST
		JR		Z,MLHDIRLIST
		CP		'M'			;*M: MKDIR
		JR		Z,MLHMKDIR
		CP		'C'			;*C: CHDIR
		JP		NZ,MERRD		;他はエラー
;**** CHDIR ****
MLHCHDIR:
		LD		A,0A6H			;CHDIRコマンドA6H
		JR		MLHXDIR
;*** MKDIR ****
MLHMKDIR:
		LD		A,0A7H			;MKDIRコマンドA7H
MLHXDIR:

;**** CHDIR/MKDIR 本体 ****
; HL+1～ファイル名
; A: 0A6H = CHDIRコマンド, 0A7H = MKDIRコマンド
		CALL		MCMD			;コマンドコード送信
;;		AND		A			;00以外ならERROR
		JP		NZ,MERRD

		CALL		CLRLINE
		CALL		MSGPR

;		ディレクトリ名(MAX16-2=14文字)送信
		LD		B,14
		INC		HL
		CALL		SNDFN			;Trimしながら送信, 14+1バイト送信される

;		ディレクトリ名(全32文字+CR)の残りは0DH送信
		LD		B,32-15+1
MLHXDIR10:
		LD		A,0DH
		CALL		SNDBYTE
		DJNZ		MLHXDIR10

		CALL		RCVBYTE			;状態取得(00H=OK)
		AND		A
		JP		NZ,MERRD

		CALL		LETLN
	;カレントディレクトリを含む文字列受信
MLHXDIR20:
		CALL		RCVBYTE			;'00H'を受信するまで表示
		OR		A
		JR		Z,MLHXDIR30
		CALL		PRNT
		JR		MLHXDIR20
MLHXDIR30:
		CALL		CLRLBUF
		CALL		RCVBYTE			;Aにエラーコード
		JP		MERRB			;LOADコマンドとしては中断リターンとなる

;**** DIRLIST本体 ****
; HL+1～ファイル名
MLHDIRLIST:
		LD		A,0A3H			;ディレトリ属性付きDIRLISTコマンド0A3Hを送信
		CALL		MCMD			;コマンドコード送信
;;		AND		A			;00以外ならERROR
		JP		NZ,MERRD

;		ディレクトリ名(MAX16-2=14文字)送信
		LD		B,14
		INC		HL
		CALL		SNDFN			;Trimしながら送信, 14+1バイト送信される

;		ディレクトリ名(全32文字+CR)の残りは0DH送信
		LD		B,32-15+1
MLHDL10:
		LD		A,0DH
		CALL		SNDBYTE
		DJNZ		MLHDL10

		CALL		INITCHR			;文字種初期化(英数、大文字)

MLHDL20:
		CALL		RCVBYTE			;属性受信 'F' or 'D' または指示(0FFH,0FEH)の受信
		CP		0FFH			;'0FFH'を受信したら終了
		JR		Z,MLHXDIR30		;状態取得し中断リターン
		CP		0FEH			;'0FEH'を受信したら一時停止して一文字入力待ち
		JR		Z,MLHDL60
	;ファイル名の受信と表示
		PUSH		AF
		PUSH		DE
		LD		DE,MSG_LOAD
		CALL		CLRLINE
		CALL		MSGPR
		POP		DE
		POP		AF
		CP		'D'
		JR		NZ,MLHDL30		;通常ファイルのとき
	;以下ディレクトリのとき
		LD		A,"*"
		CALL		PRNT
		LD		A,"C"
		CALL		PRNT
MLHDL30:
		LD		HL,LBUF
		LD		C,33			;32文字+1
MLHDL40:
		CALL		RCVBYTE			;'00H'を受信するまでを一行とする
		DEC		C
		CP		0DH			; 0DHは無視
		JR		Z,MLHDL40
		LD		(HL),A
		INC		HL
		OR		A
		JR		NZ,MLHDL40
;1行エンド
		LD		A,C
		CP		33-5			;".MZT\0"で5文字
		JR		NC,MLHDL50		;.MZT判別無し
		DEC		HL
		DEC		HL
		LD		A,(HL)
		CP		"T"
		JR		NZ,MLHDL50
		DEC		HL
		LD		A,(HL)
		CP		"Z"
		JR		NZ,MLHDL50
		DEC		HL
		LD		A,(HL)
		CP		"M"
		JR		NZ,MLHDL50
		DEC		HL
		LD		A,(HL)
		CP		"."
		JR		NZ,MLHDL50
		LD		(HL),00H
MLHDL50:
		LD		DE,LBUF
		CALL		MSGPR
		LD		A,22H
		CALL		PRNT
		CALL		LETLN
		JR		MLHDL20
;キー指示待ち
MLHDL60:
		LD		DE,MSG_KEY		;HIT KEY表示
		CALL		CLRLINE
		CALL		MSGPR
MLHDL70:
		LD		A,0
		CALL		GETKEY			;1文字入力待ち
		OR		A
		JR		Z,MLHDL70
		CP		03H			;SHIFT+BREAKで打ち切り
		JR		Z,MLHDL80
		CP		UP_KEY			;カーソル↑で打ち切り
		JR		Z,MLHDL80
		CP		42H			;「B」で前ページ
		JR		Z,MLHDL90
		LD		A,00H			;それ以外で継続
		JR		MLHDL90
MLHDL80:
		LD		A,UP_KEY		;終わるときのカーソル位置調整。一つ上へ。
		CALL		PRNT
		LD		A,0FFH			;0FFH中断コードを送信
MLHDL90:
		CALL		SNDBYTE
		CALL		LETLN
		JP		MLHDL20			;FF 00 の受信

;-----------------------------

MLH10:
		LD		A,93H			;HEADER LOADコマンド93H
		CALL		MCMD			;コマンドコード送信
;;		AND		A			;00以外ならERROR
		JP		NZ,MERRD

;FNAME送信
		LD		HL,FNAME
		LD		B,16
		CALL		SNDFN
;		残りは0DH送信
		LD		B,32-17+1
MLH20:
		LD		A,0DH
		CALL		SNDBYTE
		DJNZ		MLH20

		CALL		RCVBYTE			;状態取得(00H=OK)
		AND		A			;00以外ならERROR
		JP		NZ,MERRD

		CALL		RCVBYTE			;状態取得(00H=OK)
		AND		A			;00以外ならERROR
		JP		NZ,MERRD

		POP		HL			;読み出し先アドレス復帰
		PUSH		HL
		LD		B,80H
MLH30:
		CALL		RCVBYTE			;読みだされたインフォメーションブロックを受信
		LD		(HL),A
		INC		HL
		DJNZ		MLH30

		CALL		RCVBYTE			;状態取得(00H=OK)
		AND		A			;00以外ならERROR
		JP		NZ,MERRD

;インフォメーションブロック中のファイル名と同じに書き換える
		LD		HL,FNAME
		LD		A,(HL)
		OR		A
		JP		Z,MRET			;ファイル名無しなら正常RETURN
		POP		DE			;読み込み先
		PUSH		DE
		INC		DE			;FNAMEの位置
		LD		BC,17
		LDIR					;コピーしてしまう
		JR		MRET			;正常RETURN

;**************************** 04F8H MONITOR リード データ代替処理 ********************
;HL: addr
;BC: size
MLDAT:
		DI
		PUSH		DE
		PUSH		BC
		PUSH		HL
		LD		A,94H			;DATA LOADコマンド94H
		CALL		MCMD			;コマンドコード送信
;;		AND		A			;00以外ならERROR
		JP		NZ,MERRD

		CALL		RCVBYTE			;状態取得(00H=OK)
		AND		A			;00以外ならERROR
		JP		NZ,MERRD

		CALL		RCVBYTE			;状態取得(00H=OK)
		AND		A			;00以外ならERROR
		JP		NZ,MERRD

;FSIZE送信
		LD		A,C
		CALL		SNDBYTE
		LD		A,B
		CALL		SNDBYTE
;データ受信
;HL: addr
;BC: size
MLD1:
		CALL		RCVBYTE			;HLからBC Byte受信
		LD		(HL),A
		DEC		BC
		LD		A,B
		OR		C
		INC		HL
		JR		NZ,MLD1			;BC=0までLOOP

		CALL		RCVBYTE			;状態取得(00H=OK)
		AND		A			;00以外ならERROR
		JP		NZ,MERRD

		JR		MRET       		;正常RETURN


;************************** 0588H VRFY CMT ベリファイ代替処理 *******************
MVRFY:
		XOR		A			;正常終了フラグ
		EI
		RET



;******* 代替処理用コマンドコード送信 (IN:A コマンドコード) **********
MCMD:
		PUSH		AF
		CALL		INIT
		POP		AF
		CALL		SNDBYTE			;コマンドコード送信
		CALL		RCVBYTE			;状態取得(00H=OK)
		AND		A			;バイト数節約のためチェックしてからリターン
		RET

;****** 代替処理用正常RETURN処理 **********
MRET:
		POP		HL
		POP		BC
		POP		DE
		XOR		A
		EI
		RET

;******* 代替処理用ERROR処理 **************
MERRD:
		LD		A,2			;READ/WRITE/DATA ERROR
		JR		MERRC
MERRB:
		XOR		A			;BREAK
MERRC:
		POP		HL
		POP		BC
		POP		DE
		SCF
		EI
		RET

		END
