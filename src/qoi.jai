
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


QOIDecode :: ( bytes: []u8 ) -> bool, QOIInfo
{
    src := bytes.data;
    header : *QOIHeader;
    info : QOIInfo;

    header = xx src;
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

    src += size_of(QOIHeader);

    info.pixels = NewArray( info.width * info.height, Pixel );
    tgt := info.pixels.data;

    seen : [64]Pixel;
    last := Pixel.{ a = 255 };

    while( (src - bytes.data < bytes.count) && (tgt - info.pixels.data < info.width * info.height) )
    {
        seenNew := true;

        if src[0] ==
        {
        case QOI_OP_RGB;
            tgt.r = src[1];
            tgt.g = src[2];
            tgt.b = src[3];
            tgt.a = last.a;
            src += 4;

        case QOI_OP_RGBA;
            tgt.r = src[1];
            tgt.g = src[2];
            tgt.b = src[3];
            tgt.a = src[4];
            src += 5;

        case;

            twoBitTag := src[0] >> 6;
            tagValue  := src[0] & 0x3F;

            if twoBitTag ==
            {
            case QOI_OP_INDEX;
                // TODO Validate that last chunk was not a QOI_OP_INDEX to the same index
                tgt.* = seen[tagValue];
                seenNew = false;
                src += 1;

            // TODO Review signedness and wrapping
            case QOI_OP_DIFF;
                dr :u8 = ((src[0] >> 4) & 0x3) - 2;
                dg :u8 = ((src[0] >> 2) & 0x3) - 2;
                db :u8 = ((src[0] >> 0) & 0x3) - 2;

                tgt.r = last.r + dr;
                tgt.g = last.g + dg;
                tgt.b = last.b + db;
                tgt.a = last.a;
                src += 1;

            case QOI_OP_LUMA;
                dg :u8 = tagValue - 32;
                dr_dg :u8 = ((src[1] >> 4) & 0xF) - 8;
                db_dg :u8 = ((src[1] >> 0) & 0xF) - 8;

                dr := dr_dg + dg;
                db := db_dg + dg;

                tgt.r = last.r + dr;
                tgt.g = last.g + dg;
                tgt.b = last.b + db;
                tgt.a = last.a;
                src += 2;

            case QOI_OP_RUN;
                // TODO Check invalid run length 63 & 64
                // Run length has a -1 bias
                for 0..tagValue
                {
                    tgt.* = last;
                    tgt += 1;
                }
                seenNew = false;
                src += 1;
            }
        }

        last = tgt.*;
        if seenNew
        {
            idx := (last.r * 3 + last.g * 5 + last.b * 7 + last.a * 11) & 0x3F;
            seen[idx] = last;
        }
        tgt += 1;
    }

    // TODO Handle either missing src bytes or missing tgt pixel data
    // TODO Check post-amble

    return true, info;
}

QOILoad :: ( path: string ) -> bool, QOIInfo
{
    result: QOIInfo;

    content_str, ok := read_entire_file( path, false, false );
    if ok
        ok, result = QOIDecode( cast([]u8)content_str );
    else
        log( "Couldn't open '%' for reading.\n", path );

    return ok, result;
}



#scope_module

QOIHeader :: struct
{
    magic:         [4]u8;
    width, height: u32;
    channels:      u8;
    colorspace:    u8;
}

QOI_OP_RGB   :: 0xFE;
QOI_OP_RGBA  :: 0xFF;
QOI_OP_INDEX :: 0;
QOI_OP_DIFF  :: 1;
QOI_OP_LUMA  :: 2;
QOI_OP_RUN   :: 3;

#scope_file

#import "Basic";
#import "File";
