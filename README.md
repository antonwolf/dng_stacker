# dng_stacker
DNG Stacker can be used as a digital ND filter for raw photographs, as an HDR tool or to create multi-exposure images.
It creates an average of several DNG files and tries up to 16 bits if this makes sense given the source images.
It works on the raw photo data, before any de-mosaicing or conversion to colors.

## Purposes

* __Digital ND Filter__: By stacking many photos taken in a row, you achieve pretty much the same picture as if you had a very good and expensive ND filter. This way, you can achieve the same smooth water and smooth clouds effect.
* __Digital closed aperture__: By stacking many photos taken in a row, you can achieve a similar picture as if you had closed the aperture. Most smartphones cannot close the aperture. Full-frame camera lenses get less sharp from f/11 onwards, so you might not want to close aperture further.
* __Noise improvement__: The more pictures you stack, the less digital noise will be in the output. This can be useful if you need a high-quality picture, e.g. to apply post processing (e.g. in RawTherapee, Lightroom, CaptureOne or Darktable).
* __High-dynamic range images (HDR)__: If less noise is present, you can apply more HDR post-processing in a raw converter. There are a few tools out there that allow you to create an HDR dng from an exposure bracket, but they all struggle with moving subjects. DNG stacker has no problem with moving subjects. The same picture as an exposure bracket of -2 EV, ±0 EV, +2 EV can be made by stacking 16 -2 EV photos.
* __Multi-exposures__: You can also stack completely different pictures to create artistic effects. You have to use the same camera model, though. It is best to use similar ISO settings and as well.

## Setup and install
To get the DNG Stacker running, just download all files from this repository and put them into a folder on your computer.
The files are:
 * __dng_stacker.bat__: The actual DNG stacker script I made
 * __exiftool.exe__: ExifTool by Phil Harvey from https://exiftool.org/
 * __dng_validate.exe__: dng_validate from Adobe's DNG SDK from https://www.adobe.com/support/downloads/dng/dng_sdk.html
 * __convert.exe__: The portable version of ImageMagick from https://imagemagick.org/

## Source files
The DNG stacker cannot use raw files (&ast;.RAF, &ast;.CR2, &ast;.NEF, ...) directly.
You first have to convert these files to DNG using [Adobe's DNG Converter](https://helpx.adobe.com/de/photoshop/using/adobe-dng-converter.html) or Lightroom or another tool.
The source files have to be placed in the same folder as dng_stacker.bat and the exe files.

## Running dng_stacker
To run it, just double-click dng_stacker.bat in Explorer

## How it works
0. Use ExifTool to analyze DNG files
1. Extract raw sensor data as TIF from all DNG's using dng_validate from Adobe's DNG SDK
2. Stack the TIFs into one using ImageMagick
3. Use exiftool to convert the stacked TIF into a DNG
4. Use dng_validate to make the new DNG valid.
