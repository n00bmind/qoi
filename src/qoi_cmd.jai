PrintUsage :: ()
{
    USAGE_STR :: #string STR
Usage:
    qoi.exe <src_file> <target_file>
    qoi.exe -test <path>
STR
    print( "%\n", USAGE_STR );
}

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

    encodedOk, encoded := QOIEncode( encodedDesc, rawData );
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

    decodedOk, decoded, decodedDesc := QOIDecode( encoded );
    if( !decodedOk )
    {
        log( "Error: Failed decoding image data\n" );
        return false;
    }
    defer free( decoded.data );

    // Compare roundtripped image against raw data returned from stb_image
    decodedSize := decoded.count;
    log( "Decoded size: % / Target size: %\n", decodedSize, rawData.count );

    equal = true;
    if decodedSize == rawData.count
    {
        src := decoded.data;
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
    args := get_command_line_arguments();
    defer array_free(args);

    helpSwitches := string.["h", "help", "?"];
    argsOk, parsedArgs, isSet, freeArgs := parse_arguments( Args, Default_Argument_Flags | .SHOW_HELP_ON_ERROR, helpSwitches );

    if( !argsOk || args.count < 3 || freeArgs.count < 1 )
    {
        PrintUsage();
        exit( 1 );
    }

    if( parsedArgs.test )
    {
        log( "Working directory: %\n", get_working_directory() );

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

        log( "\n% files processed, % OK.\n", totalCount, successCount );
    }
    else
    {
        if( freeArgs.count < 2 )
        {
            PrintUsage();
            exit( 1 );
        }

        inPath := freeArgs[0];
        inExt, inExtFound := path_extension( inPath );
        inQOI := false;

        readBuffer: []u8;
        readDataBlock: *u8;
        w, h, channels: s32;
        if( inExtFound && equal( inExt, "qoi" ) )
        {
            readOk, readBuffer=, readDesc := QOIRead( inPath );
            if( !readOk )
                exit( 1 );

            w = xx readDesc.width;
            h = xx readDesc.height;
            channels = xx readDesc.channels;
            inQOI = true;
        }
        else
        {
            readDataBlock = stbi_load( temp_c_string( inPath ), *w, *h, *channels, 0 );
            if( !readDataBlock )
            {
                log( "Error: Couldn't load source file '%'.", inPath, flags=.ERROR );
                exit( 1 );
            }

            readBuffer.data = readDataBlock;
            readBuffer.count = w * h * channels;
        }

        defer ifx inQOI free( readBuffer.data ) else stbi_image_free( readDataBlock );  


        outPath := freeArgs[1];
        outExt, outExtFound := path_extension( outPath );

        writeOk := false;
        if( outExtFound && equal( outExt, "qoi" ) )
        {
            outDesc := QOIDesc.{ width = w, height = h, channels = xx channels };

            writeOk = QOIWrite( outPath, outDesc, readBuffer );
        }
        else
        {
            name := temp_c_string( outPath );

            if outExt ==
            {
                case "png"; 
                    writeOk = stbi_write_png( name, w, h, channels, readBuffer.data, w * channels ) != 0;
                case "tga";
                    writeOk = stbi_write_tga( name, w, h, channels, readBuffer.data ) != 0;
                case "bmp";
                    writeOk = stbi_write_bmp( name, w, h, channels, readBuffer.data ) != 0;
                case "jpg";
                    writeOk = stbi_write_jpg( name, w, h, channels, readBuffer.data, quality=80 ) != 0;
                case;
                    log( "Extension '%' is not supported.", outExt, flags=.ERROR );
            }
        }

        exit( xx ifx writeOk 0 else 1 );
    }
}

Args :: struct
{
    test: bool;     @"?Perform a round-trip test on either a single .qoi file or a directory (each .qoi file needs an accompanying .png)"
}

#scope_file

#import "Basic";
#import "String";
#import "Command_Line";
#import "Bit_Operations";
#import "File_Utilities";
#import "stb_image";
#import "stb_image_write";

#load "qoi.jai";
