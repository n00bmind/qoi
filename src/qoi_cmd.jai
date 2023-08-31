
TestPath :: ( filepath: string, successCount: *int, totalCount: *int ) -> bool
{
    <<totalCount += 1;

    pngPath := tprint( "%.png", filepath );
    rawPath := tprint( "%.raw", filepath );
    log( "-> Comparing file % against % and %..\n", filepath, pngPath, rawPath );

    w, h, channels: s32;
    rawDataBlock := stbi_load( temp_c_string( pngPath ), *w, *h, *channels, 0 );
    if !rawDataBlock
    {
        log( "Error: Couldn't load png '%'.", pngPath, flags=.ERROR );
        return false;
    }
    defer stbi_image_free( rawDataBlock );

    // TODO Is there syntax for this?
    //rawData: []u8 = { rawDataBlock, w * h * channels };
    rawData: []u8;
    rawData.data = rawDataBlock;
    rawData.count = w * h * channels;
    pngDesc := QOIDesc.{ width = w, height = h, channels = xx channels };

    encodedOk, encoded := QOIEncode( rawData, pngDesc );
    if( !encodedOk )
    {
        log( "Error: Failed encoding image data\n" );
        return false;
    }
    defer free( encoded.data );

    qoiInput, qoiInputOk := read_entire_file( filepath, false, true );
    if( !qoiInputOk )
    {
        log( "Error: Couldn't open % for reading\n", filepath );
        return false;
    }
    defer free( qoiInput.data );

    equal := false;
    log( "Encoded size: % / Target size: %\n", encoded.count, qoiInput.count );
    if( encoded.count == qoiInput.count )
    {
        firstDiff := first_different_byte( encoded.data, qoiInput.data, xx encoded.count ); 
        if( firstDiff == xx encoded.count )
        {
            log( "Encoded OK.\n" );
            equal = true;
        }
        else
        {
            log( "Encoded contents differ at byte %\n", firstDiff );
        }
    }


    if( !equal )
        return false;


    rawInput, rawInputOk := read_entire_file( rawPath, false, false );
    if( !rawInputOk )
    {
        log( "Error: Couldn't open '%' for reading\n", rawPath );
        return false;
    }
    defer free( rawInput.data );

    decodedOk, qoiDesc := QOIDecode( xx qoiInput, xx rawInput );
    if( !decodedOk )
    {
        log( "Error: Failed decoding image data\n" );
        return false;
    }
    defer free( qoiDesc.rawData.data );

    // Compare
    decodedSize := qoiDesc.rawData.count;
    log( "Decoded size: % / Target size: %\n", decodedSize, rawInput.count );

    equal = true;
    if decodedSize == rawInput.count
    {
        src := qoiDesc.rawData.data;
        tgt := rawInput.data;
        for 0 .. qoiDesc.width * qoiDesc.height - 1
        {
            if !bits_equal( src + it, tgt + it, qoiDesc.channels )
            {
                if( qoiDesc.channels == 3 )
                {
                    log( "Pixel #% differs: want { %, %, % }, have { %, %, % }\n",
                         it, tgt[it + 0], tgt[it + 1], tgt[it + 2], src[it + 0], src[it + 1], src[it + 2] );
                }
                else
                {
                    assert( qoiDesc.channels == 4, "Unsupported channel count: %\n", qoiDesc.channels );
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


    #if false
    {
        if equal
        {
            log( "Decoded OK.\n" );

            //encodedOk, encoded := QOIEncode( qoiDesc.rawData, qoiDesc );
            encodedOk, encoded := QOIEncode( xx rawInput, qoiDesc );
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
#import "stb_image";

#load "qoi.jai";
