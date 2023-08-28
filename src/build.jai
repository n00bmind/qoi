#import "Basic";
#import "Compiler";
#import "System";
#import "String";

build :: ()
{
    set_build_options_dc( .{do_output=false} );  // No executable for this workspace.

    // The compiler will set the CWD to the directory containing the current file
    path := get_working_directory();
    print( "Working directory for 'build' metaprogram: '%'\n", path );

    // Right now it seems there's no way to just pass a path string directly
    loc: Source_Code_Location;
    loc.fully_pathed_filename = path;

    global_options := get_build_options();
    // NOTE Writes to '<prj_dir>\bin'
    global_options.output_path = "bin";
    global_options.intermediate_path = "bin";


    build_release := false;
    args := global_options.compile_time_command_line;

    for arg: args
    {
        if arg ==
        {
          case "release";
            build_release = true;
            print( "Building release version.\n" );
        }
    }


    // Main executable
    {
        w := compiler_create_workspace();
        options := global_options;
        options.output_type = .EXECUTABLE;
        options.output_executable_name = "qoi";
        if build_release
            set_optimization( *options, .VERY_OPTIMIZED, true );
        else
            set_optimization( *options, .VERY_DEBUG, true );
        set_build_options( options, w, loc );

        add_build_file( "qoi_cmd.jai", w );
    }

}
#run build();


