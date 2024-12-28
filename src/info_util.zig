const builtin = @import("builtin");
const std = @import("std");
const fsb5 = @import("fsb5");

const ArgsError = error{
    NotEnoughArgs,
    TooManyArgs,
    InputFilenameEmpty,
    InputFilenameWrongExtension,
};

pub fn main() !void {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var input_filename: []const u8 = "";
    for (args, 0..) |arg, arg_index| {
        switch (arg_index) {
            1 => input_filename = arg,
            else => {},
        }
    }

    if (args.len < 2) {
        try printUsageError();
        return error.NotEnoughArgs;
    }

    if (args.len > 2) {
        try printUsageError();
        return error.TooManyArgs;
    }

    if (input_filename.len == 0) {
        std.log.err("input_filename must not be empty\n", .{});
        return error.InputFilenameEmpty;
    }

    const input_filename_extension = std.fs.path.extension(input_filename);
    const fsb5_filename_extension = ".fsb";
    if (!std.mem.eql(u8, input_filename_extension, fsb5_filename_extension)) {
        std.log.err("input_filename has wrong extension. Expected: {s} - Actual: {s}\n", .{ fsb5_filename_extension, input_filename_extension });
        return error.InputFilenameWrongExtension;
    }

    const input_file_open_flags = .{};
    const input_file = blk: {
        if (std.fs.path.isAbsolute(input_filename))
            break :blk std.fs.openFileAbsolute(input_filename, input_file_open_flags)
        else
            break :blk std.fs.cwd().openFile(input_filename, input_file_open_flags);
    } catch |err| switch (err) {
        else => {
            std.log.err("Unable to open file input_filename: {s}\n", .{input_filename});
            return err;
        },
    };
    defer input_file.close();

    const max_bytes_to_read = 200 * 1024 * 1024; // Biggest input file is 189MB
    var limited_input_file_reader = std.io.limitedReader(input_file.reader(), max_bytes_to_read);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    var writer = bw.writer();

    try writer.print("{s}\n", .{input_filename});
    try writer.print("\n", .{});
    try writeFsb5FileVerbose(limited_input_file_reader.reader().any(), writer.any(), allocator);

    try bw.flush();
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
        \\Usage: bb-audio-fsb5-file-info input_filename
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

// TODO: Move this to shared code?
fn writeFsb5FileVerbose(reader: std.io.AnyReader, writer: std.io.AnyWriter, allocator: std.mem.Allocator) !void {
    var input_fsb_file_iter = fsb5.File.read(reader, allocator);
    defer input_fsb_file_iter.free();

    var subsong_header_index: usize = 0;
    var subsong_flag_index: usize = 0;
    var subsong_name_index: usize = 0;
    var subsong_sample_data_index: usize = 0;

    while (try input_fsb_file_iter.next()) |token| {
        switch (token) {
            .base_header => |base_header| {
                try writer.print("Magic byte chars: {s}\n", .{base_header.magic_bytes});
                try writer.print("Version Major: {}\n", .{base_header.version_major});
                try writer.print("Version Minor: {}\n", .{base_header.version_minor});
                try writer.print("Subsong Count: {}\n", .{base_header.subsong_count});
                try writer.print("Subsong Sample Data Codec: {} ({s})\n", .{ @intFromEnum(base_header.subsong_sample_data_codec), @tagName(base_header.subsong_sample_data_codec) });
                try writer.print("Flags: {} (0b{b:0>32})\n", .{ base_header.flags, base_header.flags });
                try writer.print("Primary Hash: {X:0>32}\n", .{base_header.primary_hash});
                try writer.print("Secondary Hash: {X:0>16}\n", .{base_header.secondary_hash});
            },

            .subsong_header => |subsong_header| {
                try writer.print("Subsong Header: {}\n", .{subsong_header_index + 1});
                try writer.print("  Has Flags: {}\n", .{subsong_header.has_flags});
                try writer.print("  Sample Rate: {} ({s} - {}hz)\n", .{ @intFromEnum(subsong_header.sample_rate_type), @tagName(subsong_header.sample_rate_type), subsong_header.sample_rate_type.getFrequency() });
                try writer.print("  Channel Count: {} ({s} - {} channels)\n", .{ @intFromEnum(subsong_header.channel_count_type), @tagName(subsong_header.channel_count_type), subsong_header.channel_count_type.getChannelCount() });
                try writer.print("  Sample Data Offset: {} bytes\n", .{subsong_header.sample_data_offset});
                try writer.print("  Sample Count: {} samples\n", .{subsong_header.sample_count});
                subsong_header_index += 1;
                subsong_flag_index = 0;
            },

            .subsong_flag => |subsong_flag| {
                try writer.print("  Subsong Flag: {}\n", .{subsong_flag_index + 1});
                try writer.print("    Has More Flags: {}\n", .{subsong_flag.has_more_flags});
                try writer.print("    Flag Data Size: {}\n", .{subsong_flag.flag_data_size});
                try writer.print("    Flag Type: {} ({s})\n", .{ @intFromEnum(std.meta.activeTag(subsong_flag.data)), @tagName(std.meta.activeTag(subsong_flag.data)) });
                try writer.print("    Flag Data:\n", .{});

                switch (subsong_flag.data) {
                    .none => unreachable,
                    .channel_override => unreachable,
                    .sample_rate_override => unreachable,

                    .loop_info => |loop_info| {
                        try writer.print("      Loop Start Sample: {}\n", .{loop_info.loop_start_sample});
                        try writer.print("      Loop End Sample: {}\n", .{loop_info.loop_end_sample});
                    },

                    .free_comment_or_sfx_info => unreachable,
                    .unknown_5 => unreachable,
                    .xma_seek_table => unreachable,
                    .dsp_coefficients => unreachable,

                    .atrac9_config => |atrac9_config| {
                        try writer.print("      Frame Size: {} bytes\n", .{atrac9_config.frame_size_bytes});
                        // TODO: Handle layered config
                        const config_standard = atrac9_config.config.standard;
                        try writer.print("      Magic Byte: {X:0>2}\n", .{config_standard.magic_byte_char});
                        try writer.print("      Sample Rate Index: {}\n", .{config_standard.sample_rate_index});
                        try writer.print("      Channel Config Index: {}\n", .{config_standard.channel_config_index});
                        try writer.print("      Validation Bit: {}\n", .{config_standard.validation_bit});
                        try writer.print("      Frame Size (?): {} bytes\n", .{config_standard.frame_size_bytes});
                        try writer.print("      Superframe Index: {}\n", .{config_standard.superframe_index});
                        try writer.print("      <Unused>: {b:03}\n", .{config_standard._unused});
                    },

                    .xwma_config => unreachable,
                    .vorbis_setup_id_and_seek_table => unreachable,
                    .peak_volume => unreachable,
                    .vorbis_intra_layers => unreachable,
                    .opus_data_size_ignoring_frame_headers => unreachable,
                }
                subsong_flag_index += 1;
            },

            .subsong_name => |subsong_name| {
                try writer.print("  Subsong {} Name: {s}\n", .{ subsong_name_index, subsong_name });
                subsong_name_index += 1;
            },

            .subsong_sample_data => |subsong_sample_data| {
                try writer.print("  Subsong {} Sample Data:\n", .{subsong_sample_data_index});
                try writer.print("    Length - Expected: {} bytes\n", .{subsong_sample_data.data_size_bytes});

                var sample_data_limited_reader = subsong_sample_data.data_reader;
                var sample_data_reader = sample_data_limited_reader.reader();
                const data_length = try sample_data_reader.any().discard();

                try writer.print("    Length - Actual: {} bytes\n", .{data_length});

                subsong_sample_data_index += 1;
            },

            .end_of_tokens => {
                try writer.print("End of File\n", .{});
            },
        }
    }

    std.log.err("Data at end of file: {} bytes\n", .{try reader.discard()});
}
