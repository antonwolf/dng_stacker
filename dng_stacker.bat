@echo off
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
if exist temp.tif del temp.tif

rem Determine number of files and the first file
set numberOfFiles=0
set firstFile=
for %%i in (*.dng) do (
	set /a numberOfFiles+=1
	if "!firstFile!"=="" set firstFile=%%~ni
)
echo !numberOfFiles! files found. > dng_stacker.log
if !numberOfFiles! EQU 0 (
	echo No DNG files found. Please place DNG files in the current folder and try again.
	pause
	GOTO:EOF
)

set totalExposureTime=0
set currentFileNumber=0
set imCommand=
for %%i in (*.dng) do (
	set /a currentFileNumber+=1
	if exist %%~ni.tif (
		echo [!currentFileNumber! of !numberOfFiles!] %%i: %%~ni.tif found, skipping TIF extraction.
	) else (
		echo [!currentFileNumber! of !numberOfFiles!] %%i: Extracting raw image data to %%~ni.tif.
		echo Extracting %%i to %%~ni.tif > dng_stacker.log
		dng_validate.exe -1 %%~ni %%~ni.dng >> dng_stacker.log 2>>&1
	)
	
	set WhiteLevel=16383
	set BlackLevel=0
	set ExposureTime=0
	for /f "tokens=1,2 delims=	" %%A in ('exiftool -n -t -WhiteLevel -BlackLevel -ExposureTime %%i') do (
		if "%%A" == "White Level"   for /f "tokens=1"          %%F in ("%%B") do set WhiteLevel=%%F
		if "%%A" == "Black Level"   for /f "tokens=1"          %%F in ("%%B") do set BlackLevel=%%F
		if "%%A" == "Exposure Time" for /f "tokens=1 delims=." %%F in ("%%B") do set ExposureTime=%%F
	)
	set /a totalExposureTime+=!ExposureTime!
	set imCommand=!imCommand! ^( %%~ni.tif -level !BlackLevel!,!WhiteLevel! ^)
)
echo.
echo Merging TIF files.
echo convert !imCommand! -evaluate-sequence mean temp.tif >> dng_stacker.log
convert !imCommand! -evaluate-sequence mean temp.tif >> dng_stacker.log 2>>&1
if errorlevel 1 (
	echo         Error! Please check dng_stacker.log for details.
	pause
	GOTO:EOF
)

echo Creating DNG based on the metadata from !firstFile!.dng
echo Creating DNG based on the metadata from !firstFile!.dng >> dng_stacker.log

ren temp.tif temp.dng

if !totalExposureTime! GTR 1 (
	set exposureTag="-ExposureTime=!totalExposureTime!"
) else (
	set exposureTag="-ExposureTime<ExposureTime"
)
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
if errorlevel 1 (
	echo         Error! Please check the dng_stacker.log for details.
	GOTO:EOF
)
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
