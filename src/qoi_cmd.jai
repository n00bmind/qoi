
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

    path := freeArgs[0];
    loaded_ok, info := QOILoad( path );

    if loaded_ok
        print( "Contents of %:\n%\n", path, info );
}

Args :: struct
{

}

#scope_file

#import "Basic";
#import "Command_Line";

#load "qoi.jai";
