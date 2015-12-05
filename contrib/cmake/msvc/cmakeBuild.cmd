@echo off
setlocal enableextensions

set "_BUILDDIR_=%CD%"

:GETOPTS
if /I "%1" == "--help" (
   call:Help
   exit /b
)
if /I "%1" == "--webready"        set "_WEBREADY_=1"
if /I "%1" == "--config"          set "_CONFIG_=%2"& shift
if /I "%1" == "--temp"            set "_TEMP_=%2"& shift
if /I "%1" == "--generator"       set "_GENERATOR_=%2"& shift
if /I "%1" == "--exiv2"           set "_EXIV2_=%2"& shift
if /I "%1" == "--verbose"         set ("_VERBOSE_=1 && echo on)"
if /I "%1" == "--dryrun"          set "_DRYRUN_=1"
if /I "%1" == "--rebuild"         set "_REBUILD_=1"
if /I "%1" == "--silent"          set "_SILENT_=1"
if /I "%1" == "--silent"          set "_QUIET_=1"
if /I "%1" == "--quiet"           set "_QUIET_=1"
if /I "%1" == "--video"           set "_VIDEO_=1"
if /I "%1" == "--pause"           set "_PAUSE_=1"
if /I "%1" == "--zlib"            set "_ZLIB_=%2"& shift
if /I "%1" == "--expat"           set "_EXPAT_=%2"& shift
if /I "%1" == "--libssh"          set "_LIBSSH_=%2"& shift
if /I "%1" == "--curl"            set "_CURL_=%2"& shift
if /I "%1" == "--openssl"         set "_OPENSSL_=%2"& shift
if /I "%1" == "--test"            set "_TEST_=1"
if /I "%1" == "--static"          set "_TYPE_=1"
if /I "%1" == "--bash"            set "_BASH_=%2"& shift

shift
if not (%1) EQU () goto GETOPTS

if NOT DEFINED _SILENT_ set _VERBOSE_=1
set _UNSUPPORTED_=

rem  ----
call:echo calling cmakeDefaults.cmd
call cmakeDefaults
IF ERRORLEVEL 1 (
	echo "*** setenv.cmd has failed ***" >&2
	GOTO error_end
)

rem  ----
call:echo checking that %_EXIV2_% exists
if NOT EXIST %_EXIV2_% (
	echo "_EXIV2_ = %_EXIV2_% does not exist ***" >&2
	exit /b 1
)
pushd %_EXIV2_%
set _EXIV2_=%CD%
popd
call:echo _EXIV2_ = %_EXIV2_%

rem  ----
call:echo testing VSINSTALLDIR "%VSINSTALLDIR%"
IF NOT DEFINED VSINSTALLDIR (
	echo "VSINSTALLDIR not set.  Run vcvars32.bat or vcvarsall.bat ***"
	GOTO error_end
)
IF NOT EXIST "%VSINSTALLDIR%" (
	echo "VSINSTALLDIR %VSINSTALLDIR% does not exist.  Run vcvars32.bat or vcvarsall.bat ***"
	GOTO error_end
)

rem http://stackoverflow.com/questions/9252980/how-to-split-the-filename-from-a-full-path-in-batch
for %%A in ("%VSINSTALLDIR%") do (
    set "VS_PROG_FILES=%%~nA"
)
if /I "%VSINSTALLDIR%" == "C:\Program Files (x86)\Microsoft Visual Studio 14.0\" set "VS_PROG_FILES=Microsoft Visual Studio 14"
if /I "%VSINSTALLDIR%" == "C:\Program Files (x86)\Microsoft Visual Studio 12.0\" set "VS_PROG_FILES=Microsoft Visual Studio 12"
if /I "%VSINSTALLDIR%" == "C:\Program Files (x86)\Microsoft Visual Studio 11.0\" set "VS_PROG_FILES=Microsoft Visual Studio 11"
if /I "%VSINSTALLDIR%" == "C:\Program Files (x86)\Microsoft Visual Studio 10.0\" set "VS_PROG_FILES=Microsoft Visual Studio 10"
if /I "%VSINSTALLDIR%" == "C:\Program Files (x86)\Microsoft Visual Studio 9.0\"  set "VS_PROG_FILES=Microsoft Visual Studio 9"
if /I "%VSINSTALLDIR%" == "C:\Program Files (x86)\Microsoft Visual Studio 8.0\"  set "VS_PROG_FILES=Microsoft Visual Studio 8"
call:echo VS_PROG_FILES = "%VS_PROG_FILES%"

rem  ----
call:echo setting CMake Generator
if        /I "%VS_PROG_FILES%" == "Microsoft Visual Studio 14" (
        set   "VS_CMAKE=Visual Studio 14 2015"
        set   "VS_OPENSSL=vs2015"
        set   "_VS_=2015"
        set   "_VC_=14"
) else if /I "%VS_PROG_FILES%" == "Microsoft Visual Studio 12" (
        set   "VS_CMAKE=Visual Studio 12 2013"
        set   "VS_OPENSSL=vs2013"
        set   "_VS_=2013"
        set   "_VC_=12"
) else if /I "%VS_PROG_FILES%" == "Microsoft Visual Studio 11" (
        set   "VS_CMAKE=Visual Studio 11 2012"
        set   "VS_OPENSSL=vs2012"
        set   "_VS_=2012"
        set   "_VC_=11"
) else if /I "%VS_PROG_FILES%" == "Microsoft Visual Studio 10" (
        set   "VS_CMAKE=Visual Studio 10 2010"
        set   "VS_OPENSSL=vs2010"
        set   "_VS_=2010"
        set   "_VC_=10"
) else if /I "%VS_PROG_FILES%" == "Microsoft Visual Studio 9"  (
        set   "VS_CMAKE=Visual Studio 9 2008"
        set   "VS_OPENSSL=vs2008"
        set   "_VS_=2008"
        set   "_VC_=9"
) else if /I "%VS_PROG_FILES%" == "Microsoft Visual Studio 8"  (
        set   "VS_CMAKE=Visual Studio 8 2005"
        set   "VS_OPENSSL=vs2005"
        set   "_VS_=2005"
        set   "_VC_=8"
) else (
        echo "*** Unsupported version of Visual Studio in '%VSINSTALLDIR%' ***"
	    GOTO error_end
)

call:echo testing architecture
if "%PROCESSOR_ARCHITECTURE%" EQU "AMD64" ( 
	set Platform=x64
	set RawPlatform=x64
	set CpuPlatform=intel64
) ELSE (
	set Platform=Win32
	set RawPlatform=x86
	set CpuPlatform=ia32
)

IF %Platform% EQU x64 (
	set "VS_CMAKE=%VS_CMAKE% Win64"
)
call:echo Platform = %Platform% (%RawPlatform%)

rem  ----
call:echo testing out of source build
dir/s exiv2.cpp >NUL 2>NUL
IF NOT ERRORLEVEL 1 (
	echo "*** error: do not execute this script within the exiv2 source directory ***"
	goto error_end
)

rem  ----
call:echo testing compiler
cl > NUL 2>NUL
IF ERRORLEVEL 1 (
	echo "*** ensure cl is on path.  Run vcvars32.bat or vcvarsall.bat ***"
	GOTO error_end
)
if NOT DEFINED _SILENT_ cl

rem  ----
call:echo testing svn is on path
svn --version > NUL
IF ERRORLEVEL 1 (
	echo "*** please ensure svn.exe is on the PATH ***"
	GOTO error_end
)

rem  ----
call:echo testing 7z is on path
7z > NUL
IF ERRORLEVEL 1 (
	echo "*** please ensure 7z.exe is on the PATH ***"
	GOTO error_end
)

rem  ----
call:echo testing cmake is on path
cmake --version > NUL
IF ERRORLEVEL 1 (
	echo "*** please ensure cmake.exe is on the PATH ***"
	GOTO error_end
)

rem  ----
call:echo testing temporary directory _TEMP_ = %_TEMP_%
if defined _REBUILD_ if EXIST "%_TEMP_%" rmdir/s/q "%_TEMP_%"
IF NOT EXIST "%_TEMP_%" mkdir "%_TEMP_%"
pushd        "%_TEMP_%"
set          "_TEMP_=%CD%"
popd
call:echo     _TEMP_ = %_TEMP_%

rem ----
call:echo testing INSTALL
if     defined _TYPE_ SET _INSTALL_=dist\%_VS_%\%Platform%\static\%_CONFIG_%
if NOT defined _TYPE_ SET _INSTALL_=dist\%_VS_%\%Platform%\dll\%_CONFIG_%
if NOT EXIST %_INSTALL_% mkdir %_INSTALL_%
IF NOT EXIST %_INSTALL_% mkdir %_INSTALL_%
pushd        %_INSTALL_%
set          "_INSTALL_=%CD%"
popd
call:echo     _INSTALL_ = %_INSTALL_%

set "_LIBPATH_=%_INSTALL_%\bin"
set "_INCPATH_=%_INSTALL_%\include"
set "_BINPATH_=%_INSTALL_%\bin"
set  _LIBPATH_=%_LIBPATH_:\=/%
set  _INCPATH_=%_INCPATH_:\=/%
set  _BINPATH_=%_BINPATH_:\=/%

if defined _TEST_ if NOT EXIST "%_BASH_%" (
	echo "*** bash does not exist %_BASH_% ***"
	GOTO error_end
)

if NOT DEFINED _GENERATOR_       set "_GENERATOR_=%VS_CMAKE%"
if /I "%_GENERATOR_%" == "NMake" set "_GENERATOR_=NMake Makefiles"

if defined _VIDEO_ set "_VIDEO_=-DEXIV2_ENABLE_VIDEO=ON"
if defined _TYPE_  set "_TYPE_=-DCMAKE_LINK=static"

call:cltest

echo.&&echo.&&echo.
echo.------ cmakeBuild Settings ----------
echo.bash      = %_BASH_%
echo.binpath   = %_BINPATH_%
echo.config    = %_CONFIG_%
echo.curl      = %_CURL_%
echo.exiv2     = %_EXIV2_%
echo.expat     = %_EXPAT_%
echo.generator = %_GENERATOR_%
echo.incpath   = %_INCPATH_%
echo.libpath   = %_LIBPATH_%
echo.libssh    = %_LIBSSH_%
echo.openssh   = %_OPENSSL_%
echo.temp      = %_TEMP_%
echo.test      = %_TEST_%
echo.type      = %_TYPE_%
echo.video     = %_VIDEO_%
echo.vc        = %_VC_%
echo.vs        = %_VS_%
echo.webready  = %_WEBREADY_%
echo.zlib      = %_ZLIB_%
echo.&&echo.&&echo.

if defined _WEBREADY_ (
	if /I "%_VS_%" == "2005" set "_UNSUPPORTED_=openssl not available for VS 2005"
	if /I "%_VS_%" == "2015" set "_UNSUPPORTED_=libssh and libcurl do not build for VS2015"
)

if defined _UNSUPPORTED_ ( 
    echo %_UNSUPPORTED_%
    call:error_end
)

IF DEFINED _DRYRUN_  goto end
IF DEFINED _REBUILD_ rmdir/s/q "%_TEMP_%"
IF DEFINED _PAUSE_   pause

echo ---------- ZLIB building with cmake ------------------
call:buildLib %_ZLIB_% -DCMAKE_INSTALL_PREFIX=%_INSTALL_%

echo ---------- EXPAT building with cmake -----------------
set "_TARGET_=--target expat"
call:buildLib %_EXPAT_% -DCMAKE_INSTALL_PREFIX=%_INSTALL_% 
set  _TARGET_=

if DEFINED _WEBREADY_ (
	echo ---------- OPENSSL installing pre-built binaries -----------------
	call:getOPENSSL %_OPENSSL_%
	if errorlevel 1 set _OPENSSL_=

	echo ---------- LIBSSH building with cmake -----------------
	call:buildLib   %_LIBSSH_% -DCMAKE_INSTALL_PREFIX=%_INSTALL_% -DCMAKE_LIBRARY_PATH=%_LIBPATH_% -DCMAKE_INCLUDE_PATH=%_INCPATH_% -DWITH_GSSAPI=OFF -DWITH_ZLIB=ON -DWITH_SFTP=ON -DWITH_SERVER=OFF -DWITH_EXAMPLES=OFF -DWITH_NACL=OFF -DWITH_PCAP=OFF
	if errorlevel 1 set _LIBSSH_=

	set        CURL_CMAKE=
	if DEFINED CURL_CMAKE (
	    echo ---------- CURL building with cmake -----------------
	    call:buildLib   %_CURL_% -DCMAKE_INSTALL_PREFIX=%_INSTALL_% -DCMAKE_LIBRARY_PATH=%_LIBPATH_% -DCMAKE_INCLUDE_PATH=%_INCPATH_% -DWITH_GSSAPI=OFF -DWITH_ZLIB=OFF -DWITH_SFTP=OFF -DWITH_SERVER=OFF -DWITH_EXAMPLES=OFF -DWITH_NACL=OFF -DWITH_PCAP=OFF -DCMAKE_USE_LIBSSH2=OFF -DCMAKE_USE_LIBSSH=OFF
	    if errorlevel 1 set _CURL_=
	) ELSE (
	    echo ---------- CURL building with nmake -----------------
	    pushd  "%_TEMP_%"
	    IF     EXIST  %_CURL_%        rmdir/s/q  %_CURL_% 
	    IF NOT EXIST %_CURL_%.tar.gz  svn export svn://dev.exiv2.org/svn/team/libraries/%_CURL_%.tar.gz >NUL
	    IF NOT EXIST %_CURL_%.tar     7z x %_CURL_%.tar.gz
        7z x %_CURL_%.tar
        cd "%_CURL_%\winbuild"
	    call:run nmake /f Makefile.vc mode=dll vc=%_VC_% machine=%RawPlatform% "WITH_DEVEL=%_INSTALL_%" WITH_ZLIB=dll WITH_SSL=dll
	    cd ..
	    copy/y builds\libcurl-vc%_VC_%-%RawPlatform%-release-dll-ssl-dll-zlib-dll-ipv6-sspi\lib\*     "%_LIBPATH_%"  
	    copy/y builds\libcurl-vc%_VC_%-%RawPlatform%-release-dll-ssl-dll-zlib-dll-ipv6-sspi\bin\*     "%_BINPATH_%"  
	    xcopy/yesihq builds\libcurl-vc%_VC_%-%RawPlatform%-release-dll-ssl-dll-zlib-dll-ipv6-sspi\include\curl "%_INCPATH_%"\curl
	    popd
	)
) else (
	set _CURL_=
	set _LIBSSH_=
)

echo ---------- EXIV2 building with cmake ------------------
set          "EXIV_B=%_TEMP_%\exiv2"
if defined _REBUILD_  IF EXIST "%EXIV_B%"  rmdir/s/q "%EXIV_B%"
IF NOT EXIST "%EXIV_B%"                    mkdir     "%EXIV_B%"

pushd        "%EXIV_B%"
	set ENABLE_CURL=-DEXIV2_ENABLE_CURL=OFF
	set ENABLE_LIBSSH=-DEXIV2_ENABLE_SSH=OFF
	set ENABLE_OPENSSL=-DEXIV2_ENABLE_WEBREADY=OFF
	set ENABLE_WEBREADY=-DEXIV2_ENABLE_VIDEO=OFF
	
	if defined _CURL_     set ENABLE_CURL=-DEXIV2_ENABLE_CURL=ON
	if defined _LIBSSH_   set ENABLE_LIBSSH=-DEXIV2_ENABLE_LIBSSH=ON
	if defined _WEBREADY_ set ENABLE_WEBREADY=-DEXIV2_ENABLE_WEBREADY=ON
	if defined _VIDEO_    set ENABLE_VIDEO=-DEXIV2_ENABLE_VIDEO=ON
	
	call:run cmake -G "%_GENERATOR_%" %_TYPE_% -DCMAKE_INSTALL_PREFIX=%_INSTALL_% -DCMAKE_LIBRARY_PATH=%_LIBPATH_% -DCMAKE_INCLUDE_PATH=%_INCPATH_% ^
	          -DEXIV2_ENABLE_NLS=OFF                -DEXIV2_ENABLE_BUILD_SAMPLES=ON ^
	          -DEXIV2_ENABLE_WIN_UNICODE=OFF        -DEXIV2_ENABLE_SHARED=ON ^
	          %ENABLE_WEBREADY%  %ENABLE_CURL%  %ENABLE_LIBSSH% %ENABLE_VIDEO% ^
	         "%_EXIV2_%"

	IF errorlevel 1 (
		echo "*** cmake errors in EXIV2 ***" >&2
	    popd
		goto error_end
	)

	call:run cmake --build . --config %_CONFIG_%
	IF errorlevel 1 (
		echo "*** build errors in EXIV2 ***" >&2
	    popd
		goto error_end
	)

	call:run cmake --build . --config %_CONFIG_% --target install
	IF errorlevel 1 (
		echo "*** install errors in EXIV2 ***" >&2
	    popd
		goto error_end
	)
	if     defined _SILENT_ copy/y "samples\%_CONFIG_%\"*.exe "%_INSTALL_%\bin" >nul
	if NOT defined _SILENT_ copy/y "samples\%_CONFIG_%\"*.exe "%_INSTALL_%\bin"
popd

if defined _TEST_ (
	pushd "%_EXIV2_%\test"
	"%_BASH_%" -c "export 'PATH=/usr/bin:$PATH' ; ./testMSVC.sh $(cygpath -au '%_BINPATH_%')"	
	popd
	exit /b 0
)

rem -----------------------------------------
rem Exit
:end
endlocal
exit /b 0

:error_end
endlocal
exit /b 1

rem -----------------------------------------
rem Functions
:help
echo Options: --help ^| --pause ^| --webready ^| --dryrun ^| --verbose ^| --rebuild ^| --silent ^| --verbose ^| --video ^| --test
echo.         --exiv2 directory ^| --temp directory ^| --config name ^| --generator generator
echo.         --zlib zlib.1.2.8 ^| --expat expat-2.1.0 ^| --curl curl-7.45.0 ^| --libssh libssh-0.7.2 ^| --openssl openssl-1.0.1p ^| --bash c:\cygwin64\bin\bash
exit /b 0

:echo
if NOT DEFINED _SILENT_ echo %*%
exit /b 0

:run
if defined _VERBOSE_ (
	echo.
	echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	echo CD = %CD%
	echo %*%
)	
if     defined _SILENT_ %*% >nul 2>nul
if NOT defined _SILENT_ %*%

set _RESULT_=%ERRORLEVEL%
if DEFINED _PAUSE_ pause
exit /b %_RESULT_%

rem -----------------------------------------
:buildLib
cd  "%_BUILDDIR_%"
set "LOB=%1"
shift

set "LOB_B=%_TEMP_%\%LOB%"
set "LOB_TAR=%LOB%.tar"
set "LOB_TAR_GZ=%LOB_TAR%.gz"

IF NOT EXIST "%LOB_TAR_GZ%"  svn export svn://dev.exiv2.org/svn/team/libraries/%LOB_TAR_GZ% >NUL
IF NOT EXIST "%LOB_TAR%"     7z x "%LOB_TAR_GZ%"
IF NOT EXIST "%LOB%"         7z x "%LOB_TAR%"
if NOT EXIST "%LOB_B%"       mkdir "%LOB_B%"

pushd "%LOB_B%"

    call:run cmake -G "%_GENERATOR_%" %_TYPE_% %* ..\..\%LOB%
	IF errorlevel 1 (
		echo "*** cmake errors in %LOB% ***"
	    popd
		exit /b 1
	)

	call:run cmake --build . --config %_CONFIG_% %_TARGET_%
	IF errorlevel 1 (
		echo "*** warning: build errors in %LOB% ***"
	)

	call:run cmake --build . --config %_CONFIG_% --target install
	IF errorlevel 1 (
		echo "*** warning: install errors in %LOB% ***"
	)
popd
exit /b 0

rem -----------------------------------------
:getOPENSSL
cd  "%_BUILDDIR_%"
set "LOB=%1-%VS_OPENSSL%"
set "LOB_7Z=%LOB%.7z"

IF NOT EXIST "%LOB_7Z%"      svn export svn://dev.exiv2.org/svn/team/libraries/%LOB_7Z% >NUL
IF NOT EXIST "%LOB%"         7z x      "%LOB_7Z%" >nul

set _BINARY_=bin
set _LIBRARY_=lib
set _INCLUDE_=include
if /I "%Platform%" == "x64" (
	set "_BINARY_=bin64"
	set "_LIBRARY_=lib64"
	set "_INCLUDE_=include64"
)

xcopy/yesihq "%LOB%\%_BINARY_%"  "%_INSTALL_%\bin"
xcopy/yesihq "%LOB%\%_LIBRARY_%" "%_INSTALL_%\lib"
xcopy/yesihq "%LOB%\%_INCLUDE_%" "%_INSTALL_%\include"
rem curl requires libeay32 and ssleay32 (and not libeay32MD and ssleay32MD)
pushd "%_INSTALL_%\lib"
copy/y libeay32MD.lib  libeay32.lib
copy/y ssleay32MD.lib  ssleay32.lib
popd
pushd "%_INSTALL_%\bin"
copy/y libeay32MD.dll  libeay32.dll
copy/y ssleay32MD.dll  ssleay32.dll
popd

exit /b 0

rem -----------------------------------------
:cltest
pushd    "%_EXIV2_%\contrib\cmake\msvc"
nmake -a cltest.exe
cltest.exe
popd
exit /b %ERRORLEVEL%
	
rem That's all Folks!
rem -----------------------------------------