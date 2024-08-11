LETLN		EQU		0053H			;Hu-BASIC
PRNT		EQU		0013H
PRNTS		EQU		0059H
MSGPR		EQU		000BH
GETKEY		EQU		001BH

DSPX		EQU		000EH			;Hu-BASIC

IBUFE		EQU		10D7H			;Hu-BASIC
FNAME		EQU		IBUFE+1
FSIZE		EQU		IBUFE+18
SADRS		EQU		IBUFE+18+2
EADRS		EQU		IBUFE+18+4
LBUF		EQU		1157H

UP_KEY		EQU		1EH			;カーソル↑ Hu-BASIC

		ORG		003BH			;Hu-BASIC
WRINF:		JP		MSHED
WRDAT:		JP		MSDAT
RDINF:		JP		MLHED
RDDAT:		JP		MLDAT
VERFY:		JP		MVRFY

		ORG		0C7EH			;Hu-BASIC

;**** 文字種初期化 ****
INITCHR:
		PUSH		AF
		PUSH		DE

		LD		DE,MSG_INITCHR
		CALL		MSGPR

		JR		CLRLINE_RET

;**** 1行クリア ****
CLRLINE:
		PUSH		AF
		PUSH		DE

		XOR		A
		LD		(DSPX),A
		LD		DE,MSG_CLRL
		CALL		MSGPR
		XOR		A
		LD		(DSPX),A
CLRLINE_RET:
		POP		DE
		POP		AF
		RET

;*** ファイル名Trimしながらファイル名16文字+0DHを送信 ***
;IN:
;  HL: ファイル名PTR
;   B: 長さ(16 or 14)
;OUT:
;  HL: B+1される。(17 or 15)
;
; Hu-BASIC はファイル名を正規化するので *c/*M で ./.. が以下のようになる。(*Cの場合)
;           "1234567890123456"
; "."   --> "*C              " --> ""
; ".."  --> "*C           .  " --> ".."
; "..." --> "*C           .. " --> "..."
; "ABCDEFGHIJKLMNOPQRSTUVWXYZ.BAS"のようなファイルも拡張子のピリオドを省略して後ろ詰めする。
; "12345678901234567"     "1234567890123456"
; "ABC.BAS"           --> "ABC          BAS" --> "ABC.BAS"
; "ABCDEFGHIJKLM.BAS" --> "ABCDEFGHIJKLMBAS" --> "ABCDEFGHIJKLMBAS" : 長さが超えるので拡張子扱いしない
; →後ろから4文字目がスペース、3文字目がスペース以外なら、3文字目はピリオドに書き換える

FNBUF		EQU		LBUF

SNDFN:
; ワークエリア(FNBUF)へコピー
		PUSH		DE
		PUSH		HL
		PUSH		BC

		LD		DE,FNBUF
		LD		C,B
		LD		B,0
		LDIR
; HL-=3, DE-=3
		LD		C,3		; LD BC,3
		OR		A		; CY=0
		SBC		HL,BC		; CFは立たないはず
		EX		DE,HL
		SBC		HL,BC
		EX		DE,HL
; 後ろから3バイト目のチェック
		LD		A,(DE)
		CP		' '		; 後ろから3バイト目が' 'なら拡張子無し
		JR		Z,SNDFN_NOEXT
		DEC		DE
		LD		A,(DE)
		INC		DE
		CP		' '		; 後ろから4バイト目が' 'で無いなら拡張子無しとする
		JR		NZ,SNDFN_NOEXT
; 拡張子がある場合、スペースで無い文字の後にピリオドを打ってその後ろへ拡張子をコピー
		POP		BC		; 元の文字数復帰
		PUSH		BC
		DEC		B		; B=拡張子の前の文字数
		DEC		B
		DEC		B
; 拡張子の前のTrim
SNDFN_10:
		DEC		DE		; 1文字前がスペースかどうか見る
		LD		A,(DE)
		CP		' '
		JR		NZ,SNDFN_20
		DEC		B
		JR		Z,SNDFN_30
		JR		SNDFN_10
SNDFN_20:
		INC		DE
SNDFN_30:
		LD		A,'.'
		LD		(DE),A
		INC		DE
		LD		BC,3
		LDIR

SNDFN_NOEXT:
		EX		DE,HL
		LD		(HL),0DH	;エンドマーク

; 送るべき長さをレストア --> B
		POP		BC
		PUSH		BC
		LD		HL,FNBUF
;
		LD		D,B		;送信すべきバイト数の保存
		LD		C,0		;送信したバイト数

SNDFN_LOOP1:
		CALL		IS_LAST
		JR		Z,SNDFN_LAST
		LD		A,C
		OR		A		;1バイトでも送信していれば前Trim済み
		LD		A,(HL)
		JR		NZ,SNDFN_SEND	;前Trim済みなら無条件で送信
		CP		' '		;前Trim
		JR		Z,SNDFN_SKIP
SNDFN_SEND:
		CALL		SNDBYTE
		INC		C		;送信したバイト数++
SNDFN_SKIP:
		INC		HL
		DJNZ		SNDFN_LOOP1
SNDFN_LAST:
		LD		A,D		;スキップしたバイト数=(送信すべきバイト数-送信したバイト数)
		SUB		C
		LD		B,A
		INC		B		;エンドマークの0DHのぶん
SNDFN_LOOP2:
		LD		A,0DH
		CALL		SNDBYTE
		INC		HL
		DJNZ		SNDFN_LOOP2

		POP		BC
; HLを進める
		POP		HL
		LD		D,0
		LD		E,B
		ADD		HL,DE
		INC		HL
		POP		DE
		RET

MSG_INITCHR:	DB		15H,11H,0D,0		;英数、大文字、CR
MSG_CLRL:	DB		05H,0			;CTRL-E
MSG_KEY:	DB		"N/B/UP/SH+BRK",0DH,00H
MSG_LOAD:	DB		"LOAD",22H,00H

;**** 共通部 ****
		CHAIN "COMMON.s"

		END

