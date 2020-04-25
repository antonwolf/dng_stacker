@echo off

rem If you installed Adobe DNG Converter to a different path, please enter the path here
set dngConverter="C:\Program Files\Adobe\Adobe DNG Converter\Adobe DNG Converter.exe"

echo +---------------------------------------------------------------+
echo ^|      ____  _   ________   _____ __             __             ^|
echo ^|     / __ \/ ^| / / ____/  / ___// /_____ ______/ /_____  _____ ^|
echo ^|    / / / /  ^|/ / / __    \__ \/ __/ __ `/ ___/ //_/ _ \/ ___/ ^|
echo ^|   / /_/ / /^|  / /_/ /   ___/ / /_/ /_/ / /__/ ,^< /  __/ /     ^|
echo ^|  /_____/_/ ^|_/\____/   /____/\__/\__,_/\___/_/^|_^|\___/_/      ^|
echo ^|           Anton Wolf's DNG stacker script                     ^|
echo +---------------------------------------------------------------+
echo.
echo This tool merges several DNG images into one. It can be used as a digital ND filter.
echo.
echo This is a simple script that combines the following tools:
echo ExifTool by Phil Harvey: https://exiftool.org/
echo Adobe DNG SDK:           https://www.adobe.com/support/downloads/dng/dng_sdk.html
echo ImageMagick:             https://imagemagick.org/
echo.
echo Process:
echo Step 1: Extract raw sensor data as TIF from all DNGs using dng_validate from Adobe's DNG SDK
echo Step 2: Merge the TIFs into one using ImageMagick
echo Step 3: Use exiftool to convert the stacked TIF into a DNG
echo Step 4: Use dng_validate to make the new DNG valid and to compress it.
echo.

SETLOCAL EnableDelayedExpansion

rem delete the temp files
if exist temp.dng del temp.dng
if exist *.tif del *.tif

rem Determine number of files and the first file
set numberOfFiles=0
set firstFile=
for %%i in (*.dng *.crw *.cr2 *.cr3 *.raw *.raf *.3fr *.fff *.rwl *.new *.nrw *.pef *.arw) do (
	set /a numberOfFiles+=1
	if "!firstFile!"=="" set firstFile=%%~ni
)
echo !numberOfFiles! raw files found. > dng_stacker.log
if !numberOfFiles! EQU 0 (
	echo No raw files found. Please place raw files in the current folder and try again.
	pause
	GOTO:EOF
)

rem Adding up the total exposure time with exiftool because batch does not support floating point
exiftool -overwrite_original -ExposureTime=0 -ShutterSpeedValue=0 temp.xmp >> dng_stacker.log 2>>&1

set currentFileNumber=0
set imCommand=
for %%i in (*.dng *.crw *.cr2 *.cr3 *.raw *.raf *.3fr *.fff *.rwl *.new *.nrw *.pef *.arw) do (
	set /a currentFileNumber+=1
	if /i "%%~xi" NEQ ".dng" (
		echo [!currentFileNumber! of !numberOfFiles!] %%i: Converting raw to DNG.
		echo [!currentFileNumber! of !numberOfFiles!] %%i: Converting raw to DNG. >> dng_stacker.log
		if not exist !dngConverter! (
			echo Erorr: Adobe DNG Converter not found in path !dngConverter!. Please install it and/or change the path in line 2 of dng_stacker.bat
			goto err
		)
		!dngConverter! -u -p0 %%i >> dng_stacker.log 2>>&1
		if errorlevel 1 goto err
	)
	
	echo Copying %%~ni.dng to %%~ni-temp.dng >> dng_stacker.log
	exiftool -OpcodeList3= -OpcodeList2= %%~ni.dng  -o %%~ni-temp.dng >> dng_stacker.log 2>>&1
	if errorlevel 1 goto err

	echo [!currentFileNumber! of !numberOfFiles!] %%i: Extracting raw image data to %%~ni.tif.
	echo Extracting %%~ni-temp.dng to %%~ni.tif >> dng_stacker.log
	dng_validate.exe -1 %%~ni %%~ni-temp.dng >> dng_stacker.log 2>>&1
	if errorlevel 1 goto err
	
	del %%~ni-temp.dng
	
	for /f "tokens=1-3" %%a in ('exiftool -n -p "${BlackLevel;s/ .*//g} ${WhiteLevel;s/ .*//g} $ExposureTime" %%~ni.dng') do (
		set imCommand=!imCommand! ^( %%~ni.tif -level %%a,%%b ^)
		exiftool -overwrite_original -ExposureTime+=%%c -ShutterSpeedValue+=%%c temp.xmp >> dng_stacker.log 2>>&1
		if errorlevel 1 goto err
	)
)
echo.
echo Merging TIF files.
echo convert !imCommand! -evaluate-sequence mean temp.tif >> dng_stacker.log
convert !imCommand! -evaluate-sequence mean temp.tif >> dng_stacker.log 2>>&1
if errorlevel 1 goto err

echo Creating DNG based on the metadata from !firstFile!.dng
echo Creating DNG based on the metadata from !firstFile!.dng >> dng_stacker.log

ren temp.tif temp.dng

exiftool -n^
 -IFD0:SubfileType#=0^
 -overwrite_original -TagsFromFile !firstFile!.dng^
 "-all:all>all:all"^
 -DNGVersion^
 -DNGBackwardVersion^
 -ColorMatrix1^
 -ColorMatrix2^
 "-IFD0:BlackLevelRepeatDim<SubIFD:BlackLevelRepeatDim"^
 "-IFD0:PhotometricInterpretation<SubIFD:PhotometricInterpretation"^
 "-IFD0:CalibrationIlluminant1<SubIFD:CalibrationIlluminant1"^
 "-IFD0:CalibrationIlluminant2<SubIFD:CalibrationIlluminant2"^
 -SamplesPerPixel^
 "-IFD0:CFARepeatPatternDim<SubIFD:CFARepeatPatternDim"^
 "-IFD0:CFAPattern2<SubIFD:CFAPattern2"^
 -AsShotNeutral^
 "-IFD0:ActiveArea<SubIFD:ActiveArea"^
 "-IFD0:DefaultScale<SubIFD:DefaultScale"^
 "-IFD0:DefaultCropOrigin<SubIFD:DefaultCropOrigin"^
 "-IFD0:DefaultCropSize<SubIFD:DefaultCropSize"^
 "-IFD0:OpcodeList1<SubIFD:OpcodeList1"^
 "-IFD0:OpcodeList2<SubIFD:OpcodeList2"^
 "-IFD0:OpcodeList3<SubIFD:OpcodeList3"^
 !exposureTag!^
 temp.dng >> dng_stacker.log 2>>&1
if errorlevel 1 goto err

rem write back total exposure time
exiftool -n -overwrite_original -TagsFromFile temp.xmp "-ExposureTime<ExposureTime" "-ShutterSpeedValue<ShutterSpeedValue" temp.dng >> dng_stacker.log 2>>&1
if errorlevel 1 goto err

del temp.xmp

echo.

set resultDNG=!firstFile!-stack!numberOfFiles!
echo Writing clean DNG to !resultDNG!.dng
echo Writing clean DNG to !resultDNG!.dng >> dng_stacker.log
dng_validate.exe -dng !resultDNG! temp.dng >> dng_stacker.log 2>>&1

del temp.dng
del *.tif
echo.

echo Fully done. The new stacked DNG is called !resultDNG!.dng. Please move or copy it to another folder now.
echo.
echo Once you are done, please press any key. All DNG files will be deleted after that.
echo.
pause
del *.dng

GOTO:EOF

:err
echo Error! Please check the dng_stacker.log for details.
pause
