set target=%1
IF "%target%"=="" set target=all

IF "%target%"=="all" GOTO BUILD
IF "%target%"=="package" GOTO BUILD
IF "%target%"=="test" GOTO BUILD
GOTO EXIT

:BUILD
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
del bin\*.coffee
IF "%target%"=="package" GOTO PACKAGE

:TEST
mkdir bin\mocks
copy test\*.* bin
copy test\mocks\*.* bin
mkdir bin\jasmine-1.2.0
xcopy /E third_party\jasmine-1.2.0 bin\jasmine-1.2.0
call coffee -c bin
del bin\*.coffee
IF "%target%"=="test" GOTO EXIT

:PACKAGE
rmdir package /s /q
mkdir package
mkdir package\bin
xcopy /E bin package\bin
mkdir package\static
mkdir package\static\icon
copy static\icon\*.png package\static\icon
copy manifest.json package

:EXIT