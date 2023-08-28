
Pixel :: struct
{
    r, g, b, a: u8;
}

QOIInfo :: struct
{
    pixels: []Pixel;
    width, height: s32;
    channels:      s8;
    colorspace:    u8;
    //...
}


QOIDecode :: ( bytes: []u8, reference: []u8 = .[] ) -> bool, QOIInfo
{
    srcBytes := bytes.data;
    header : *QOIHeader;
    info : QOIInfo;

    header = xx srcBytes;
    if cast(string) header.magic != "qoif"
        return false, info;
    log( "Found magic '%'\n", cast(string) header.magic );

    // Big endian WAT
    info.width = xx ((header.width & 0xFF) << 24)
        | ((header.width & 0xFF00) << 8)
        | ((header.width & 0xFF0000) >> 8)
        | ((header.width & 0xFF000000) >> 24);
    info.height = xx ((header.height & 0xFF) << 24)
        | ((header.height & 0xFF00) << 8)
        | ((header.height & 0xFF0000) >> 8)
        | ((header.height & 0xFF000000) >> 24);
    info.channels = xx header.channels;
    info.colorspace = xx header.colorspace;

    if reference
    {
        sizeBytes := info.width * info.height * info.channels;
        assert( reference.count == sizeBytes, "Ref: size mismatch, found %, wanted %\n", sizeBytes, reference.count );
    }

    srcBytes += size_of(QOIHeader);

    info.pixels = NewArray( info.width * info.height, Pixel );
    tgtPx, refTgt := info.pixels.data;

    if reference
        refTgt = cast(*Pixel)reference.data;

    seen : [64]Pixel;
    last := Pixel.{ a = 255 };

    while( (srcBytes - bytes.data < bytes.count) && (tgtPx - info.pixels.data < info.width * info.height) )
    {
        advance := 0;
        seenNew := true;
        pixelIdx := tgtPx - info.pixels.data;

        if srcBytes[0] ==
        {
        case QOI_OP_RGB;
            tgtPx.r = srcBytes[1];
            tgtPx.g = srcBytes[2];
            tgtPx.b = srcBytes[3];
            tgtPx.a = last.a;
            advance += 4;

            if reference
                assert( bits_equal( tgtPx, refTgt ), "Ref: pixel #% data mismatch, found %, wanted %\n", pixelIdx, <<tgtPx, <<refTgt );

        case QOI_OP_RGBA;
            tgtPx.r = srcBytes[1];
            tgtPx.g = srcBytes[2];
            tgtPx.b = srcBytes[3];
            tgtPx.a = srcBytes[4];
            advance += 5;

            if reference
                assert( bits_equal( tgtPx, refTgt ), "Ref: pixel #% data mismatch, found %, wanted %\n", pixelIdx, <<tgtPx, <<refTgt );

        case;

            twoBitTag := srcBytes[0] >> 6;
            tagValue  := srcBytes[0] & 0x3F;

            if twoBitTag ==
            {
            case QOI_OP_INDEX;
                // TODO Validate that last chunk was not a QOI_OP_INDEX to the same index
                tgtPx.* = seen[tagValue];
                seenNew = false;
                advance += 1;

                if reference
                    assert( bits_equal( tgtPx, refTgt ), "Ref: pixel #% data mismatch, found %, wanted %\n", pixelIdx, <<tgtPx, <<refTgt );

            // TODO Review signedness and wrapping
            case QOI_OP_DIFF;
                dr :int = ((srcBytes[0] >> 4) & 0x3) - 2;
                dg :int = ((srcBytes[0] >> 2) & 0x3) - 2;
                db :int = ((srcBytes[0] >> 0) & 0x3) - 2;

                tgtPx.r = cast,no_check(u8) (last.r + dr);
                tgtPx.g = cast,no_check(u8) (last.g + dg);
                tgtPx.b = cast,no_check(u8) (last.b + db);
                tgtPx.a = last.a;
                advance += 1;

                if reference
                    assert( bits_equal( tgtPx, refTgt ), "Ref: pixel #% data mismatch, found %, wanted %\n", pixelIdx, <<tgtPx, <<refTgt );

            case QOI_OP_LUMA;
                dg :int = tagValue - 32;
                dr_dg :int = ((srcBytes[1] >> 4) & 0xF) - 8;
                db_dg :int = ((srcBytes[1] >> 0) & 0xF) - 8;

                dr := dr_dg + dg;
                db := db_dg + dg;

                tgtPx.r = cast,no_check(u8) (last.r + dr);
                tgtPx.g = cast,no_check(u8) (last.g + dg);
                tgtPx.b = cast,no_check(u8) (last.b + db);
                tgtPx.a = last.a;
                advance += 2;

                if reference
                    assert( bits_equal( tgtPx, refTgt ), "Ref: pixel #% data mismatch, found %, wanted %\n", pixelIdx, <<tgtPx, <<refTgt );

            case QOI_OP_RUN;
                // Run length has a -1 bias, but we also advance tgtPx by 1 at the very end..
                for 0..cast(s8)tagValue - 1
                {
                    <<tgtPx = last;

                    if reference
                    {
                        refTgt = cast(*Pixel)reference.data + (tgtPx - info.pixels.data);
                        assert( bits_equal( tgtPx, refTgt ), "Ref: pixel #% data mismatch, found %, wanted %\n", pixelIdx, <<tgtPx, <<refTgt );
                    }
                    tgtPx += 1;
                }
                <<tgtPx = last;
                seenNew = false;
                advance += 1;

            }
        }

        last = <<tgtPx;
        if seenNew
        {
            idx := (last.r * 3 + last.g * 5 + last.b * 7 + last.a * 11) & 0x3F;
            seen[idx] = last;
        }

        assert( advance != 0, "Stuck in place!" );
        srcBytes += advance;

        tgtPx += 1;
        if reference
            refTgt = cast(*Pixel)reference.data + (tgtPx - info.pixels.data);
    }

    // TODO Handle either missing src bytes or missing tgt pixel data
    // TODO Check post-amble

    return true, info;
}

QOILoad :: ( path: string, reference: []u8 = .[] ) -> bool, QOIInfo
{
    result: QOIInfo;

    contentStr, ok := read_entire_file( path, false, true );
    if ok
        ok, result = QOIDecode( cast([]u8)contentStr, reference );
    else
    {
        log( "Couldn't open '%' for reading.\n", path );
        ok = false;
    }

    return ok, result;
}



#scope_module


QOIHeader :: struct
{
    magic:         [4]u8;
    width, height: u32;
    channels:      u8;
    colorspace:    u8;
} #no_padding

QOI_OP_RGB   :: 0xFE;
QOI_OP_RGBA  :: 0xFF;
QOI_OP_INDEX :: 0;
QOI_OP_DIFF  :: 1;
QOI_OP_LUMA  :: 2;
QOI_OP_RUN   :: 3;

#scope_file

#import "Basic";
#import "File";
