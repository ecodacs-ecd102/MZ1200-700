; =====================================================================================
;   MZ-1R12 モドキ
;   128KB (64KBx2) version
; =====================================================================================

LETNL		EQU		0006H
QNL		EQU		0009H		; [kaokun]: Use entry
PRNT		EQU		0012H
MSG		EQU		0015H
GETKY		EQU		001BH
RDINF		EQU		0027H
RDDAT		EQU		002AH

;[kaokun]
TIMST		EQU		0033H		; Set TIME: A:0=AM, 1=PM; DE=seconds
XTEMP		EQU		0041H		; Tempo set: default: AL=4
MSTP		EQU		0047H		; Stop Melody

NAME		EQU		10F1H
SIZE		EQU		1102H
DTADR		EQU		1104H
COMNT		EQU		1108H

LBUF		EQU		11A3H

SP_BOTTOM	EQU		10F0H
MONITOR_80K	EQU		0082H
MONITOR_700	EQU		00ADH
MONITOR_NEWMON	EQU		0082H			;with stack init
MONITOR_NEWMON7	EQU		0082H
MONITOR_80A	EQU		0095H

; MZ80K-SD/kao Specific work
CONTF		EQU		11FFH			; for FD: command
CONTF_ON	EQU		':'			; ':' なら連続ロード中を示す

; Tape
BRKEY		EQU		001EH
CSTR		EQU		0E002H
CSTPT		EQU		0E003H


		ORG	0E800H


; =====================================================================================
;   拡張ROMエントリ
; =====================================================================================
MZ1R12:
		NOP				; ROM Exists
;[kaokun]: ボードが無いときと、"*B" コマンド実行時の副作用で来たときはコマンドラインに戻る
		XOR	A

		DI				; スタックなど念のためイニシャライズ
		LD	SP,SP_BOTTOM
		LD	(CONTF),A		; MZ-80K SDのスペシャルバージョンの連続ロードフラグを念のためクリアする
		CALL	CHK_BOARD		; ボード存在チェック
		JP	C,MON2			; ボード無し

		LD	A,(LBUF)
		CP	'*'			;ラインバッファが"*B"か？
		JR	NZ,MZ1R12_START
		LD	A,(LBUF+1)
		CP	'B'
		JR	NZ,MZ1R12_START

;*Bだったので何もせずコマンド待ちへ
		LD	HL,0			; ここでリセットしたときに次回起動するように潰しておく
		LD	(LBUF),HL
		JP	MON2

; =====================================================================================
;   メニュー表示
; =====================================================================================
MZ1R12_START:
		LD	A,16H
		CALL	PRNT
		CALL	LETNL
		CALL	LETNL
ST1X:
		CALL	LETNL
		CALL	LETNL
		LD	DE,MSG_PRESS_RWM	; 'PRESS R, W OR M'
		CALL	MSG
		CALL	LETNL
		CALL	LETNL
		LD	DE,MSG_R_READ		; 'R: READ   S-RAM'
		CALL	MSG
		CALL	LETNL
		LD	DE,MSG_W_WRITE		; 'W: WRITE  S-RAM'
		CALL	MSG
		CALL	LETNL
		LD	DE,MSG_M_MONITOR	; 'M: MONITOR'
		CALL	MSG
		CALL	LETNL
		JR	KEY_INPUT


;MSG_PRESS_RWM:	DB	'           P',05H,'RESS',05H,' R , W ',05H,'OR',05H,' M',0DH
;MSG_R_READ:	DB	'            R:',05H,'READ',05H,'  S-RAM',0DH
;MSG_W_WRITE:	DB	'            W:',05H,'WRITE',05H,' S-RAM',0DH
;MSG_M_MONITOR:	DB	'            M:',05H,'MONITOR',05H,0DH

MSG_PRESS_RWM:	DB	'           PRESS R , W OR M',0DH
MSG_R_READ:	DB	'            R:READ  S-RAM',0DH
MSG_W_WRITE:	DB	'            W:WRITE S-RAM',0DH
MSG_M_MONITOR:	DB	'            M:MONITOR',0DH


; =====================================================================================
;   キー入力
; =====================================================================================
KEY_INPUT:
		CALL	GETKY
		CP	'M'
		JP	Z,MON1
		CP	'W'
		JP	Z,WRITE_COMMAND
		CP	'R'
		JP	Z,READ_COMMAND
		JP	NZ,KEY_INPUT

; =====================================================================================
;   READ S-RAM
; =====================================================================================
READ_COMMAND:
		LD	A,16H
		CALL	PRNT
		CALL	LETNL
		CALL	LETNL
		CALL	LETNL
		LD	DE,MSG_LOADING_SRAM	; 'LOADING PROGRAM FROM S-RAM'
		CALL	MSG
		CALL	LETNL
		CALL	LETNL
		CALL	CHECK			; Information's sum check
		JP	NZ,ERR_CSUM		; Check sum error
		IN	A,(0F8H)	 	; Counter reset
; ヘッダ 8 byte (Little Endian) + 1
; 00 W Size
; 02 W From
; 04 W Exec
; 06 W Check Sum
; 08 B ヘッダのチェックサム (ヘッダ8バイトの中の1のビット数)

		IN	A,(0F9H)		; Size L
		LD	C,A
		IN	A,(0F9H)		; Size H
		LD	B,A			; BC=SIZE

		IN	A,(0F9H)		; From L
		LD	L,A
		IN	A,(0F9H)		; From H
		LD	H,A			; HL=FROM

		IN	A,(0F9H)		; Exec L
		LD	E,A
		IN	A,(0F9H)		; Exec H
		LD	D,A			; DE=EXEC

		PUSH	DE			; PUSH EXEC

		LD	D,B			; DE:=Size
		LD	E,C

		IN	A,(0F9H)		; Check Sum L
		LD	C,A
		IN	A,(0F9H)		; Check Sum H
		LD	B,A			; BC:=SUM

		IN	A,(0F9H)		; ヘッダチェックサムを読み飛ばす

		PUSH	BC			; SUM
		PUSH	DE			; SIZE
		PUSH	HL			; FROM

		LD	C,0F9H

		LD	A,E
		OR	A
		JR	Z,RD1			; 端数無し
		LD	B,E			; 下位バイトに端数があるとき、最初に実行
		INIR
	; 以下、D x 256 バイトぶん実行
RD1:
		LD	A,D
		OR	A
		JR	Z,RD99			; 上位が0なら終わり
		LD	B,128
		INIR
		LD	B,128
		INIR
		DEC	D
		JR	RD1
RD99:
		POP	DE			; FROM
		POP	BC			; SIZE
		CALL	SUM			; HL:=SUM
		POP	DE			; SUM
		OR	A
		SBC	HL,DE			; HL==DE ?
		JR	NZ,ERR_CSUM
;
; [kaokun] アプリ動作が固まってしまうアプリへの対処
		EI				;カセットリード後EIになっているようなので踏襲
		LD	A,00H			;TI$="000000"
		LD	DE,0000H
		CALL	TIMST
		LD	A,4			;Init Music
		CALL	XTEMP
		CALL	MSTP
;
		POP	HL
		LD	A,H			;[kaokun]:$1200より前の値はオートスタート無し
		CP	012H
		JP	C,MON2
		JP	(HL)


; =====================================================================================
;   sum check
; =====================================================================================
; IN BC=Size
;    DE=Data adr
; EXIT HL=Check sum
;
SUM:
		PUSH	BC
		PUSH	DE
		EXX
		LD	HL,0000H		; HL'= Check sum clr
		LD	C,08H			; C' = Loop count in a byte
		EXX
SUMCK1:
		LD	A,B			; BC = Size
		OR	C
		JR	Z,SUMCK99
		LD	A,(DE)			; DE = Data adrs
		EXX
		LD	B,C			; BC'
SUMCK2:
		RLCA
		JR	NC,SUMCK3
		INC	HL			; HL' = Check sum data
SUMCK3:
		DJNZ	SUMCK2
		EXX
		INC	DE			; DE
		DEC	BC			; BC
		JP	SUMCK1
SUMCK99:
		EXX
		POP	DE
		POP	BC
		RET



;
; =====================================================================================
;   Information's sum check
; =====================================================================================
;
;
CHECK:
		IN	A,(0F8H)		 ; Counter reset
; ヘッダ 8 byte (Little Endian) + 1
; 00 W Size
; 02 W From
; 04 W Exec
; 06 W Check Sum
; 08 B ヘッダのチェックサム (ヘッダ8バイトの中の1のビット数)
		LD	BC,0800H		; B=Byte Counter C=Sum Counter
CK1:
		IN	A,(0F9H)	 	; Counter=Counter+1
		PUSH	BC
		LD	B,08H			; Bit Counter
CK2:
		RLCA
		JR	NC,CK3
		INC	C
CK3:
		DJNZ	CK2
		LD	A,C
		POP	BC
		LD	C,A
		DJNZ	CK1
		IN	A,(0F9H)
		CP	C
		RET


ERR_CSUM:
		LD	A,16H
		CALL	PRNT
		CALL	LETNL
		CALL	LETNL
		LD	DE,MSG_CSUMERR		; 'CHECK SUM ERROR'
		CALL	LF_PRINT
		JP	ST1X

; =====================================================================================
;   WRITE  S-RAM
; =====================================================================================
WRITE_COMMAND:
		LD	A,16H
		CALL	PRNT
		CALL	LETNL
		CALL	LETNL
		CALL	LETNL

		LD	DE,MSG_SRAM_PRG		; 'S-RAM PROGRAMMING'
		CALL	LF_PRINT_LF
		CALL	LETNL

		CALL	CHECK_SD_PATCH		;ROMがSDパッチされているかチェック: CY=1されていない
		JR	C,WR_DISP_PLAY

		CALL	LETNL
		JR	WR_00

WR_DISP_PLAY:
		LD	DE,MSG_SET_TAPE		; 'SET MASTER TAPE  PLAY'
;		CALL	 GET_BG_COLOR		; [KAOKUN] A=11H or 00H
;		LD	 HL,0D8F0H		; Hide "PLAY↓"
;		CALL	 FILL_6BYTESS		;
		CALL	PRINT_LF
		CALL	MOTOR_ON_NO_MSG		;モーターONを待つ
		JP	C,ERR_DISP		;BREAK
WR_00:
		CALL	RDINF
		JP	C,ERR_DISP

		PUSH	AF
		PUSH	BC
		LD	BC,(SIZE)
		CALL	IS_64K
		JR	C,WR_32K
; 64Kバージョンのサイズチェック
; ヘッダが9バイトあるので、10000H-6 = 0FFF7H バイトまでまで良いはずだけど 0FFF6までとする
WR_64K:
		LD	A,B			; B < 0FFH ?
		CP	0FFH
		JR	C,WR1			; OK
		LD	A,0F6H
		CP	C
		JR	C,WR2			; too long
		JR	WR1
; 32Kバージョンのサイズチェック
; ヘッダが9バイトあるので、8000H-6 = 7FF7H バイトまで良いはずだけど 7FF6までとする
WR_32K:
		LD	A,7FH
		CP	B
		JR	C,WR2			; 80-FF: too long
		JR	NZ,WR1			; 00-7E: OK
		LD	A,0F6H
		CP	C
		JR	C,WR2			; F7-FF: too long
WR1:
		POP	BC
		POP	AF
		JR	WR3
WR2:
		POP	BC
		POP	AF
		JP	ERR_TOO_LONG

WR3:
;		LD	A,00H			;Erase "PLAY↓"
;		LD	HL,0D0F0H
;		CALL	FILL_6BYTESS
;		CALL	GET_FG_COLOR		; [KAOKUN] A=71H or 40H
;		LD	HL,0D8F0H
;		CALL	FILL_6BYTESS
;		LD	A,02H
;		JP	C,ERR_DISP

		CALL	LETNL
		LD	DE,MSG_FOUND		; 'FOUND : '
		CALL	LF_PRINT
		LD	DE,NAME
		PUSH	DE
		RST	18H
		CALL	LETNL
		LD	DE,MSG_LOADING		; 'LOADING : '
		CALL	LF_PRINT
		POP	DE
		RST	18H
;
;	Read data block
;
		CALL	RDDAT
		JR	C,ERR_DISP
;
;	Counter reset
;
		IN	A,(0F8H)
;
;		Sum check for data
;
		LD	DE,(DTADR)
		LD	BC,(SIZE)
		PUSH	DE			; DTADR {
		PUSH	BC			; SIZE [
		CALL	SUM
		LD	(COMNT),HL
;
;	Write information (8Byte)
;
		LD	HL,SIZE
		LD	BC,08FAH		; B=Byte Counter=8, C=Write Data I/O Port=FA
		PUSH	HL
		PUSH	BC
		OTIR
		POP	BC
		POP	HL
;
;	Sum check for information block
;	    AccCheck sum data
;
		PUSH	DE			; DE: DTADR (
		LD	D,00H			; Sum Counter
WCK1:
		PUSH	BC			; { B=LOOP counter
		LD	B,08H
		LD	A,(HL)
WCK2:
		RLCA
		JR	NC,WCK3
		INC	D
WCK3:
		DJNZ	WCK2
		INC	HL
		POP	BC			; } B=LOOP COUNTER
		DJNZ	WCK1
		LD	A,D
		POP	DE			; ) DE: DTADR
		OUT	(0FAH),A
;
;	Write data block
;
		POP	DE			; ] DE: SIZE
		POP	HL			; } HL: DTADR

		LD	A,E
		OR	A
		JR	Z,WR4			; 端数無し
		LD	B,E			; 下位バイトに端数があるとき、最初に実行
		OTIR
	; 以下、D x 256 バイトぶん実行
WR4:
		LD	A,D
		OR	A
		JR	Z,WR99			; 上位が0なら終わり
		LD	B,128
		OTIR
		LD	B,128
		OTIR
		DEC	D
		JR	WR4
WR99:
		LD	A,16H
		CALL	PRNT
		CALL	LETNL
		CALL	LETNL
		LD	DE,MSG_WR_RAM_OK	; 'WRITING S-RAM O.K.!'
		CALL	MSG
		JP	ST1X

; =====================================================================================
; 改行して
; DE～の文字列を表示して
; 改行する。
; =====================================================================================
LF_PRINT_LF:
		CALL	QNL

; =====================================================================================
; DE～の文字列を表示して
; 改行する。
; =====================================================================================
PRINT_LF:
		RST	18H			;MSGX
		JP	QNL

; =====================================================================================
; 改行して、
; DE～の文字列を表示する。
; =====================================================================================
LF_PRINT:
		CALL	QNL
		RST	18H
		RET

; =====================================================================================
; エラー表示
; A=02H : BREAK
; 他    : CHECK SUM ERROR
; =====================================================================================
ERR_DISP:
		CP	02H
		JP	Z,ERR_BREAK
		JP	ERR_CSUM

;FILL_6BYTESS:
;		LD	B,06H
;FIL6_1:
;		LD	(HL),A
;		INC	HL
;		DEC	B
;		JR	NZ,FIL6_1
;		RET

; =====================================================================================
; BREAK
; =====================================================================================
ERR_BREAK:
		LD	A,16H
		CALL	PRNT
		CALL	LETNL
		CALL	LETNL
		LD	DE,MSG_BREAK	    ; 'BREAK !'
		CALL	MSG
		JP	ST1X

; =====================================================================================
; TOO LONG
; =====================================================================================
ERR_TOO_LONG:
		LD	DE,0000H
		LD	(SIZE),DE
		LD	A,16H
		CALL	PRNT
		CALL	LETNL
		CALL	LETNL
		LD	DE,MSG_FILE_TOO_LONG	    ; 'FILE IS TOO LONG'
		CALL	MSG
		JP	ST1X


;MSG_CSUMERR:	DB      '           C',05H,'HECK SUM ERROR',05H,0DH
;MSG_SRAM_PRG:	DB      '           S-RAM ',05H,'PROGRAMMING',05H,0DH
;MSG_SET_TAPE:	DB      '        S',05H,'ET MASTER TAPE',05H,'   ',7FH,'P',05H,'LAY',05H,'  ',0DH
;MSG_FOUND:	DB      '         F',05H,'OUND',05H,'  : ',0DH
;MSG_LOADING:	DB      '         L',05H,'OADING',05H,': ',0DH
;MSG_LOADING_SRAM: DB   '      L',05H,'OADING PROGRAM FROM ',05H,'S-RAM',0DH
;LEB3E:		DB      '**  MONITOR 1Z-009A  **',0DH
;MSG_RD_RAM_OK:	DB      '           R',05H,'EADING',05H,' S-RAM O.K.!',0DH
;MSG_BREAK:	DB      '           B',05H,'REAK',05H,' !',0DH
;MSG_WR_RAM_OK:	DB      '           W',05H,'RITING',05H,' S-RAM O.K.!',0DH
;MSG_FILE_TOO_LONG: DB  '           F',05H,'ILE IS TOO LONG',05H,0DH

MSG_CSUMERR:	DB      '           CHECK SUM ERROR',0DH
MSG_SRAM_PRG:	DB      '           S-RAM PROGRAMMING',0DH
MSG_SET_TAPE:	DB      '        SET MASTER TAPE   ',7FH,'PLAY  ',0DH
MSG_FOUND:	DB      '         FOUND  : ',0DH
MSG_LOADING:	DB      '         LOADING: ',0DH
MSG_LOADING_SRAM: DB    '      LOADING PROGRAM FROM S-RAM',0DH
MSG_RD_RAM_OK:	DB      '           READING S-RAM O.K.!',0DH
MSG_BREAK:	DB      '           BREAK !',0DH
MSG_WR_RAM_OK:	DB      '           WRITING S-RAM O.K.!',0DH
MSG_FILE_TOO_LONG: DB   '           FILE IS TOO LONG',0DH


; =====================================================================================
;  ボードの存在チェック
;  CY=No board
; =====================================================================================
CHK_BOARD:	; Check if board exists
		IN		A,(0F8H)		; Counter reset
		IN		A,(0F9H)		; Save data
		PUSH		AF

		LD		A,0
		CALL		CHK_BOARD_SUB
		JR		NZ,CHK_BOARD_NG

		LD		A,0FFH
		CALL		CHK_BOARD_SUB
		JR		NZ,CHK_BOARD_NG

		LD		A,55H
		CALL		CHK_BOARD_SUB
		JR		NZ,CHK_BOARD_NG

		LD		A,0AAH
		CALL		CHK_BOARD_SUB
		JR		NZ,CHK_BOARD_NG

		POP		AF
		CALL		CHK_BOARD_SUB
		JR		NZ,CHK_BOARD_NG

		XOR		A			; OK
		RET

CHK_BOARD_NG:
		POP		AF
		XOR		A
		SCF
		RET

CHK_BOARD_SUB:
		PUSH		BC
		LD		C,A
		IN		A,(0F8H)		; Counter reset
		LD		A,C
		OUT		(0FAH),A		; WRITE, Counter++
		IN		A,(0F8H)		; Counter reset
		IN		A,(0F9H)		; READ, Counter++
		CP		C			; CHECK
		IN		A,(0F8H)		; Counter reset
		LD		A,C
		POP		BC
		RET

; =====================================================================================
;  ボードが64Kあるか調べる
;    CY=0: 64K
;    CY=1: 32K
;
;  I/O	OUT		IN
;  F8	Sets Counter H	Resets Counter
;  F9	Sets Counter L	Reads DATA
;  FA	Writes DATA	N/A
;
; =====================================================================================
IS_64K:
		PUSH		HL
		PUSH		BC

	; SAVE ($0000)
		LD		HL,0000H
		CALL		SET_COUNTER_ADDRESS
		IN		A,(0F9H)		; READ, Counter++
		LD		B,A			; Save data : B=($0000)

	; SAVE ($8000)
		LD		HL,8000H
		CALL		SET_COUNTER_ADDRESS
		IN		A,(0F9H)		; READ, Counter++
		LD		C,A			; Save data : C=($8000)

	; ($0000)=$55
		LD		HL,0000H
		CALL		SET_COUNTER_ADDRESS
		LD		A, 055H
		OUT		(0FAH),A		; WRITE, Counter++

	; ($8000)=$AA
		LD		HL,8000H
		CALL		SET_COUNTER_ADDRESS
		LD		A, 0AAH
		OUT		(0FAH),A		; WRITE, Counter++

	; Check if ($0000) == $55
		LD		HL,0000H
		CALL		SET_COUNTER_ADDRESS
		IN		A,(0F9H)		; READ, Counter++
		SUB		055H			; CHECK
		JR		Z,BOARD_64K
		SCF					; 32K
BOARD_64K:
	; RESTORE ($8000):  Save data : C=($8000)
		LD		HL,8000H
		CALL		SET_COUNTER_ADDRESS
		LD		A, C
		OUT		(0FAH),A		; WRITE, Counter++

	; RESTORE ($0000):  Save data : B=($0000)
		LD		HL,0000H
		CALL		SET_COUNTER_ADDRESS
		LD		A, B
		OUT		(0FAH),A		; WRITE, Counter++

		POP		BC
		POP		HL
		RET

; =====================================================================================
;  アドレスセット
;   HL --> アドレスカウンタへセット
; =====================================================================================
SET_COUNTER_ADDRESS:
		PUSH		AF
		LD		A,H
		OUT		(0F8H),A		; HIGH
		LD		A,L
		OUT		(0F9H),A		; LOW
		POP		AF
		RET

; =====================================================================================
;  モニタのエントリアドレスを得る
;  DE=OPENING MSG, HL=ENTRY, CY=UNKNOWN, B=文字色, C=BG色
; =====================================================================================
GET_MON_ADDR:
		LD		A,(014EH)
		CP		'P'			;014EHが'P'ならMZ-80K

		LD		DE,0141H		;"**  MONITOR..." などオープニングメッセージのアドレス
		LD		BC,4040H		;Green, Black
		LD		HL,MONITOR_80K
		JP		Z,COMMON
		CP		'N'			;014EHが'N'ならFN-700
		LD		HL,MONITOR_80K
		LD		BC,7111H		;White, Blue
		JP		Z,COMMON
		CP		20H			;014EHが' 'ならMZ-NEW MONITOR MZ-80K ("MONITOR VER"のスペース)
		LD		HL,MONITOR_NEWMON
		LD		BC,4040H		;Green, Black
		JP		Z,COMMON
		LD		A,(0145H)
		CP		'7'			;0145Hが'7'ならMZ-NEW MONITOR MZ-700 ("MZ700"の"7")
		LD		HL,MONITOR_NEWMON7
		LD		BC,7171H		;White, Blue
		JP		Z,COMMON

		LD		A,(010DH)		;010DHが'A'ならMZ-80A ("SA-1510"の"A")
		CP		'A'
		LD		DE,0100H		;"** SA-1510...
		LD		HL,MONITOR_80A
		LD		BC,4040H		;Green, Black
		JP		Z,COMMON

		LD		A,(06EBH)
		CP		'M'			;06EBHが'M'ならMZ-700 (JP/EU 共通)
		LD		DE,06E7H		;"** MONITOR 1Z-.."
		LD		HL,MONITOR_700
		LD		BC,7111H		;White, Blue
		JP		Z,COMMON
; UNKNOWN ROM: CY=1
		LD		DE,0
		LD		HL,0
		LD		BC,4000H		;Green, Black
		SCF
		RET
COMMON:
		XOR		A			; CY=0
		RET

;GET_FG_COLOR:
;		PUSH		HL
;		PUSH		DE
;		PUSH		BC
;		CALL		GET_MON_ADDR
;		LD		A,B
;		JR		GET_BG_RET
;GET_BG_COLOR:
;		PUSH		HL
;		PUSH		DE
;		PUSH		BC
;		CALL		GET_MON_ADDR
;		LD		A,C
;GET_BG_RET:
;		POP		BC
;		POP		DE
;		POP		HL
;		RET

; =====================================================================================
;  モニタのコマンド待ちへ
; =====================================================================================
MON1:
		LD		A,16H			;CLS
		CALL		PRNT
		CALL		GET_MON_ADDR		;DE=OPENING MSG, HL=ENTRY, CY=UNKNOWN
		PUSH		HL
		CALL		NC,MSG
		RET					;Jump to Entry

MON2:
		CALL		GET_MON_ADDR		;DE=OPENING MSG, HL=ENTRY, CY=UNKNOWN
		PUSH		HL
		RET					;Jump to Entry

; =====================================================================================
; PLAY↓を出さずモーターONを待つ
; =====================================================================================
;
; CY=0: OK
; CY=1: BREAK (A=02H)
;

MOTOR_ON_NO_MSG:
		PUSH	BC
		PUSH	DE
		PUSH	HL
MOTOR_ON_L1:
		LD	C,10		; 10回トライ
MOTOR_ON_L2:
		LD	A,(CSTR)	; Motor ON ?
		AND	10H
		JR	Z,MOTOR_ON_FF	; OFF => Try to ON
		XOR	A		; A=0, CY=OFF
		JR	MOTOR_ON_RET	; RETURN
MOTOR_ON_FF:
		LD	A,06H		; Try to flip MOTOR FF
		LD	HL,CSTPT
		LD	(HL),A
		INC	A
		LD	(HL),A
		DEC	C
		JR	NZ,MOTOR_ON_L2	; Check Motor again
; 以下モータONの10回試行後
		CALL	BRKEY		; SHIFT + BREAK チェック
		JR	NZ,MOTOR_ON_L1	; 押されていなければ最初から
		LD	A,02H
		SCF			; BREAK 時は A=2, CY=1 でリターン
MOTOR_ON_RET:
		POP	HL
		POP	DE
		POP	BC
		RET

; =====================================================================================
;  ROMがSDパッチされているかチェック
;   APPLIED	: A=0,	Z=1, CY=0
;   NOT APPLIED : A=NZ, Z=0, CY=1
; =====================================================================================
CHECK_SD_PATCH:
		PUSH	HL
		LD	HL,(RDINF+1)		; HL=RDINFの飛び先
		INC	HL			; F3 をSKIP
		LD	A,(HL)
		SUB	0C3H			; JP命令に書き換わっているか？
		JR	NZ,SD_PATCH_NOT_APPLIED
		LD	A,(0F000H)		; FD ROMがあるか？
		OR	A			; 00=ROMあり
		JR	Z,SD_PATCH_APPLIED
SD_PATCH_NOT_APPLIED:
		SCF
SD_PATCH_APPLIED:
		POP	HL
		RET

; =====================================================================================
;  Padding
; =====================================================================================
NOW:
		DS	0F000H - NOW



		END
