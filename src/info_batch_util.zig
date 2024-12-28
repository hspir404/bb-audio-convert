const builtin = @import("builtin");
const std = @import("std");
const fsb5 = @import("fsb5");
const shared_input_file_data = @import("input_file_data.zig");
const Sha256 = std.crypto.hash.sha2.Sha256;

const ArgsError = error{
    NotEnoughArgs,
    TooManyArgs,
    InputDirectoryNameEmpty,
    CannotOpenInputDirectory,
    ErrorOpeningSomeFiles,
    ErrorSomeFilesDidNotMatch,
    ErrorSomeFilesDidNotParse,
    ErrorSomeFilesDidNotPrint,
};

pub fn main() !void {}
// pub fn main() !void {
//     var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena_allocator.deinit();
//     const allocator = arena_allocator.allocator();
//     const args = try std.process.argsAlloc(allocator);
//     defer std.process.argsFree(allocator, args);

//     var input_directory_name: []const u8 = "";
//     for (args, 0..) |arg, arg_index| {
//         switch (arg_index) {
//             1 => input_directory_name = arg,
//             else => {},
//         }
//     }

//     if (args.len < 2) {
//         try printUsageError();
//         return error.NotEnoughArgs;
//     }

//     if (args.len > 2) {
//         try printUsageError();
//         return error.TooManyArgs;
//     }

//     if (input_directory_name.len == 0) {
//         std.debug.print("input_directory_name must not be empty\n", .{});
//         return error.InputDirectoryNameEmpty;
//     }

//     const input_dir_open_flags: std.fs.Dir.OpenDirOptions = .{
//         .access_sub_paths = true,
//     };
//     var input_directory = blk: {
//         if (std.fs.path.isAbsolute(input_directory_name))
//             break :blk std.fs.openDirAbsolute(input_directory_name, input_dir_open_flags)
//         else
//             break :blk std.fs.cwd().openDir(input_directory_name, input_dir_open_flags);
//     } catch |err| switch (err) {
//         else => {
//             std.debug.print("Unable to open file input_directory_name: {s}\n", .{input_directory_name});
//             return err;
//         },
//     };
//     defer input_directory.close();

//     const input_file_open_flags: std.fs.File.OpenFlags = .{};
//     var all_input_files_opened = true;
//     var all_input_files_matched = true;
//     var all_input_files_parsed = true;
//     var all_input_files_printed = true;
//     for (shared_input_file_data.input_file_data) |input_entry| {
//         const input_file = input_directory.openFile(input_entry.filename, input_file_open_flags) catch |err| switch (err) {
//             else => {
//                 std.debug.print("Unable to open file input_filename: {s} - {}\n", .{ input_entry.filename, err });
//                 all_input_files_opened = false;
//                 continue;
//             },
//         };
//         defer input_file.close();

//         const max_bytes_to_read = 200 * 1024 * 1024; // Biggest input file is 189MB
//         const input_file_data = try input_file.readToEndAlloc(allocator, max_bytes_to_read);
//         defer allocator.free(input_file_data);

//         var input_file_digest_bytes: [Sha256.digest_length]u8 = undefined;
//         Sha256.hash(input_file_data, &input_file_digest_bytes, .{});

//         const stdout_file = std.io.getStdOut().writer();
//         var bw = std.io.bufferedWriter(stdout_file);
//         var writer = bw.writer();
//         defer bw.flush() catch {};

//         try writer.print("{s}\n", .{input_entry.filename});

//         try writer.writeAll("Sha256: ");
//         try writeHexBytes(&input_file_digest_bytes, writer.any());
//         if (std.mem.eql(u8, &input_entry.digest, &input_file_digest_bytes)) {
//             try writer.writeAll(" (matched)\n");
//         } else {
//             try writer.writeAll(" (did not match)\n");
//             all_input_files_matched = false;
//         }

//         const input_fsb_file = fsb5.File.init(input_file_data) catch {
//             try writer.writeAll("(FAILED TO PARSE)\n");
//             all_input_files_parsed = false;
//             continue;
//         };
//         writeFsb5FileInfo(input_fsb_file, writer.any(), allocator) catch {
//             try writer.writeAll("(FAILED TO WRITE INFO)\n");
//             all_input_files_printed = false;
//             continue;
//         };
//     }

//     if (!all_input_files_opened) {
//         return error.ErrorOpeningSomeFiles;
//     }

//     if (!all_input_files_matched) {
//         return error.ErrorSomeFilesDidNotMatch;
//     }

//     if (!all_input_files_parsed) {
//         return error.ErrorSomeFilesDidNotParse;
//     }

//     if (!all_input_files_printed) {
//         return error.ErrorSomeFilesDidNotPrint;
//     }
// }

// fn printUsageNormal() !void {
//     try printUsageImpl(false);
// }

// fn printUsageError() !void {
//     try printUsageImpl(true);
// }

// fn printUsageImpl(is_error: bool) !void {
//     // TODO: Some fancy programmatic way to get the program name?
//     const usage =
//         \\Usage: bb-audio-info-batch input_directory_name
//         \\
//     ;

//     if (is_error) {
//         std.debug.print(usage, .{});
//     } else {
//         const stdout_file = std.io.getStdOut().writer();
//         var bw = std.io.bufferedWriter(stdout_file);
//         var writer = bw.writer();
//         try writer.print(usage, .{});
//         try bw.flush();
//     }
// }

// fn writeHexBytes(value: []const u8, writer: std.io.AnyWriter) !void {
//     for (value) |value_byte| {
//         try std.fmt.formatInt(value_byte, 16, .upper, std.fmt.FormatOptions{ .fill = '0', .width = 2 }, writer);
//     }
// }

// fn writeFsb5FileInfo(file: fsb5.File, writer: std.io.AnyWriter, allocator: std.mem.Allocator) !void {
//     // TODO: Subsong data types / flag types, also put them in shared data file so we can validate them

//     // try writer.print("File size: {} byte(s)\n", .{getThousandsSeparatedInt(file.len, ",")});
//     // try writer.print("\n", .{});
//     // try writer.print("Main header information ({} byte(s), since minor version is {}) -\n", .{ try file.base_header.get_size(), file.base_header.version_minor });
//     // try writer.print("\n", .{});
//     // try writer.print("MAGIC (3 bytes): {s}\n", .{file.base_header.get_magic_bytes()[0..3].*});
//     // try writer.print("FSB Version Major (1 byte): {}\n", .{try file.base_header.get_version_major_int()});
//     // try writer.print("FSB Version Minor (4 bytes): {}\n", .{getThousandsSeparatedInt(file.base_header.version_minor, ",")});
//     // try writer.print("Subsong Count (4 bytes): {}\n", .{getThousandsSeparatedInt(file.base_header.subsong_count, ",")});
//     // try writer.print("Subsong Header Size (total) (4 bytes): {} byte(s)\n", .{getThousandsSeparatedInt(file.base_header.subsong_header_size, ",")});
//     // try writer.print("Subsong Name Table Size (total) (4 bytes): {} byte(s)\n", .{getThousandsSeparatedInt(file.base_header.subsong_name_table_size, ",")});
//     // try writer.print("Subsong Sample Data Size (total) (4 bytes): {} byte(s)\n", .{getThousandsSeparatedInt(file.base_header.subsong_sample_data_size, ",")});

//     const sample_data_codec_name = try file.base_header.sample_data_codec.get_display_string(allocator);
//     defer allocator.free(sample_data_codec_name);

//     try writer.print("Codec of Subsong Samples (4 bytes): {} ({s})\n", .{ @intFromEnum(file.base_header.sample_data_codec), sample_data_codec_name });

//     // try writer.print("Flags (4 bytes): {} (0b{b:0>32})\n", .{ getThousandsSeparatedInt(file.base_header.flags, ","), file.base_header.flags });

//     // switch (file.base_header.version_minor) {
//     //     0 => {
//     //         try writer.print("Primary Hash (16 bytes): 0x{X}\n", .{file.base_header._end_of_struct.v0._primary_hash});
//     //         try writer.print("Secondary Hash (8 bytes): 0x{X}\n", .{file.base_header._end_of_struct.v0._secondary_hash});
//     //     },
//     //     1 => {
//     //         try writer.print("<unknown> (4 bytes): {} (0b{b:0>32})\n", .{ file.base_header._end_of_struct.v1._unknown, file.base_header._end_of_struct.v1._unknown });
//     //         try writer.print("Primary Hash (16 bytes): 0x{X}\n", .{file.base_header._end_of_struct.v1._primary_hash});
//     //         try writer.print("Secondary Hash (8 bytes): 0x{X}\n", .{file.base_header._end_of_struct.v1._secondary_hash});
//     //     },
//     //     else => unreachable,
//     // }

//     // try writer.print("\n", .{});
//     // try writer.print("Subsong header information ({} byte(s), as mentioned in main header) -\n", .{getThousandsSeparatedInt(file.base_header.subsong_header_size, ",")});
//     // try writer.print("\n", .{});

//     // var current_subsong_index: usize = 0;
//     // var subsong_metadata_iter = file.get_subsong_metadata_iter();
//     // while (try subsong_metadata_iter.next()) |subsong_metadata| {
//     //     const header = subsong_metadata.subsong_header;
//     //     const frequency = header.sample_rate_type.get_frequency();
//     //     try writer.print("Subsong {}:\n", .{current_subsong_index + 1});
//     //     try writer.print("  Main info (8 bytes):\n", .{});
//     //     try writer.print("    Num samples (bits 34 through 63): {} sample(s) ({d}s at specified sample rate)\n", .{ getThousandsSeparatedInt(header.sample_count, ","), @as(f32, @floatFromInt(header.sample_count)) / @as(f32, @floatFromInt(frequency)) });
//     //     try writer.print("    Data offset (bits  7 through 33): {} byte(s) (from start of sample data)\n", .{getThousandsSeparatedInt(header.data_offset, ",")});
//     //     try writer.print("    Channels (bits 5 through 6): {} ({} channel)\n", .{ @intFromEnum(header.channel_count_type), header.channel_count_type.get_channel_count() });
//     //     try writer.print("    Sample rate (bits 1 through 4): {} ({}hz)\n", .{ @intFromEnum(header.sample_rate_type), getThousandsSeparatedInt(frequency, ",") });
//     //     try writer.print("    Has flags (bit 0): {b} ({})\n", .{ @intFromBool(header.has_flags), header.has_flags });

//     //     if (header.has_flags) {
//     //         var flags_iter = subsong_metadata.get_subsong_flags_iter();
//     //         var flag_index: usize = 0;
//     //         while (try flags_iter.next()) |flag| : (flag_index += 1) {
//     //             try writer.print("  Flag {} ({} byte(s). 4 for base info, +extra data size mentioned in flag size below):\n", .{ flag_index + 1, flag.get_size() });
//     //             try writer.print("    Flag type (bits 25 through 31): {} ({s})\n", .{ @intFromEnum(flag.flag_type), @tagName(flag.flag_type) });
//     //             try writer.print("    Flag extra data size (bits  1 through 24): {} byte(s)\n", .{getThousandsSeparatedInt(flag.extra_flag_data_size, ",")});
//     //             try writer.print("    More flags after this (bit 0): {b} ({})\n", .{ @intFromBool(flag.has_more_flags), flag.has_more_flags });

//     //             switch (flag.flag_type) {
//     //                 .None => {},
//     //                 .ChannelOverride => {},
//     //                 .SampleRateOverride => {},
//     //                 .LoopInfo => {
//     //                     const loop_info = flag.extra_flag_data.LoopInfo;
//     //                     try writer.print("    Loop start (4 bytes): {} sample(s)\n", .{getThousandsSeparatedInt(loop_info.loop_start_sample, ",")});
//     //                     try writer.print("    Loop end (4 bytes): {} sample(s) (in data in the file. +1 = {}, actual value)\n", .{ getThousandsSeparatedInt(loop_info.loop_end_sample, ","), getThousandsSeparatedInt(loop_info.loop_end_sample +% 1, ",") }); // TODO: What to do with int overflow here?
//     //                 },
//     //                 .FreeCommentOrSfxInfo => {},
//     //                 .Unknown5 => {},
//     //                 .XmaSeekTable => {},
//     //                 .DspCoefficients => {},
//     //                 .Atrac9Config => {
//     //                     try writer.print("    ATRAC9 config ({} byte(s)) - this is information used by the ATRAC9 decoder itself:\n", .{flag.extra_flag_data_size});

//     //                     const flag_data_atrac9_config = flag.extra_flag_data.Atrac9Config;
//     //                     var config_size_bytes = flag.extra_flag_data_size;
//     //                     const atrac9_config = blk: {
//     //                         if (flag_data_atrac9_config.magic_byte_char != 0xFE) {
//     //                             try writer.print("      Frame size (4 bytes): {} byte(s)\n", .{flag_data_atrac9_config.with_frame_size.frame_size_bytes});
//     //                             config_size_bytes -= 4;
//     //                             break :blk flag_data_atrac9_config.with_frame_size.config;
//     //                         } else {
//     //                             break :blk flag_data_atrac9_config.without_frame_size;
//     //                         }
//     //                     };

//     //                     if (config_size_bytes == 4) {
//     //                         const config = atrac9_config.standard;
//     //                         try writer.print("      ATRAC9 _actual_ config (4 bytes):\n", .{});
//     //                         try writer.print("        Magic config id (1 byte): {} (0x{X})\n", .{ config.magic_byte_char, config.magic_byte_char });
//     //                         try writer.print("        Sample rate index (next 4 bits): {}\n", .{config.sample_rate_index});
//     //                         try writer.print("        Channel config index (next 3 bits): {}\n", .{config.channel_config_index});
//     //                         try writer.print("        Validation bit (next 1 bit): {b} ({})\n", .{ @intFromBool(config.validation_bit), config.validation_bit });
//     //                         try writer.print("        Frame bytes (next 11 bits): {} (in data in the file. +1 = {}, actual value)\n", .{ config.frame_bytes, config.frame_bytes + 1 });
//     //                         try writer.print("        Superframe index (next 2 bits): {}\n", .{config.superframe_index});
//     //                         try writer.print("        <Next 3 bits seem to be unused>: {} (0b{b:03})\n", .{ config._unused, config._unused });
//     //                     } else {
//     //                         // TODO: Handle layers? Not sure how MP3 would handle that.
//     //                         unreachable;
//     //                     }
//     //                 },
//     //                 .XwmaConfig => {},
//     //                 .VorbisSetupIdAndSeekTable => {},
//     //                 .PeakVolume => {},
//     //                 .VorbisIntraLayers => {},
//     //                 .OpusDataSizeIgnoringFrameHeaders => {},
//     //             }
//     //         }
//     //     }

//     //     current_subsong_index += 1;
//     // }

//     // try writer.print("\n", .{});
//     // try writer.print("Subsong name table information ({} byte(s), as mentioned in main header) -\n", .{getThousandsSeparatedInt(file.base_header.subsong_name_table_size, ",")});
//     // try writer.print("\n", .{});

//     // var subsong_table_name_byte_count: usize = 0;
//     // current_subsong_index = 0;
//     // var subsong_name_iter = file.get_subsong_name_iter();
//     // while (try subsong_name_iter.next()) |subsong_name| {
//     //     try writer.print("Subsong {} name start offset (4 bytes): {} bytes (from start of subsong name table)\n", .{ current_subsong_index + 1, subsong_name.subsong_name_table_byte_offset });
//     //     subsong_table_name_byte_count += 4;
//     //     current_subsong_index += 1;
//     // }

//     // current_subsong_index = 0;
//     // subsong_name_iter = file.get_subsong_name_iter();
//     // while (try subsong_name_iter.next()) |subsong_name| {
//     //     try writer.print("Subsong {} name ({} byte(s), zero terminated): {s}\n", .{ current_subsong_index + 1, subsong_name.subsong_name.len + 1, subsong_name.subsong_name });
//     //     subsong_table_name_byte_count += subsong_name.subsong_name.len + 1;
//     //     current_subsong_index += 1;
//     // }

//     // if (subsong_table_name_byte_count < file.base_header.subsong_name_table_size) {
//     //     try writer.print("<unused space> ({} byte(s))\n", .{file.base_header.subsong_name_table_size - subsong_table_name_byte_count});
//     // }

//     // try writer.print("\n", .{});
//     // try writer.print("Subsong sample data information ({} byte(s), as mentioned in the main header) -\n", .{getThousandsSeparatedInt(file.base_header.subsong_sample_data_size, ",")});
//     // try writer.print("\n", .{});

//     // current_subsong_index = 0;
//     // var subsong_sample_data_iter = try file.get_subsong_sample_data_iter();
//     // while (try subsong_sample_data_iter.next()) |subsong_sample_data| {
//     //     // TODO: Actually print out what file type the sample data was instead of hard coding it
//     //     try writer.print("Subsong sample data {} ({} bytes): MP3 formatted data\n", .{ current_subsong_index + 1, getThousandsSeparatedInt(subsong_sample_data.subsong_sample_data.len, ",") });
//     //     current_subsong_index += 1;
//     // }

//     // // Note: subsong sample data is specified with it start offset. So the last sample data will by definition take up the rest of the file.
//     // // TODO: Is that accurate? Or can we calculate it from the sample count somehow?
// }

// fn getThousandsSeparatedInt(value: anytype, comptime separator: []const u8) ThousandSeparatedInt(@TypeOf(value), separator) {
//     const result = ThousandSeparatedInt(@TypeOf(value), separator).init(value);
//     return result;
// }

// fn ThousandSeparatedInt(comptime T: type, separator: []const u8) type {
//     return struct {
//         const Self = @This();
//         value: T,

//         pub fn init(value: T) Self {
//             const result = Self{
//                 .value = value,
//             };
//             return result;
//         }

//         pub fn format(
//             self: Self,
//             comptime fmt: []const u8,
//             options: std.fmt.FormatOptions,
//             writer: anytype,
//         ) !void {
//             _ = fmt;
//             _ = options; // TODO: Actually honor width, fill, and alignment

//             const max_thousands_sections = comptime std.math.log10(std.math.maxInt(T)) / 3;
//             var thousand_sections = std.mem.zeroes([max_thousands_sections]u10);

//             var remaining_value = self.value;
//             var current_index: usize = max_thousands_sections;
//             var thousand_section_count: usize = 0;
//             while (remaining_value > 1000) : ({
//                 remaining_value /= 1000;
//                 thousand_section_count += 1;
//             }) {
//                 current_index -= 1;
//                 thousand_sections[current_index] = @truncate(@rem(remaining_value, 1000));
//             }

//             try std.fmt.formatInt(remaining_value, 10, .lower, std.fmt.FormatOptions{}, writer);

//             const thousands_fill_zeroes = std.fmt.FormatOptions{ .width = 3, .fill = '0' };
//             for (current_index..max_thousands_sections) |index| {
//                 _ = try writer.write(separator);
//                 try std.fmt.formatInt(thousand_sections[index], 10, .lower, thousands_fill_zeroes, writer);
//             }
//         }
//     };
// }
