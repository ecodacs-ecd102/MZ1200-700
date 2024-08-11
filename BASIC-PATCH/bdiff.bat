@echo off
if "%2" == "" (
  echo.
  echo Usage:
  echo   bdiff file1.bin file.bin
  GOTO :END
)
echo Left :%~1
echo Right:%~2
cmp -l "%~1" "%~2" | gawk -e '{printf "%%08X %%02X %%02X\n", $1-1, strtonum(0$2), strtonum(0$3)}'
:END
