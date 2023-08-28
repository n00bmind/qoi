
Pixel :: struct
{
    r, g, b, a: u8;
}

QOIInfo :: struct
{
    rawData:       []u8;
    width, height: s32;
    channels:      s8;
    colorspace:    u8;
}


QOIDecode :: ( bytes: []u8, reference: []u8 = .[] ) -> bool, QOIInfo
{
    srcBytes := bytes.data;
    header : *QOIHeader;
    info : QOIInfo;

    header = xx srcBytes;
    if cast(string) header.magic != "qoif"
        return false, info;

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

    info.rawData = NewArray( info.width * info.height * info.channels, u8 );
    tgtBytes, refTgt := info.rawData.data;

    if reference
        refTgt = reference.data;

    seen : [64]Pixel;
    px := Pixel.{ a = 255 };

    PushPixel :: ( tgt: **u8, px: Pixel, channels: s32 )
    {
        (<<tgt)[0] = px.r;
        (<<tgt)[1] = px.g;
        (<<tgt)[2] = px.b;
        if( channels == 4 )
        {
            (<<tgt)[3] = px.a;
            <<tgt += 4;
        }
        else
        {
            assert( channels == 3, "Unsupported channel count: %\n", channels );
            <<tgt += 3;
        }
    }

    while( (srcBytes - bytes.data < bytes.count) && (tgtBytes - info.rawData.data < info.width * info.height * info.channels) )
    {
        advance := 0;
        offset := tgtBytes - info.rawData.data;

        if srcBytes[0] ==
        {
        case QOI_OP_RGB;
            px.r = srcBytes[1];
            px.g = srcBytes[2];
            px.b = srcBytes[3];
            advance += 4;

            if reference
                assert( bits_equal( *px, refTgt, info.channels ), "Ref: offset % data mismatch: found %, wanted { %, %, %, (%) }\n",
                        offset, px, refTgt[0], refTgt[1], refTgt[2], refTgt[3] );

        case QOI_OP_RGBA;
            px.r = srcBytes[1];
            px.g = srcBytes[2];
            px.b = srcBytes[3];
            px.a = srcBytes[4];
            advance += 5;

            if reference
                assert( bits_equal( *px, refTgt, info.channels ), "Ref: offset % data mismatch: found %, wanted { %, %, %, (%) }\n",
                        offset, px, refTgt[0], refTgt[1], refTgt[2], refTgt[3] );

        case;

            twoBitTag := srcBytes[0] >> 6;
            tagValue  := srcBytes[0] & 0x3F;

            if twoBitTag ==
            {
            case QOI_OP_INDEX;
                px = seen[tagValue];
                advance += 1;

                if reference
                    assert( bits_equal( *px, refTgt, info.channels ), "Ref: offset % data mismatch: found %, wanted { %, %, %, (%) }\n",
                            offset, px, refTgt[0], refTgt[1], refTgt[2], refTgt[3] );

            case QOI_OP_DIFF;
                dr := ((srcBytes[0] >> 4) & 0x3) - 2;
                dg := ((srcBytes[0] >> 2) & 0x3) - 2;
                db := ((srcBytes[0] >> 0) & 0x3) - 2;
                px.r += dr;
                px.g += dg;
                px.b += db;

                advance += 1;

                if reference
                    assert( bits_equal( *px, refTgt, info.channels ), "Ref: offset % data mismatch: found %, wanted { %, %, %, (%) }\n",
                            offset, px, refTgt[0], refTgt[1], refTgt[2], refTgt[3] );

            case QOI_OP_LUMA;
                dg    := tagValue - 32;
                dr_dg := ((srcBytes[1] >> 4) & 0xF) - 8;
                db_dg := ((srcBytes[1] >> 0) & 0xF) - 8;

                dr    := dr_dg + dg;
                db    := db_dg + dg;

                px.r += dr;
                px.g += dg;
                px.b += db;
                advance += 2;

                if reference
                    assert( bits_equal( *px, refTgt, info.channels ), "Ref: offset % data mismatch: found %, wanted { %, %, %, (%) }\n",
                            offset, px, refTgt[0], refTgt[1], refTgt[2], refTgt[3] );

            case QOI_OP_RUN;
                // Run length already has a -1 bias, but we also advance tgt by 1 at the very end..
                for 0..cast(s8)tagValue - 1
                {
                    PushPixel( *tgtBytes, px, info.channels );
                }

                if reference
                {
                    refTgt = reference.data + (tgtBytes - info.rawData.data);
                    assert( bits_equal( *px, refTgt, info.channels ), "Ref: offset % data mismatch: found %, wanted { %, %, %, (%) }\n",
                            offset, px, refTgt[0], refTgt[1], refTgt[2], refTgt[3] );
                }
                advance += 1;
            }
        }

        PushPixel( *tgtBytes, px, info.channels );

        seen[ (px.r * 3 + px.g * 5 + px.b * 7 + px.a * 11) & 0x3F ] = px;

        assert( advance != 0, "Stuck in place!" );
        srcBytes += advance;

        if reference
            refTgt = reference.data + (tgtBytes - info.rawData.data);
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
