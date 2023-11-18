QOI encoder &amp; decoder in Jai

## Usage (module)
Just clone this repo as is into your system's modules folder.\
Then import this module with `#import "qoi";`, remember to build your app passing `-import_dir <your_modules_dir>` to the jai compiler and you're good to go.

## Usage (command line tool)
You can build the included command line tool using\
```> jai build.jai```\
or simply run `build.bat` at the root of the project in Windows.\
This will create the command line application `qoi.exe` (or equivalent for your OS) in the `bin/` folder.

This tool can convert between the QOI format and any of the formats supported by stb_image_write (PNG/BMP/TGA/JPEG).\
Simply place the executable in any directory that's in your system's path and run\
```> qoi <src_file> <dst_file>```\
using the appropriate file extensions for each desired format.
