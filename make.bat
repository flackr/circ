@ECHO OFF
set target=%1
IF "%target%"=="" set target=all

for /f %%j in ("node.exe") do (
  set NODE_HOME=%%~dp$PATH:j
)
for /f %%j in ("coffee.cmd") do (
  set COFFEE_HOME=%%~dp$PATH:j
)
if "%NODE_HOME%"=="" GOTO NONODE 
if "%COFFEE_HOME%"=="" GOTO NOCOFFEE 

IF "%target%"=="all" GOTO BUILD 
IF "%target%"=="package" GOTO BUILD 
IF "%target%"=="test" GOTO BUILD 
GOTO :EOF

:NONODE 
echo "Missing node.exe, please download and install NodeJS from http://nodejs.org/"
GOTO :EOF

:NOCOFFEE 
echo "Missing coffee, please run: npm install -g coffee-script"
GOTO :EOF

:BUILD
echo "Building CIRC." 
rmdir bin /s /q
mkdir bin
copy src\*.* bin
copy src\chat\* bin
copy src\irc\* bin
copy src\net\* bin
copy src\script\* bin
copy src\script\prepackaged\source_array.coffee bin
copy third_party\*.js bin
mkdir bin\font
copy static\font\*.* bin\font
call coffee -c bin
IF %ERRORLEVEL% GEQ 1 GOTO :EOF
del bin\*.coffee
IF "%target%"=="package" GOTO PACKAGE 

:TEST 
echo "Creating tests, run test.bat or open bin\test_runner.html in your browser."
mkdir bin\mocks
copy test\*.* bin
copy test\mocks\*.* bin
mkdir bin\jasmine-1.2.0
xcopy /E /Y third_party\jasmine-1.2.0 bin\jasmine-1.2.0
call coffee -c bin
IF %ERRORLEVEL% GEQ 1 GOTO :EOF
del bin\*.coffee
IF "%target%"=="test" start bin\test_runner.html
IF "%target%"=="test" GOTO :EOF

:PACKAGE 
echo "Creating packaged app in directory 'package'."
rmdir package /s /q
mkdir package
mkdir package\bin
xcopy /E /Y bin package\bin
mkdir package\static
mkdir package\static\icon
copy static\icon\*.png package\static\icon
copy manifest.json package
