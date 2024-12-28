const std = @import("std");
const fsb5 = @import("fsb5");
const libatrac9 = @import("libatrac9");
const libmp3lame = @import("libmp3lame");
const convert = @import("convert.zig");
const shared_input_file_data = @import("input_file_data.zig");
const Sha256 = std.crypto.hash.sha2.Sha256;

const ArgsError = error{
    NotEnoughArgs,
    TooManyArgs,
    InputDirectoryNameEmpty,
    OutputDirectoryNameEmpty,
};

const ConvertError = error{
    ErrorOpeningSomeFiles,
    ErrorSomeFilesDidNotMatch,
    ErrorSomeFilesDidNotParse,
    ErrorSomeFilesDidNotConvert,
};

pub fn main() !void {
    // validate program command line parameters
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len == 1) {
        try printUsageNormal();
        return;
    }

    var input_directory_name: []const u8 = "";
    var output_directory_name: []const u8 = "";
    for (args, 0..) |arg, arg_index| {
        switch (arg_index) {
            1 => input_directory_name = arg,
            2 => output_directory_name = arg,
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

    if (input_directory_name.len == 0) {
        std.log.err("input_directory_name must not be empty", .{});
        return error.InputDirectoryNameEmpty;
    }

    if (output_directory_name.len == 0) {
        std.log.err("output_directory_name must not be empty", .{});
        return error.OutputDirectoryNameEmpty;
    }

    std.log.debug("Validated the command line parameters - count: {}", .{args.len});
    for (args) |arg| {
        std.log.debug("{s}", .{arg});
    }

    var job_timer = try std.time.Timer.start();

    // open the input directory
    const input_dir_open_flags: std.fs.Dir.OpenDirOptions = .{
        .access_sub_paths = true,
    };
    var input_directory = blk: {
        if (std.fs.path.isAbsolute(input_directory_name))
            break :blk std.fs.openDirAbsolute(input_directory_name, input_dir_open_flags)
        else
            break :blk std.fs.cwd().openDir(input_directory_name, input_dir_open_flags);
    } catch |err| {
        std.log.err("Unable to open file input_directory_name: {s}\n", .{input_directory_name});
        return err;
    };
    defer input_directory.close();

    std.log.debug("Opened input directory: {s}", .{input_directory_name});

    try hashAllFiles(input_directory);
    try convertAllFiles(input_directory, output_directory_name);

    const seconds_elapsed = @as(f64, @floatFromInt(job_timer.read())) / 1000000000.0;
    std.log.info("Job completed successfully in {d:.3} seconds", .{seconds_elapsed});
}

fn hashAllFiles(input_directory: std.fs.Dir) !void {
    var all_input_files_opened = true;
    var all_input_files_matched = true;
    var hash_timer = try std.time.Timer.start();
    var bytes_hashed_per_files = std.mem.zeroes([shared_input_file_data.input_file_data.len]usize);

    {
        var thread_pool: std.Thread.Pool = undefined;
        try thread_pool.init(.{ .allocator = std.heap.page_allocator });
        defer thread_pool.deinit();

        for (shared_input_file_data.input_file_data[0..], 0..) |*input_entry, input_entry_index| {
            try thread_pool.spawn(doHashTask, .{ input_directory, input_entry, &all_input_files_opened, &all_input_files_matched, &bytes_hashed_per_files[input_entry_index] });
        }
    }

    {
        const seconds_elapsed = @as(f64, @floatFromInt(hash_timer.read())) / 1000000000.0;

        var input_files_total_bytes: usize = 0;
        for (0..shared_input_file_data.input_file_data.len) |i| {
            input_files_total_bytes += bytes_hashed_per_files[i];
        }

        const bytes_per_second: u64 = @intFromFloat(@as(f64, @floatFromInt(input_files_total_bytes)) / seconds_elapsed);
        std.log.info("Hashed a total of {:.3} in {d:.3}s ({:.3}/s)", .{
            std.fmt.fmtIntSizeBin(input_files_total_bytes),
            seconds_elapsed,
            std.fmt.fmtIntSizeBin(bytes_per_second),
        });
    }

    if (!all_input_files_opened) {
        std.log.err("Was not able to open all expected input files. Not starting conversion", .{});
        return error.ErrorOpeningSomeFiles;
    }

    if (!all_input_files_matched) {
        std.log.err("Not all input files matched their expected hash. Not starting conversion", .{});
        return error.ErrorSomeFilesDidNotMatch;
    }
}

fn doHashTask(input_directory: std.fs.Dir, input_entry: *const shared_input_file_data.InputFileData, all_input_files_opened: *bool, all_input_files_matched: *bool, bytes_read: *usize) void {
    // open the input file
    const input_file_open_flags: std.fs.File.OpenFlags = .{};

    const input_file = input_directory.openFile(input_entry.filename, input_file_open_flags) catch |err| {
        std.log.err("Unable to open file input_entry.filename: \"{s}\" - {}\n", .{ input_entry.filename, err });
        all_input_files_opened.* = false;
        return;
    };
    defer input_file.close();
    const input_file_r = input_file.reader();
    var input_file_cr = std.io.countingReader(input_file_r);
    const input_file_reader = input_file_cr.reader();

    std.log.debug("Opened input file: {s}", .{input_entry.filename});

    // hash the input file with sha256
    const input_file_digest_bytes = convert.hashSha256AndGetDigest(input_file_reader.any()) catch |err| {
        std.log.debug("Failed when hashing file: {s} - {}", .{ input_entry.filename, err });
        all_input_files_matched.* = false;
        return;
    };

    std.log.debug("Sha256 hashed input file: {s}", .{input_entry.filename});

    // verify the hash of the current input file
    std.log.info("{s}", .{input_entry.filename});
    std.log.info("Sha256: {s}", .{&std.fmt.bytesToHex(input_file_digest_bytes, .upper)});
    if (std.mem.eql(u8, &input_entry.digest, &input_file_digest_bytes)) {
        std.log.info(" (matched)", .{});
    } else {
        std.log.info(" (did not match)\nExpected: {s}", .{&std.fmt.bytesToHex(input_file_digest_bytes, .upper)});
        all_input_files_matched.* = false;
    }

    bytes_read.* = input_file_cr.bytes_read;
}

fn convertAllFiles(input_directory: std.fs.Dir, output_directory_name: []const u8) !void {
    // TODO: Multithread
    var all_input_files_opened = true;
    var all_input_files_parsed = true;
    var all_input_files_converted = true;

    var converter_arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer converter_arena_allocator.deinit();
    const converter_allocator = converter_arena_allocator.allocator();

    for (shared_input_file_data.input_file_data) |input_entry| {
        defer _ = converter_arena_allocator.reset(.free_all);

        // open the input file
        const input_file_open_flags: std.fs.File.OpenFlags = .{};

        const input_file = input_directory.openFile(input_entry.filename, input_file_open_flags) catch |err| switch (err) {
            else => {
                std.log.err("Unable to open file input_filename: {s} - {}\n", .{ input_entry.filename, err });
                all_input_files_opened = false;
                continue;
            },
        };
        defer input_file.close();

        var input_file_br = std.io.bufferedReader(input_file.reader());
        const input_file_reader = input_file_br.reader();

        std.log.debug("Opened input file: {s}", .{input_entry.filename});

        // create the output file
        const output_filename = try std.fs.path.join(converter_allocator, &.{
            output_directory_name,
            input_entry.filename,
        });
        defer converter_allocator.free(output_filename);

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
                        else => {
                            std.log.err("Unable to create output directory: {s}", .{output_dir_name});
                            return err;
                        },
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

        std.log.info("Converting input file: {s}", .{input_entry.filename});

        convert.convert(input_file_reader.any(), writer.any(), converter_allocator) catch |err| {
            // TODO: Bbetter way than this?
            match: inline for (&.{ fsb5.ParseError, libatrac9.Atrac9Error, libmp3lame.Mp3LameError, convert.ConvertError }) |err_type| {
                for (std.meta.tags(err_type)) |potential_error| {
                    if (potential_error == err) {
                        // It will definitely be one of these
                        switch (err_type) {
                            fsb5.ParseError => {
                                std.log.err("Failed to parse file: {s} - {}", .{ input_entry.filename, err });
                                all_input_files_parsed = false;
                            },
                            libatrac9.Atrac9Error => {
                                std.log.err("Failed to read atrac9 data from file: {s} - {}", .{ input_entry.filename, err });
                                all_input_files_converted = false;
                            },
                            libmp3lame.Mp3LameError => {
                                std.log.err("Failed to write mp3 data from file: {s} - {}", .{ input_entry.filename, err });
                                all_input_files_converted = false;
                            },
                            convert.ConvertError => {
                                std.log.err("Failed to convert file: {s} - {}", .{ input_entry.filename, err });
                                all_input_files_converted = false;
                            },
                            else => return err,
                        }
                        break :match;
                    }
                }
            } else {
                // Error does not match any known type
                return err;
            }
        };
    }

    if (!all_input_files_opened) {
        std.log.err("Was not able to open all expected input files. Not starting conversion", .{});
        return error.ErrorOpeningSomeFiles;
    }

    if (!all_input_files_parsed) {
        std.log.err("Was not able to parse all expected input files. Conversion failed", .{});
        return error.ErrorSomeFilesDidNotParse;
    }

    if (!all_input_files_converted) {
        std.log.err("Was not able to convert all expected input files. Conversion failed", .{});
        return error.ErrorSomeFilesDidNotConvert;
    }
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
