set MZ=MZ
set PET=PET
set OUT=27C512CG.bin
set TTT=27C512CG.tmp
@rem 1234 ADDR ROM
@rem 0000 0000 MZ-80K JP x 2
copy /b %MZ%\MZ80K.bin + %MZ%\MZ80K.bin %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 0001 1000 MZ-80A EN x 2
copy /b %OUT% + %MZ%\MZ80A.bin + %MZ%\MZ80A.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 0010 2000 MZ-700 JP
copy /b %OUT% + %MZ%\MZ700JP.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 0011 3000 MZ-700 EN
copy /b %OUT% + %MZ%\MZ700EN.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 0100 4000 MZ-80K JP + MZ-80A EN
copy /b %OUT% + %MZ%\MZ80K.bin + %MZ%\MZ80A.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 0101 5000 MZ-80A EN + MZ-80K JP
copy /b %OUT% + %MZ%\MZ80A.bin + %MZ%\MZ80K.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 0110 6000 MZ-700 EN
copy /b %OUT% + %MZ%\MZ700EN.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 0111 7000 MZ-700 JP
copy /b %OUT% + %MZ%\MZ700JP.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 1000 8000 PET BAS1+BAS4
copy /b %OUT% + %PET%\BAS1.bin + %PET%\BAS4.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 1001 9000     BAS4+BAS1
copy /b %OUT% + %PET%\BAS4.bin + %PET%\BAS1.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 1010 A000     GER+BAS4
copy /b %OUT% + %PET%\GER.bin + %PET%\BAS4.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 1011 B000     SWE+BAS4
copy /b %OUT% + %PET%\SWE.bin + %PET%\BAS4.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 1100 C000     NOR+BAS4
copy /b %OUT% + %PET%\NOR.bin + %PET%\BAS4.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 1101 D000     GER+SWE
copy /b %OUT% + %PET%\GER.bin + %PET%\SWE.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 1110 E000     JPN+BAS1
copy /b %OUT% + %PET%\JPN.bin + %PET%\BAS1.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

@rem 1111 F000     JPN+BAS4
copy /b %OUT% + %PET%\JPN.bin + %PET%\BAS4.bin %TTT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND
move /y %TTT% %OUT%
IF not %ERRORLEVEL% equ 0 GOTO ERREND

echo "SUCCESS !"
goto OKEND

:ERREND
echo "ERROR !"

:OKEND
pause
