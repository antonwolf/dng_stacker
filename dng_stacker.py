import os
import subprocess
from glob import glob
from tqdm import tqdm


def select_method():
    # Select option
    valid_options = {
        '1': 'mean',
        '2': 'max',
        '3': 'min',
        '4': 'median'
    }

    for option in valid_options.keys():
        print(f"{option} = {valid_options[option]}")

    # Prompt user for input
    user_input = input("Select an option: ")

    # Validate user input
    while user_input not in valid_options.keys():
        print("Invalid option. Please try again.")
        user_input = input("Select an option: ")

    # Get the selected option
    method = valid_options[user_input]
    print("Selected option:", method)
    return method


root_dir = os.path.dirname(os.path.realpath(__file__))
file_types = ['*.dng', '*.crw', '*.cr2', '*.cr3', '*.raw', '*.raf', '*.3fr', '*.fff', '*.rwl', '*.new', '*.nrw',
              '*.pef', '*.arw', '*.nef']

dng_converter = r"C:\Program Files\Adobe\Adobe DNG Converter\Adobe DNG Converter.exe"
exif_tool = root_dir + r'\exiftool.exe'
dng_validate = root_dir + r'\dng_validate.exe'
convert = root_dir + r'\convert.exe'

temp_dng = 'temp.dng'
temp_tif = 'temp.tif'
temp_xmp = 'temp.xmp'
log_file_path = 'dng_stacker.log'

def main():
    method = select_method()

    # Delete temp files
    for file in glob(temp_dng):
        os.remove(file)

    for file in glob('*.tif'):
        os.remove(file)

    # Get files

    files = []
    for file_type in file_types:
        files.extend(glob(file_type))

    num_files = len(files)
    if num_files == 0:
        print("No raw files found. Please place raw files in the current folder and try again.")
        exit(1)

    with open(log_file_path, 'w') as log_file:
        log_file.write(f"{num_files} raw files found.\n")

        # Initialize EXIF data
        subprocess.run([exif_tool, '-overwrite_original', '-ExposureTime=0', '-ShutterSpeedValue=0', temp_xmp],
                       stdout=log_file, stderr=log_file)

        im_commands = []
        num_files = len(files)
        for i, file in enumerate(tqdm(files, total=num_files, desc='Converting raw to DNG.')):
            name, ext = os.path.splitext(file)
            if ext.lower() != '.dng':
                subprocess.run([dng_converter, '-u', '-p0', file])

            subprocess.run([exif_tool, '-OpcodeList3=', '-OpcodeList2=', f'{name}.dng', '-o', f'{name}-temp.dng'],
                           stdout=log_file, stderr=log_file)
            subprocess.run([dng_validate, '-1', name, f'{name}-temp.dng'], stdout=log_file, stderr=log_file)
            os.remove(f'{name}-temp.dng')

            exif_output = subprocess.run(
                [exif_tool, '-n', '-p', '${SubIFD:BlackLevel;s/ .*//g} ${SubIFD:WhiteLevel;s/ .*//g} $ExposureTime',
                 f'{name}.dng'], capture_output=True, text=True)
            black_level, white_level, exposure_time = exif_output.stdout.strip().split(' ')
            im_commands.append(f"( {name}.tif -level {black_level},{white_level} )")
            subprocess.run([exif_tool, '-overwrite_original', '-ExposureTime+=' + str(exposure_time),
                            '-ShutterSpeedValue+=' + str(exposure_time), temp_xmp], stdout=log_file, stderr=log_file)

        print("Merging TIF files.")
        convert_command = convert + " " + " ".join(im_commands) + f" -evaluate-sequence {method} temp.tif"
        os.system(convert_command)
        # subprocess.run(['convert'] + im_commands + ['-evaluate-sequence', 'mean', temp_tif])

        os.rename(temp_tif, temp_dng)

        print(f"Creating DNG based on the metadata from {files[0]}")
        subprocess.run([exif_tool, '-n',
                        '-IFD0:SubfileType#=0',
                        '-overwrite_original', '-TagsFromFile', files[0],
                        '-all:all>all:all',
                        '-DNGVersion',
                        '-DNGBackwardVersion',
                        '-ColorMatrix1',
                        '-ColorMatrix2',
                        '-IFD0:BlackLevelRepeatDim<SubIFD:BlackLevelRepeatDim',
                        '-IFD0:PhotometricInterpretation<SubIFD:PhotometricInterpretation',
                        '-IFD0:CalibrationIlluminant1<SubIFD:CalibrationIlluminant1',
                        '-IFD0:CalibrationIlluminant2<SubIFD:CalibrationIlluminant2',
                        '-SamplesPerPixel',
                        '-IFD0:CFARepeatPatternDim<SubIFD:CFARepeatPatternDim',
                        '-IFD0:CFAPattern2<SubIFD:CFAPattern2',
                        '-AsShotNeutral',
                        '-IFD0:ActiveArea<SubIFD:ActiveArea',
                        '-IFD0:DefaultScale<SubIFD:DefaultScale',
                        '-IFD0:DefaultCropOrigin<SubIFD:DefaultCropOrigin',
                        '-IFD0:DefaultCropSize<SubIFD:DefaultCropSize',
                        '-IFD0:OpcodeList1<SubIFD:OpcodeList1',
                        '-IFD0:OpcodeList2<SubIFD:OpcodeList2',
                        '-IFD0:OpcodeList3<SubIFD:OpcodeList3',
                        temp_dng], stdout=log_file, stderr=log_file)

        subprocess.run(
            [exif_tool, '-n', '-overwrite_original', '-TagsFromFile', temp_xmp, '-ExposureTime<ExposureTime',
             '-ShutterSpeedValue<ShutterSpeedValue', temp_dng], stdout=log_file, stderr=log_file)

        os.remove(temp_xmp)

        result_dng = f"{os.path.splitext(files[0])[0]}-stack{num_files}_{method}"
        print(f"Writing clean DNG to {result_dng}.dng")
        subprocess.run([dng_validate, '-dng', result_dng, temp_dng], stdout=log_file, stderr=log_file)

        os.remove(temp_dng)
        for file in glob('*.tif'):
            os.remove(file)

        print(
            f"Fully done. The new stacked DNG is called {result_dng}.dng. Please move or copy it to another folder now.")

        # input("Once you are done, please press any key. All DNG files will be deleted after that.")
        # for file in glob('*.dng'):
        #   os.remove(file)


if __name__ == '__main__':
    main()
