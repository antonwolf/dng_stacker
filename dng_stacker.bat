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
echo This tool stacks several DNG images into one. It can be used as a digital ND filter.
echo.
echo This is a simple script that call the following tools:
echo ExifTool by Phil Harvey: https://exiftool.org/
echo Adobe DNG SDK:           https://www.adobe.com/support/downloads/dng/dng_sdk.html
echo ImageMagick:             https://imagemagick.org/
echo.
echo Process:
echo Step 0: Use ExifTool to analyze DNG files
echo Step 1: Extract raw sensor data as TIF from all DNG's using dng_validate from Adobe's DNG SDK
echo Step 2: Stack the TIFs into one using ImageMagick
echo Step 3: Use exiftool to convert the stacked TIF into a DNG
echo Step 4: Use dng_validate to make the new DNG valid.
echo.

SETLOCAL EnableDelayedExpansion

rem delete the temp files
if exist temp.dng del temp.dng
if exist temp.tif del temp.tif

rem Determine number of files, the first file and the TIF amplification and the total exposure time
set numberOfFiles=0
set amplification=0
set firstFile=
set totalExposureTime=0
echo Step 0: Analyzing the DNG files in the current folder...
echo Step 0 > dng_stacker.log

for %%i in (*.dng) do (
	rem Print the current file name to indicate progress to the user
	< /nul set /p=%%i 
	echo Step 0: %%i >> dng_stacker.log
	
	rem Count this file
	set /a numberOfFiles+=1
	
	rem Rember this file as the first file if it is he first
	if "!firstFile!"=="" set firstFile=%%~ni
	
	rem Accumulate total exposure time. Unfortunately, batch scripts only support integer numbers
	for /f "tokens=1 delims=." %%A in ('exiftool -n -T -ExposureTime %%i') do set /a totalExposureTime+=%%A
)
echo.

rem Display an error and exit if no file was found
if !numberOfFiles! EQU 0 (
	echo Error! No DNG files found. Please please DNG files in the current folder and try again.
	echo Step 0: Nothing found > dng_stacker.log
	pause
	exit
)

rem Extract WhiteLevel from first file.
for /f "tokens=1" %%A in ('exiftool -n -T -SubIFD:WhiteLevel !firstFile!.dng') do set oldWhiteLevel=%%A
rem Determine amplification. We can only use 16bits.
set /A amplification=65535/oldWhiteLevel
rem it makes no sense to amplify by more than the number of DNG images
if !numberOfFiles! LEQ !amplification! set amplification=!numberOfFiles!
rem Calculate new white level
set /a newWhiteLevel=!oldWhiteLevel!*!amplification!

rem Show summary to user
echo         Analysis resuls:
echo         Number of DNG files: !numberOfFiles!
echo         Current white level: !oldWhiteLevel!
echo         Amplification:       !amplification!
echo         New white level:     !newWhiteLevel!
echo         Total exposure time: !totalExposureTime!s (approx.)
echo.

echo Step 0: !numberOfFiles! files, amplyifing by !amplification! from !oldWhiteLevel! to !newWhiteLevel! >> dng_stacker.log

echo Step 1: Extracing raw data TIFs.
if exist *.tif (
	echo         Some TIF files have been found in the directory.
	echo         I assume I can use these and I don't need to extract stage 1.
	echo         If this does not work, pelase delete the TIF files.
	echo Step 1: Skipped since TIFs found. >> dng_stacker.log
) else (
	set currentFileNumber=0
	for %%i in (*.dng) do (
		set /a currentFileNumber+=1
		echo !currentFileNumber! of !numberOfFiles!: Extracting %%~ni.tif from %%~ni.dng
		echo Step 1: %%~ni.dng >> dng_stacker.log
		dng_validate.exe -1 %%~ni %%~ni.dng >> dng_stacker.log 2>>&1
		if errorlevel 1 (
			echo         Error! Please check the dng_stacker.log for details.
			pause
			exit
		)
	)
)
echo.

echo Step 2: Merging !numberOfFiles! TIF files into one.
echo.
set imCommand=
for %%i in (*.tif) do set imCommand=!imCommand! ( %%i -evaluate Multiply !amplification! ) 
convert !imCommand! -evaluate-sequence mean temp.tif >> dng_stacker.log 2>>&1
if errorlevel 1 (
	echo         Error! Please check the dng_stacker.log for details.
	pause
	exit
)

echo Step 3: Creating a temporary DNG based on the metadata from !firstFile!.dng
echo Step 3: Metadata from !firstFile!.dng >> dng_stacker.log
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
 "-IFD0:BlackLevel<SubIFD:BlackLevel"^
 "-IFD0:WhiteLevel<SubIFD:WhiteLevel"^
 "-IFD0:PhotometricInterpretation<SubIFD:PhotometricInterpretation"^
 "-IFD0:CalibrationIlluminant1<SubIFD:CalibrationIlluminant1"^
 "-IFD0:CalibrationIlluminant2<SubIFD:CalibrationIlluminant2"^
 -SamplesPerPixel^
 "-IFD0:CFARepeatPatternDim<SubIFD:CFARepeatPatternDim"^
 "-IFD0:CFAPattern2<SubIFD:CFAPattern2"^
 -AsShotNeutral^
 "-IFD0:ActiveArea<SubIFD:ActiveArea"^
 -"IFD0:DefaultScale<SubIFD:DefaultScale"^
 -"IFD0:DefaultCropOrigin<SubIFD:DefaultCropOrigin"^
 -"IFD0:DefaultCropSize<SubIFD:DefaultCropSize"^
 -"IFD0:OpcodeList3<SubIFD:OpcodeList3"^
 temp.dng >> dng_stacker.log 2>>&1
if errorlevel 1 (
	echo         Error! Please check the dng_stacker.log for details.
	exit
)
echo.

if !amplification! NEQ 1 (
	echo         Updating BlackLevel and WhiteLevel based on the amplification factor of !amplification!...
	for /f "tokens=*" %%F in ('exiftool -n -T -SubIFD:BlackLevel !firstFile!.dng') do set oldBlackLevels=%%F
	set newBlackLevels=
	for %%G in (!oldBlackLevels!) do (
		set /a newBlackLevel=%%G*!amplification!
		set newBlackLevels=!newBlackLevels! !newBlackLevel!
	)
	set newBlackLevels=!newBlackLevels:~1!
	exiftool -n -overwrite_original -IFD0:BlackLevel="!newBlackLevels!" -IFD0:WhiteLevel="!newWhiteLevel!" temp.dng >> dng_stacker.log 2>>&1
	if errorlevel 1 (
		echo         Error! Please check the dng_stacker.log for details.
		pause
		exit
	)
	echo.
)

if !totalExposureTime! GTR 1 (
	echo         Setting exposure time to !totalExposureTime!s...
	exiftool -n -overwrite_original -ExposureTime=!totalExposureTime! -ShutterSpeedValue=!totalExposureTime! -overwrite_original temp.dng >> dng_stacker.log 2>>&1
	echo.
)

set resultDNG=!firstFile!-stack!numberOfFiles!
echo Step 4: Writing clean DNG to !resultDNG!.dng
echo Step 4 >> dng_stacker.log
dng_validate.exe -dng !resultDNG! temp.dng >> dng_stacker.log 2>>&1
echo.

echo Cleaning up...
del temp.dng
del *.tif
echo.

echo Fully done. Please enjoy your new stacked DNG called !resultDNG!.dng
echo.
echo Please move or copy !resultDNG!.dng to another folder now.
echo Once you are done, please press any key. All DNG files will be deleted after that.
echo.
pause
del *.dng