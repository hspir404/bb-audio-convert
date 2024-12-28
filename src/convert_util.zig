const std = @import("std");
const convert = @import("convert.zig");

const ArgsError = error{
    NotEnoughArgs,
    TooManyArgs,
    InputFilenameEmpty,
    OutputFilenameEmpty,
    OutputFilenameInvalid,
};

pub fn main() !void {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();

    // validate program command line parameters
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        try printUsageNormal();
        return;
    }

    var input_filename: []const u8 = "";
    var output_filename: []const u8 = "";
    for (args, 0..) |arg, arg_index| {
        switch (arg_index) {
            1 => input_filename = arg,
            2 => output_filename = arg,
            else => {},
        }
    }

    if (args.len < 3) {
        try printUsageError();
        return error.NotEnoughArgs;
    }

    if (args.len > 3) {
        try printUsageError();
        return error.TooManyArgs;
    }

    if (input_filename.len == 0) {
        std.log.err("input_filename must not be empty", .{});
        return error.InputFilenameEmpty;
    }

    if (output_filename.len == 0) {
        std.log.err("output_filename must not be empty", .{});
        return error.OutputFilenameEmpty;
    }

    const input_filename_extension = std.fs.path.extension(input_filename);
    const fsb5_filename_extension = ".fsb";
    if (!std.mem.eql(u8, input_filename_extension, fsb5_filename_extension)) {
        std.log.err("input_filename has wrong extension. Expected: {s} - Actual: {s}", .{ fsb5_filename_extension, input_filename_extension });
        return error.InputFilenameWrongExtension;
    }

    std.log.debug("Validated the command line parameters - count: {}", .{args.len});
    for (args) |arg| {
        std.log.debug("{s}", .{arg});
    }

    // open the input file
    const input_file_open_flags = .{};
    const input_file = blk: {
        if (std.fs.path.isAbsolute(input_filename))
            break :blk std.fs.openFileAbsolute(input_filename, input_file_open_flags)
        else
            break :blk std.fs.cwd().openFile(input_filename, input_file_open_flags);
    } catch |err| {
        std.log.err("Unable to open file input_filename: {s}", .{input_filename});
        return err;
    };
    defer input_file.close();

    var input_file_br = std.io.bufferedReader(input_file.reader());
    const input_file_reader = input_file_br.reader();

    std.log.debug("Opened input file: {s}", .{input_filename});

    // create the output file
    const output_file_create_flags = std.fs.File.CreateFlags{};
    const output_file = blk: {
        // create any intermediate subdirectories that don't yet exist
        if (std.fs.path.dirname(output_filename)) |output_dir_name| {
            const create_dir_result = if (std.fs.path.isAbsolute(output_dir_name))
                std.fs.makeDirAbsolute(output_dir_name)
            else
                std.fs.cwd().makePath(output_dir_name);
            create_dir_result catch |err| {
                switch (err) {
                    error.PathAlreadyExists => {}, // Ignore this
                    else => return err,
                }
            };

            std.log.debug("Created output directory: {s}", .{output_dir_name});
        }

        if (std.fs.path.isAbsolute(output_filename))
            break :blk std.fs.createFileAbsolute(output_filename, output_file_create_flags)
        else
            break :blk std.fs.cwd().createFile(output_filename, output_file_create_flags);
    } catch |err| {
        std.log.err("Unable to open file output_filename: {s}", .{output_filename});
        return err;
    };
    defer output_file.close();

    const output_file_writer = output_file.writer();
    var bw = std.io.bufferedWriter(output_file_writer);
    const writer = bw.writer();

    std.log.debug("Opened output file: {s}", .{output_filename});

    try convert.convert(input_file_reader.any(), writer.any(), allocator);

    try bw.flush();
}

fn getAlignmentPadding(value: usize, comptime alignment: usize) usize {
    const rem = alignment - @rem(value, alignment);
    const result = if (rem == alignment) 0 else rem;
    return result;
}

fn printUsageNormal() !void {
    try printUsageImpl(false);
}

fn printUsageError() !void {
    try printUsageImpl(true);
}

fn printUsageImpl(is_error: bool) !void {
    // TODO: Some fancy programmatic way to get the program name?
    const usage =
        \\Usage: bb-audio-convert-batch input_input_directory_name output_directory_name
        \\
    ;

    if (is_error) {
        std.log.err(usage, .{});
    } else {
        const stdout_file = std.io.getStdOut().writer();
        var bw = std.io.bufferedWriter(stdout_file);
        var writer = bw.writer();
        try writer.print(usage, .{});
        try bw.flush();
    }
}
