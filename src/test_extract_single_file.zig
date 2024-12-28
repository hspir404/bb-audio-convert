const std = @import("std");
const fsb5 = @import("fsb5");
const libmp3lame = @import("libmp3lame");

const Error = error{
    NotEnoughArgs,
    EmptyInputFilename,
    EmptyOutputFilename,
    CouldNotOpenInputFile,
};

pub fn main() !void {
    // validate program command line parameters
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len < 4) {
        return error.NotEnoughArgs;
    }

    var input_filename: []const u8 = "";
    var output_filename1: []const u8 = "";
    var output_filename2: []const u8 = "";
    for (args, 0..) |arg, arg_index| {
        switch (arg_index) {
            1 => input_filename = arg,
            2 => output_filename1 = arg,
            3 => output_filename2 = arg,
            else => {},
        }
    }

    if (input_filename.len == 0) {
        std.log.err("input_filename must not be empty", .{});
        return error.EmptyInputFilename;
    }

    if (output_filename1.len == 0) {
        std.log.err("output_filename1 must not be empty", .{});
        return error.EmptyOutputFilename;
    }

    if (output_filename2.len == 0) {
        std.log.err("output_filename2 must not be empty", .{});
        return error.EmptyOutputFilename;
    }

    std.log.debug("Validated the command line parameters - count: {}", .{args.len});
    for (args) |arg| {
        std.log.debug("{s}", .{arg});
    }

    const input_file = std.fs.openFileAbsolute(input_filename, .{}) catch |err| {
        std.log.err("could not open input file: {s} - error: {}", .{ input_filename, err });
        return error.CouldNotOpenInputFile;
    };
    defer input_file.close();

    const output_file1 = std.fs.createFileAbsolute(output_filename1, .{}) catch |err| {
        std.log.err("could not open output file 1: {s} - error: {}", .{ output_filename1, err });
        return error.CouldNotOpenInputFile;
    };
    defer output_file1.close();
    const output_file1_writer = output_file1.writer();

    const output_file2 = std.fs.createFileAbsolute(output_filename2, .{}) catch |err| {
        std.log.err("could not open output file 2: {s} - error: {}", .{ output_filename2, err });
        return error.CouldNotOpenInputFile;
    };
    defer output_file2.close();
    const output_file2_writer = output_file2.writer();
    _ = output_file2_writer; // autofix

    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();

    var input_file_iter = fsb5.File.read(input_file.reader().any(), allocator);
    const lame_decoder = try libmp3lame.initDecoder();
    defer libmp3lame.freeDecoder(lame_decoder);
    var sample_count_to_read: ?usize = null;

    while (try input_file_iter.next()) |token| {
        switch (token) {
            .subsong_header => |subsong_header| {
                sample_count_to_read = subsong_header.sample_count;
            },
            .subsong_sample_data => |subsong_sample_data| {
                // subsong_sample_data.data_reader
                if (sample_count_to_read) |expected_sample_count| {
                    // libmp3lame.initDecoder()
                    //const decode_buffer = try allocator.alloc(u8, subsong_sample_data.data_size_bytes);
                    var data_reader = subsong_sample_data.data_reader;
                    const input_mp3_data_buffer = try data_reader.reader().readAllAlloc(allocator, subsong_sample_data.data_size_bytes);
                    defer allocator.free(input_mp3_data_buffer);
                    const output_pcm_left = try allocator.alloc(i16, expected_sample_count * 4);
                    defer allocator.free(output_pcm_left);
                    const output_pcm_right = try allocator.alloc(i16, expected_sample_count * 4);
                    defer allocator.free(output_pcm_right);

                    var mp3_data: libmp3lame.mp3data_struct = undefined;
                    const header_samples_decoded = try libmp3lame.decodeHeaders(lame_decoder, input_mp3_data_buffer, output_pcm_left, output_pcm_right, &mp3_data);
                    std.debug.assert(header_samples_decoded == 0);

                    const samples_decoded = try libmp3lame.decode(lame_decoder, input_mp3_data_buffer, output_pcm_left, output_pcm_right);
                    std.debug.assert(samples_decoded == expected_sample_count * 4); // TODO: Why 4x and not 2x? There's two output channel already. I'd expect those to just be double length

                    const channel_count = 2;
                    try output_file1_writer.writeAll("RIFF");
                    // TODO: Figure out right value after data headers
                    try output_file1_writer.writeInt(u32, @truncate(expected_sample_count * @sizeOf(i16) * channel_count + 44), .little);
                    try output_file1_writer.writeAll("WAVE");

                    try output_file1_writer.writeAll("fmt ");
                    try output_file1_writer.writeInt(u32, 16, .little); // bytes (after this) in this fmt entry
                    try output_file1_writer.writeInt(u16, 1, .little); // PCM
                    try output_file1_writer.writeInt(u16, 1, .little); // two channels
                    try output_file1_writer.writeInt(u32, 48000, .little); // samples per second
                    try output_file1_writer.writeInt(u32, 96000, .little); // bytes per second
                    try output_file1_writer.writeInt(u16, 2, .little); // block align
                    try output_file1_writer.writeInt(u16, 16, .little); // bits per sample

                    try output_file1_writer.writeAll("data");
                    const bytes_to_write = expected_sample_count * @sizeOf(i16) * 2;
                    try output_file1_writer.writeInt(u32, @truncate(bytes_to_write / 2), .little); // data size in bytes
                    // try output_file1_writer.writeAll(@as([*]const u8, @ptrCast(&output_pcm_right[0]))[0..samples_decoded]);
                    var bytes_written: usize = 1152;
                    const bytes_in_frame = @as(usize, @intCast(mp3_data.framesize)) * @sizeOf(i16) * 2;
                    const samples_to_write_buffer = @as([*]const u8, @ptrCast(&output_pcm_right[0]));
                    while (bytes_written < bytes_to_write) {
                        try output_file1_writer.writeAll(samples_to_write_buffer[bytes_written .. bytes_written + bytes_in_frame]);
                        bytes_written += bytes_in_frame;
                    }

                    // try output_file2.writeAll("RIFF");
                    // try output_file2.writeAll(samples_decoded.len);
                } else unreachable;
            },
            else => {
                // Don't care
            },
        }
    }

    std.log.info("Job's done", .{});
}
