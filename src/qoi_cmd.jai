
TestDecodePath :: ( filepath: string, successCount: *int, totalCount: *int ) -> bool
{
    rawPath := tprint( "%.raw", filepath );
    print( "-> Comparing file % against raw dump..\n", filepath );

    rawStr, rawOk := read_entire_file( rawPath, false, false );
    loadedOk, info := QOIRead( filepath, xx rawStr );

    equal := false;
    if loadedOk
    {
        if rawOk
        {
            // Compare
            decodedSize := info.rawData.count;
            print( "Decoded size: % / Target size: %\n", decodedSize, rawStr.count );

            if decodedSize == rawStr.count
            {
                equal = true;
                src := info.rawData.data;
                tgt := rawStr.data;
                for 0 .. info.width * info.height - 1
                {
                    if !bits_equal( src + it, tgt + it, info.channels )
                    {
                        if( info.channels == 3 )
                        {
                            print( "Pixel #% differs: want { %, %, % }, have { %, %, % }\n",
                                   it, tgt[it + 0], tgt[it + 1], tgt[it + 2], src[it + 0], src[it + 1], src[it + 2] );
                        }
                        else
                        {
                            assert( info.channels == 4, "Unsupported channel count: %\n", info.channels );
                            print( "Pixel #% differs: want { %, %, %, % }, have { %, %, %, % }\n",
                                   it, tgt[it + 0], tgt[it + 1], tgt[it + 2], tgt[it + 3], src[it + 0], src[it + 1], src[it + 2], src[it + 3] );
                        }
                        equal = false;
                        break;
                    }
                }

                if equal
                {
                    print( "OK.\n" );
                }
            }
        }
        else
            print( "Couldn't open '%' for reading\n", rawPath );
    }

    free( info.rawData.data );
    free( rawStr.data );

    <<successCount += xx equal;
    <<totalCount += 1;
    return equal;
}


successCount, totalCount: int;

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

    path := freeArgs[0];
    if is_directory( path )
    {
        visitor :: (info : *File_Visit_Info, data : *void)
        {
            if info.is_directory || path_extension( info.full_name ) != "qoi"
                return;
            TestDecodePath( info.full_name, *successCount, *totalCount );
        }

        visit_files( path, true, null, visitor );
    }
    else
        TestDecodePath( path, *successCount, *totalCount );

    print( "\n% files processed, % OK.\n", totalCount, successCount );
}

Args :: struct
{

}

#scope_file

#import "Basic";
#import "String";
#import "Command_Line";
#import "Bit_Operations";
#import "File_Utilities";

#load "qoi.jai";
