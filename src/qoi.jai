
Pixel :: struct
{
    r, g, b, a: u8;
}

QOIDesc :: struct
{
    // TODO Take this out of here
    rawData:       []u8;
    width, height: s32;
    channels:      s8;
    colorspace:    u8;
}


QOIDecode :: ( input: []u8, reference: []u8 = .[] ) -> ok: bool, desc: QOIDesc
{
    src := input.data;
    desc : QOIDesc;
    header : *QOIHeader;

    header = xx src;
    // TODO Validation & logging
    if cast(string) header.magic != "qoif"
        return false, desc;

    // Big endian WAT
    desc.width = xx ((header.width & 0xFF) << 24)
        | ((header.width & 0xFF00) << 8)
        | ((header.width & 0xFF0000) >> 8)
        | ((header.width & 0xFF000000) >> 24);
    desc.height = xx ((header.height & 0xFF) << 24)
        | ((header.height & 0xFF00) << 8)
        | ((header.height & 0xFF0000) >> 8)
        | ((header.height & 0xFF000000) >> 24);
    desc.channels = xx header.channels;
    desc.colorspace = xx header.colorspace;

    if reference
    {
        sizeBytes := desc.width * desc.height * desc.channels;
        assert( reference.count == sizeBytes, "Ref: size mismatch, found %, wanted %\n", sizeBytes, reference.count );
    }

    src += size_of(QOIHeader);

    desc.rawData = NewArray( desc.width * desc.height * desc.channels, u8 );
    if !desc.rawData
        return false, desc;

    tgt, refTgt := desc.rawData.data;

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

    tgtEnd := desc.rawData.data + desc.width * desc.height * desc.channels;
    while( tgt < tgtEnd )
    {
        advance := 0;
        offset := tgt - desc.rawData.data;

        if src[0] ==
        {
        case QOI_OP_RGB;
            px.r = src[1];
            px.g = src[2];
            px.b = src[3];
            advance += 4;

            if reference
                assert( bits_equal( *px, refTgt, desc.channels ), "Ref: offset % data mismatch: found %, wanted { %, %, %, (%) }\n",
                        offset, px, refTgt[0], refTgt[1], refTgt[2], refTgt[3] );

        case QOI_OP_RGBA;
            px.r = src[1];
            px.g = src[2];
            px.b = src[3];
            px.a = src[4];
            advance += 5;

            if reference
                assert( bits_equal( *px, refTgt, desc.channels ), "Ref: offset % data mismatch: found %, wanted { %, %, %, (%) }\n",
                        offset, px, refTgt[0], refTgt[1], refTgt[2], refTgt[3] );

        case;

            if src[0] & QOI_MASK_2 ==
            {
            case QOI_OP_INDEX;
                index: u8 = src[0] & ~QOI_MASK_2;
                px = seen[index];
                advance += 1;

                if reference
                    assert( bits_equal( *px, refTgt, desc.channels ), "Ref: offset % data mismatch: found %, wanted { %, %, %, (%) }\n",
                            offset, px, refTgt[0], refTgt[1], refTgt[2], refTgt[3] );

            case QOI_OP_DIFF;
                dr := ((src[0] >> 4) & 0x3) - 2;
                dg := ((src[0] >> 2) & 0x3) - 2;
                db := ((src[0] >> 0) & 0x3) - 2;
                px.r += dr;
                px.g += dg;
                px.b += db;

                advance += 1;

                if reference
                    assert( bits_equal( *px, refTgt, desc.channels ), "Ref: offset % data mismatch: found %, wanted { %, %, %, (%) }\n",
                            offset, px, refTgt[0], refTgt[1], refTgt[2], refTgt[3] );

            case QOI_OP_LUMA;
                luma: u8 = src[0] & ~QOI_MASK_2;
                dg    := luma - 32;
                dr_dg := ((src[1] >> 4) & 0xF) - 8;
                db_dg := ((src[1] >> 0) & 0xF) - 8;

                dr    := dr_dg + dg;
                db    := db_dg + dg;

                px.r += dr;
                px.g += dg;
                px.b += db;
                advance += 2;

                if reference
                    assert( bits_equal( *px, refTgt, desc.channels ), "Ref: offset % data mismatch: found %, wanted { %, %, %, (%) }\n",
                            offset, px, refTgt[0], refTgt[1], refTgt[2], refTgt[3] );

            case QOI_OP_RUN;
                runLen: u8 = src[0] & ~QOI_MASK_2;
                // Run length already has a -1 bias, but we also advance tgt by 1 on every loop iteration below..
                for 0..cast(s8)runLen - 1
                {
                    PushPixel( *tgt, px, desc.channels );
                }

                if reference
                {
                    refTgt = reference.data + (tgt - desc.rawData.data);
                    assert( bits_equal( *px, refTgt, desc.channels ), "Ref: offset % data mismatch: found %, wanted { %, %, %, (%) }\n",
                            offset, px, refTgt[0], refTgt[1], refTgt[2], refTgt[3] );
                }
                advance += 1;
            }
        }

        PushPixel( *tgt, px, desc.channels );

        seen[ (px.r * 3 + px.g * 5 + px.b * 7 + px.a * 11) & 0x3F ] = px;

        assert( advance != 0, "Stuck in place!" );
        src += advance;

        if reference
            refTgt = reference.data + (tgt - desc.rawData.data);
    }

    // TODO Handle either missing src bytes or missing tgt pixel data
    // TODO Check post-amble

    return true, desc;
}

QOIRead :: ( path: string, reference: []u8 = .[] ) -> bool, QOIDesc
{
    result: QOIDesc;

    contentStr, ok := read_entire_file( path, false, true );
    if ok
        ok, result = QOIDecode( cast([]u8)contentStr, reference );
    else
    {
        log( "Couldn't open '%' for reading.\n", path );
        ok = false;
    }

    free( contentStr.data );

    return ok, result;
}


QOIEncode :: ( input: []u8, desc: QOIDesc ) -> ok: bool, encodedOut: []u8
{
    if !input
    {
        log( "Error: Invalid input array\n" );
        return false, .[];
    }

    if( desc.width == 0 || desc.height == 0 ||
        desc.channels < 3 || desc.channels > 4 )
    {
        log( "Error: Invalid input image description\n" );
        return false, .[];
    }

    inputSize := desc.width * desc.height * desc.channels;
    if input.count != inputSize
    {
        log( "Error: Invalid input array dimensions (given %, want %)\n", input.count, inputSize );
        return false, .[];
    }

    // Worst case
    // TODO Use a bucket array?
    maxSize := desc.width * desc.height * (desc.channels + 1)
        + size_of(QOIHeader) + size_of(type_of(qoiEpilogue));

    encodedOut := NewArray( maxSize, u8 );
    if !encodedOut
    {
        log( "Error: out of memory\n" );
        return false, .[];
    }

    tgt := encodedOut.data;

    QOI_MAGIC :u32 : (#char "q" << 24) | (#char "o" << 16) | (#char "i" <<  8) | (#char "f");
    QOIWrite32( *tgt, QOI_MAGIC );
    QOIWrite32( *tgt, xx desc.width );
    QOIWrite32( *tgt, xx desc.height );
    tgt[0] = xx desc.channels;
    tgt[1] = xx desc.colorspace;
    tgt += 2;

    src := input.data;

    px_prev := Pixel.{ a = 255 };
    px: Pixel = px_prev;
    run: u8 = 0;
    seen: [64]Pixel;

    srcEnd := input.data + inputSize;
    lastPx := input.data + inputSize - desc.channels;
    while( src < srcEnd )
    {
        px.r = src[0];
        px.g = src[1];
        px.b = src[2];

        if( desc.channels == 4 )
            px.a = src[3];

        if( bits_equal( *px, *px_prev ) )
        {
            run += 1;
            if( run == 62 || src == lastPx )
            {
                <<tgt = QOI_OP_RUN | (run - 1);
                tgt += 1;
                run = 0;
            }
        }
        else
        {
            if( run > 0 )
            {
                <<tgt = QOI_OP_RUN | (run - 1);
                tgt += 1;
                run = 0;
            }

            index := (px.r * 3 + px.g * 5 + px.b * 7 + px.a * 11) & 0x3F;

            if( bits_equal( *seen[index], *px ) )
            {
                <<tgt = QOI_OP_INDEX | index;
                tgt += 1;
            }
            else
            {
                seen[index] = px;

                if( px.a == px_prev.a )
                {
                    // TODO Unsigned?
                    dr: s8 = cast,no_check(s8) (px.r - px_prev.r);
                    dg: s8 = cast,no_check(s8) (px.g - px_prev.g);
                    db: s8 = cast,no_check(s8) (px.b - px_prev.b);

                    dr_dg: s8 = dr - dg;
                    db_dg: s8 = db - dg;

                    if( dr > -3 && dr < 2 &&
                        dg > -3 && dg < 2 &&
                        db > -3 && db < 2 )
                    {
                        // TODO Precedence?
                        tgt[0] = QOI_OP_DIFF | (cast,no_check(u8)(dr + 2) << 4)
                            | (cast,no_check(u8)(dg + 2) << 2) | cast,no_check(u8)(db + 2);
                        tgt += 1;
                    }
                    else if( dr_dg >  -9 && dr_dg <  8 &&
                             dg    > -33 && dg    < 32 &&
                             db_dg >  -9 && db_dg <  8 )
                    {
                        // TODO Precedence?
                        tgt[0] = QOI_OP_LUMA                         | cast,no_check(u8)(dg    + 32);
                        tgt[1] = (cast,no_check(u8)(dr_dg + 8) << 4) | cast,no_check(u8)(db_dg +  8);
                        tgt += 2;
                    }
                    else
                    {
                        tgt[0] = QOI_OP_RGB;
                        tgt[1] = px.r;
                        tgt[2] = px.g;
                        tgt[3] = px.b;
                        tgt += 4;
                    }
                }
                else
                {
                    tgt[0] = QOI_OP_RGBA;
                    tgt[1] = px.r;
                    tgt[2] = px.g;
                    tgt[3] = px.b;
                    tgt[4] = px.a;
                    tgt += 5;
                }
            }
        }

        px_prev = px;
        src += desc.channels;
    }

    for qoiEpilogue
    {
        <<tgt = it;
        tgt += 1;
    }

    // TODO This is kind of wasteful
    encodedOut.count = tgt - encodedOut.data;
    return true, encodedOut;
}


// TODO QOIWrite
// TODO QOIWrite


#scope_file


#import "Basic";
#import "File";

QOIHeader :: struct
{
    magic:         [4]u8;
    width, height: u32;
    channels:      u8;
    colorspace:    u8;
} #no_padding

QOI_OP_INDEX  :u8 : 0x00; /* 00xxxxxx */
QOI_OP_DIFF   :u8 : 0x40; /* 01xxxxxx */
QOI_OP_LUMA   :u8 : 0x80; /* 10xxxxxx */
QOI_OP_RUN    :u8 : 0xc0; /* 11xxxxxx */
QOI_OP_RGB    :u8 : 0xfe; /* 11111110 */
QOI_OP_RGBA   :u8 : 0xff; /* 11111111 */

QOI_MASK_2    :u8 : 0xc0; /* 11000000 */

qoiEpilogue: [8]u8 = .[ 0,0,0,0,0,0,0,1 ];


QOIWrite32 :: ( tgt: **u8, v: u32 )
{
    (<<tgt)[0] = xx ((0xff000000 & v) >> 24);
    (<<tgt)[1] = xx ((0x00ff0000 & v) >> 16);
    (<<tgt)[2] = xx ((0x0000ff00 & v) >> 8);
    (<<tgt)[3] = xx ((0x000000ff & v));
    (<<tgt) += 4;
}

