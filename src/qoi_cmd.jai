
main :: ()
{
    helpSwitches := string.["h", "help", "?"];
    argsOk, args, isSet, freeArgs := parse_arguments( Args, Default_Argument_Flags | .SHOW_HELP_ON_ERROR, helpSwitches );

    if !argsOk
    {
        exit( 1 );
    }

    if freeArgs.count < 1
    {
        print( "Need a file / folder path to open\n" );
        exit( 1 );
    }

    print( "Working directory: %\n", get_working_directory() );

    for 0..0
        print( "Quick test #%\n", it );

    path := freeArgs[0];
    rawPath := tprint( "%.raw", path );
    rawStr, rawOk := read_entire_file( rawPath );

    loadedOk, info := QOILoad( path, xx rawStr );

    if loadedOk
    {
        if rawOk
        {
            // Compare
            decodedSize := info.pixels.count * 4;
            print( "Decoded size: % / Target size: %\n", decodedSize, rawStr.count );

            if decodedSize == rawStr.count
            {
                equal := true;
                tgt := cast(*u32)rawStr.data;
                for info.pixels
                {
                    if !bits_equal( *it, tgt + it_index, 4 )
                    {
                        print( "Pixel #% differs: want %, have %\n", it_index, tgt[it_index], it );
                        equal = false;
                        break;
                    }
                }

                if equal
                {
                    print( "Decoded image is identical to target!\n" );
                    testPath := tprint( "%.rawtest", path );
                    if write_entire_file( testPath, info.pixels.data, info.pixels.count * size_of(Pixel) )
                        print( "Raw output written to %\n", testPath );
                }
            }
        }
        else
            print( "Couldn't open '%' for reading\n", rawPath );
    }
    else
        exit( 1 );
}

Args :: struct
{

}

#scope_file

#import "Basic";
#import "Command_Line";
#import "Bit_Operations";

#load "qoi.jai";
