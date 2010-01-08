@echo off
rem   Wrapper around perl that keeps the window open, to allow inspection of
rem   output messages.
echo Invoking dizzy %*
..\strawberry\perl\bin\perl.exe %*
pause
