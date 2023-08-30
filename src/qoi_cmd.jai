
TestPath :: ( filepath: string, successCount: *int, totalCount: *int ) -> bool
{
    <<totalCount += 1;

    rawPath := tprint( "%.raw", filepath );
    log( "-> Comparing file % against %..\n", filepath, rawPath );

    input, inputOk := read_entire_file( filepath, false, true );
    if( !inputOk )
    {
        log( "Error: Couldn't open % for reading\n", filepath );
        return false;
    }
    defer free( input.data );

    rawInput, rawInputOk := read_entire_file( rawPath, false, false );
    if( !rawInputOk )
    {
        log( "Error: Couldn't open '%' for reading\n", rawPath );
        return false;
    }
    defer free( rawInput.data );

    decodedOk, desc := QOIDecode( xx input, xx rawInput );
    if( !decodedOk )
    {
        log( "Error: Failed decoding image data\n" );
        return false;
    }
    defer free( desc.rawData.data );

    // Compare
    decodedSize := desc.rawData.count;
    log( "Decoded size: % / Target size: %\n", decodedSize, rawInput.count );

    equal := true;
    if decodedSize == rawInput.count
    {
        src := desc.rawData.data;
        tgt := rawInput.data;
        for 0 .. desc.width * desc.height - 1
        {
            if !bits_equal( src + it, tgt + it, desc.channels )
            {
                if( desc.channels == 3 )
                {
                    log( "Pixel #% differs: want { %, %, % }, have { %, %, % }\n",
                         it, tgt[it + 0], tgt[it + 1], tgt[it + 2], src[it + 0], src[it + 1], src[it + 2] );
                }
                else
                {
                    assert( desc.channels == 4, "Unsupported channel count: %\n", desc.channels );
                    log( "Pixel #% differs: want { %, %, %, % }, have { %, %, %, % }\n",
                         it, tgt[it + 0], tgt[it + 1], tgt[it + 2], tgt[it + 3], src[it + 0], src[it + 1], src[it + 2], src[it + 3] );
                }
                equal = false;
                break;
            }
        }
    }
    else
        equal = false;


    if equal
    {
        log( "Decoded OK.\n" );

        //encodedOk, encoded := QOIEncode( desc.rawData, desc );
        encodedOk, encoded := QOIEncode( xx rawInput, desc );
        if( !encodedOk )
        {
            log( "Error: Failed encoding image data\n" );
            return false;
        }
        defer free( encoded.data );

        encodedPath := tprint( "%.test", filepath );
        write_entire_file( encodedPath, encoded.data, encoded.count );

        log( "Encoded size: % / Target size: %\n", encoded.count, input.count );
        if( encoded.count == input.count )
        {
            firstDiff := first_different_byte( encoded.data, input.data, xx encoded.count ); 
            if( firstDiff == xx encoded.count )
                log( "Encoded OK.\n" );
            else
            {
                log( "Encoded contents differ at byte %\n", firstDiff );
                equal = false;
            }
        }
        else
            equal = false;
    }

    <<successCount += xx equal;
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
            TestPath( info.full_name, *successCount, *totalCount );
        }

        visit_files( path, true, null, visitor );
    }
    else
        TestPath( path, *successCount, *totalCount );

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
