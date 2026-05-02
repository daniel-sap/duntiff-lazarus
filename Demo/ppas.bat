@echo off
SET THEFILE=D:\Project\Lazarus\Packages\FileFormats\DunTif\Demo\DunTifDemo.exe
echo Linking %THEFILE%
D:\Dev\Lazarus\fpc\3.2.2\bin\x86_64-win64\ld.exe -b pei-x86-64  --gc-sections   --subsystem windows --entry=_WinMainCRTStartup    -o D:\Project\Lazarus\Packages\FileFormats\DunTif\Demo\DunTifDemo.exe D:\Project\Lazarus\Packages\FileFormats\DunTif\Demo\link10860.res
if errorlevel 1 goto linkend
goto end
:asmend
echo An error occurred while assembling %THEFILE%
goto end
:linkend
echo An error occurred while linking %THEFILE%
:end
