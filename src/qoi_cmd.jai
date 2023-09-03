
TestPath :: ( filepath: string, successCount: *int, totalCount: *int ) -> bool
{
    <<totalCount += 1;

    pngPath := tprint( "%.png", path_strip_extension( filepath ) );
    log( "-> Comparing file % against %..\n", filepath, pngPath );

    w, h, channels: s32;
    rawDataBlock := stbi_load( temp_c_string( pngPath ), *w, *h, *channels, 0 );
    if !rawDataBlock
    {
        log( "Error: Couldn't load png '%'.", pngPath, flags=.ERROR );
        return false;
    }
    defer stbi_image_free( rawDataBlock );

    log( "Image info as reported by stbi_image: W: %, H: %, channels: %\n", w, h, channels );

    rawData: []u8;
    rawData.data = rawDataBlock;
    rawData.count = w * h * channels;
    encodedDesc := QOIDesc.{ width = w, height = h, channels = xx channels };

    encodedOk, encoded := QOIEncode( rawData, encodedDesc );
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


    #if 0
    {
        rawPath := tprint( "%.raw", filepath );
        rawInput, rawInputOk := read_entire_file( rawPath, false, false );
        if( !rawInputOk )
        {
            log( "Error: Couldn't open '%' for reading\n", rawPath );
            return false;
        }
        defer free( rawInput.data );
    }

    decodedOk, decodedDesc := QOIDecode( encoded );
    if( !decodedOk )
    {
        log( "Error: Failed decoding image data\n" );
        return false;
    }
    defer free( decodedDesc.rawData.data );

    // Compare roundtripped image against raw data returned from stb_image
    decodedSize := decodedDesc.rawData.count;
    log( "Decoded size: % / Target size: %\n", decodedSize, rawData.count );

    equal = true;
    if decodedSize == rawData.count
    {
        src := decodedDesc.rawData.data;
        tgt := rawData.data;
        for 0 .. decodedDesc.width * decodedDesc.height - 1
        {
            if !bits_equal( src + it, tgt + it, decodedDesc.channels )
            {
                if( decodedDesc.channels == 3 )
                {
                    log( "Pixel #% differs: want { %, %, % }, have { %, %, % }\n",
                         it, tgt[it + 0], tgt[it + 1], tgt[it + 2], src[it + 0], src[it + 1], src[it + 2] );
                }
                else
                {
                    assert( decodedDesc.channels == 4, "Unsupported channel count: %\n", decodedDesc.channels );
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
        log( "Decoded OK.\n" );

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
