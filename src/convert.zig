const std = @import("std");
const fsb5 = @import("fsb5");
const libatrac9 = @import("libatrac9");
const libmp3lame = @import("libmp3lame");
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const ConvertError = error{
    InputFileWrongSubsongSampleDataCodecType,
    InputFileNoAtrac9ConfigFlagInSubsongHeader,
    InputFileWrongChannelCountInSubsongSampleData,
    InputFileTooLittleSampleData,
    ChannelCountNotYetImplemented,
};

pub fn hashSha256AndGetDigest(input_reader: std.io.AnyReader) ![Sha256.digest_length]u8 {
    var sha256 = Sha256.init(.{});
    const output_hash_writer = sha256.writer();

    // TODO: Is there somewhere we can grab the 4096 constant from? It seems to be the typical value for buffered readers and writers
    var reader_writer_fifo = std.fifo.LinearFifo(u8, .{ .Static = 4096 }).init();
    try reader_writer_fifo.pump(input_reader, output_hash_writer);

    const result = sha256.finalResult();
    return result;
}

pub fn convert(input_reader: std.io.AnyReader, output_writer: std.io.AnyWriter, allocator: std.mem.Allocator) !void {
    // prepare to read in the input file
    var input_fsb_file_iter = fsb5.File.read(input_reader, allocator);
    defer input_fsb_file_iter.free();

    // setup allocations to stash tokens for later reference.
    // they could just be written out if this code wasn't going to convert the audio data,
    //   but we need to reference them to calculate new data sizes.
    var base_header: fsb5.BaseHeader = undefined;
    var base_header_size_bytes: usize = 0;

    var subsong_headers = std.ArrayList(fsb5.SubsongHeader).init(allocator);
    defer subsong_headers.clearAndFree();

    var flags_per_subsong = std.ArrayList(std.ArrayList(fsb5.SubsongFlag)).init(allocator);
    defer {
        for (flags_per_subsong.items) |*subsong_flags| {
            subsong_flags.clearAndFree();
        }
        flags_per_subsong.clearAndFree();
    }

    var subsong_headers_size_bytes: usize = 0;

    var subsong_names = std.ArrayList([:0]const u8).init(allocator);
    defer subsong_names.clearAndFree();

    var subsong_name_table_size_bytes: usize = 0;

    var mp3_sample_data_per_subsong = std.ArrayList([]const u8).init(allocator);
    defer {
        for (mp3_sample_data_per_subsong.items) |subsong_mp3_sample_data| {
            allocator.free(subsong_mp3_sample_data);
        }
        mp3_sample_data_per_subsong.clearAndFree();
    }

    var subsong_sample_data_total_size_bytes: usize = 0;

    std.log.debug("Created memory to capture tokens for modification", .{});

    const max_songs_to_encode: usize = 2; // TODO: DELETE THIS
    var temp_delete_this: usize = 0; // TODO: DELETE THIS
    var last_flags = false; // TODO: DELETE THIS
    var hit_names = false; // TODO: DELETE THIS
    var hit_samples = false; // TODO: DELETE THIS

    // capture all the tokens
    while (try input_fsb_file_iter.next()) |token| {
        switch (token) {
            .base_header => |base_header_token| {
                const actual_subsong_sample_data_codec = base_header_token.subsong_sample_data_codec;
                if (actual_subsong_sample_data_codec != .atrac9) {
                    std.log.err("Input file does not have Atrac9 data - actual codec: {s}", .{@tagName(actual_subsong_sample_data_codec)});
                    return error.InputFileWrongSubsongSampleDataCodecType;
                }

                base_header = base_header_token;
                base_header.subsong_count = @min(max_songs_to_encode, base_header.subsong_count); // TODO: DELETE THIS
                base_header_size_bytes = base_header_token.getFileSizeBytes();

                std.log.debug(
                    \\Got base_header token - v{}.{} header
                    \\  base_header_size_bytes: {}
                    \\  subsong_count: {}
                    \\  subsong_sample_data_codec: {} ({s})
                    \\  flags: {} ({b:0>32})
                    \\  primary_hash: {X:0>16}
                    \\  secondary_hash: {X:0>8}
                ,
                    .{
                        base_header.version_major,
                        base_header.version_minor,
                        base_header_size_bytes,
                        base_header.subsong_count,
                        @intFromEnum(base_header.subsong_sample_data_codec),
                        @tagName(base_header.subsong_sample_data_codec),
                        base_header.flags,
                        base_header.flags,
                        base_header.primary_hash,
                        base_header.secondary_hash,
                    },
                );
            },

            .subsong_header => |subsong_header| {
                last_flags = false; // TODO: DELETE THIS
                if (temp_delete_this >= max_songs_to_encode) continue; // TODO: DELETE THIS

                try subsong_headers.append(subsong_header);
                try flags_per_subsong.append(std.ArrayList(fsb5.SubsongFlag).init(allocator));

                const subsong_header_size_bytes = subsong_header.getFileSizeBytes();
                subsong_headers_size_bytes += subsong_header_size_bytes;

                std.log.debug(
                    \\Got subsong_header token -
                    \\  subsong_header_size_bytes: {}
                    \\  subsong_headers_size_bytes: {}
                    \\  subsongs count now: {}
                    \\  header data:
                    \\    has_flags: {}
                    \\    sample_rate_type: {} ({}hz)
                    \\    channel_count_type: {} ({} channels)
                    \\    sample_data_offset: {} bytes
                    \\    sample_count: {} samples
                ,
                    .{
                        subsong_header_size_bytes,
                        subsong_headers_size_bytes,
                        subsong_headers.items.len,
                        // data
                        subsong_header.has_flags,
                        @intFromEnum(subsong_header.sample_rate_type),
                        subsong_header.sample_rate_type.getFrequency(),
                        @intFromEnum(subsong_header.channel_count_type),
                        subsong_header.channel_count_type.getChannelCount(),
                        subsong_header.sample_data_offset,
                        subsong_header.sample_count,
                    },
                );

                temp_delete_this += 1; // TODO: DELETE THIS
                if (temp_delete_this >= max_songs_to_encode) last_flags = true; // TODO: DELETE THIS
            },

            .subsong_flag => |subsong_flag| {
                if (!last_flags and temp_delete_this >= max_songs_to_encode) continue; // TODO: DELETE THIS

                var subsong_flags = &flags_per_subsong.items[flags_per_subsong.items.len - 1];
                try subsong_flags.append(subsong_flag);

                const subsong_flag_header_size_bytes = subsong_flag.getFlagHeaderFileSizeBytes();
                var subsong_flag_data_size_bytes: usize = 0;
                var will_write_flag = false;

                switch (subsong_flag.data) {
                    .loop_info => |loop_info| {
                        subsong_flag_data_size_bytes = loop_info.getFileSizeBytes();
                        will_write_flag = true;
                    },
                    .unknown_5, .channel_override => {
                        subsong_flag_data_size_bytes = subsong_flag.flag_data_size;
                        will_write_flag = true;
                    },
                    .atrac9_config => {},
                    // TODO: Need to deal with other types?
                    else => |tag| {
                        std.log.err("Unhandled subsong flag type: {s}", .{@tagName(tag)});
                        unreachable;
                    },
                }

                if (will_write_flag) {
                    subsong_headers_size_bytes += subsong_flag_header_size_bytes + subsong_flag_data_size_bytes;
                }

                std.log.debug(
                    \\Got subsong_flag token - {s}
                    \\  will_write_flag: {}
                    \\  subsong_flag_header_size_bytes: {}
                    \\  subsong_flag_data_size_bytes: {}
                    \\  subsong headers total now: {}
                    \\  subsongs count now: {}
                ,
                    .{
                        @tagName(std.meta.activeTag(subsong_flag.data)),
                        will_write_flag,
                        subsong_flag_header_size_bytes,
                        subsong_flag_data_size_bytes,
                        subsong_headers_size_bytes,
                        subsong_headers.items.len,
                    },
                );
            },

            .subsong_name => |subsong_name| {
                if (!hit_names) { // TODO: DELETE THIS
                    temp_delete_this = 0;
                    hit_names = true;
                }
                if (temp_delete_this >= max_songs_to_encode) continue;

                try subsong_names.append(subsong_name);

                const subsong_name_offset_size_bytes = @sizeOf(u32);
                const subsong_name_string_size_bytes = subsong_name.len + 1;
                subsong_name_table_size_bytes += subsong_name_offset_size_bytes + subsong_name_string_size_bytes;

                std.log.debug(
                    \\Got subsong_name token - {s}
                    \\  subsong_name_offset_size_bytes: {}
                    \\  subsong_name_string_size_bytes: {}
                    \\  subsong name table size total now: {}
                    \\  subsongs name count now: {}
                ,
                    .{
                        subsong_name,
                        subsong_name_offset_size_bytes,
                        subsong_name_string_size_bytes,
                        subsong_name_table_size_bytes,
                        subsong_names.items.len,
                    },
                );

                temp_delete_this += 1; // TODO: DELETE THIS
            },

            .subsong_sample_data => |*subsong_sample_data| {
                if (!hit_samples) { // TODO: DELETE THIS
                    temp_delete_this = 0;
                    hit_samples = true;
                }
                if (temp_delete_this >= max_songs_to_encode) continue; // TODO: DELETE THIS

                const current_subsong_index = mp3_sample_data_per_subsong.items.len;
                std.log.debug("Got subsong_sample_data token - for subsong {s}", .{subsong_names.items[current_subsong_index]});

                const atrac9_config = cfg: for (flags_per_subsong.items[current_subsong_index].items) |subsong_flag| {
                    if (subsong_flag.data == .atrac9_config) {
                        const standard_config = subsong_flag.data.atrac9_config.config.standard;
                        break :cfg standard_config;
                    }
                } else {
                    std.log.err("Input file does not have Atrac9 header for subsong {}", .{current_subsong_index});
                    return error.InputFileNoAtrac9ConfigFlagInSubsongHeader;
                };

                const channel_override = val: for (flags_per_subsong.items[current_subsong_index].items) |subsong_flag| {
                    if (subsong_flag.data == .channel_override) {
                        const channel_override = subsong_flag.data.channel_override.override_value;
                        break :val channel_override;
                    }
                } else null;

                std.log.debug("subsong_sample_data - Found atrac9 header subsong flag", .{});

                const atrac9_config_packed = @as(u32, @bitCast(atrac9_config));
                var decoder_handle = libatrac9.Handle{};
                try libatrac9.initDecoder(&decoder_handle, atrac9_config_packed);

                const codec_info = try libatrac9.getCodecInfo(&decoder_handle);

                const subsong_header = subsong_headers.items[current_subsong_index];
                const subsong_channel_count = subsong_header.channel_count_type.getChannelCount();

                if (subsong_header.channel_count_type != .one_channel and subsong_channel_count != codec_info.getChannels()) {
                    std.log.err("ATRAC9: channels in subsong header {} vs config {} don't match", .{ subsong_channel_count, codec_info.getChannels() });
                    return error.InputFileWrongChannelCountInSubsongSampleData;
                }

                std.log.debug("subsong_sample_data - atrac9 config loaded and validated - beginning atrac9 decode to pcm16", .{});

                // Comment from vgmstream source: "extra leeway as Atrac9Decode seems to overread ~2 bytes (doesn't affect decoding though)"
                const expected_superframe_data_size_bytes = codec_info.getSuperframeSize();
                const input_data_buffer = try allocator.alloc(u8, expected_superframe_data_size_bytes + 16);
                defer allocator.free(input_data_buffer);
                @memset(input_data_buffer, 0);

                const pcm_sample_buffer = try allocator.alloc(i16, codec_info.getChannels() * subsong_header.sample_count);
                defer allocator.free(pcm_sample_buffer);
                @memset(pcm_sample_buffer, 0);

                var sample_data_r = subsong_sample_data.data_reader;
                var sample_data_reader = sample_data_r.reader();
                var pcm_samples_decoded: usize = 0;

                while (pcm_samples_decoded < subsong_header.sample_count) {
                    var input_bytes_decoded: usize = 0;
                    const read_sample_data_size_bytes = try sample_data_reader.readAll(input_data_buffer[0..expected_superframe_data_size_bytes]);

                    std.log.debug("subsong_sample_data - read {} bytes of sample data", .{read_sample_data_size_bytes});

                    if (read_sample_data_size_bytes != expected_superframe_data_size_bytes) {
                        std.log.err("ATRAC9: Input file superframe contains too little sample data - Expected: {} bytes - Actual: {} bytes", .{ expected_superframe_data_size_bytes, read_sample_data_size_bytes });
                        return error.InputFileTooLittleSampleData;
                    }

                    for (0..codec_info.getFramesInSuperframe()) |_| {
                        const input_bytes_read = try libatrac9.decode(
                            &decoder_handle,
                            input_data_buffer[input_bytes_decoded..],
                            pcm_sample_buffer[pcm_samples_decoded * codec_info.getChannels() ..],
                        );

                        input_bytes_decoded += input_bytes_read;
                        pcm_samples_decoded += codec_info.getFrameSamples();
                    }
                }

                const discarded_data_size_bytes = try sample_data_reader.any().discard();

                std.log.debug("subsong_sample_data - finished reading all samples - discarded {} remaining bytes", .{discarded_data_size_bytes});

                // TODO: Stream decoding from atrac9 straight to mp3 encode, instead of to in-memory buffer for full subsong?
                const output_mp3_buffer_size_bytes: usize = @intFromFloat(@ceil(1.25 * @as(f64, @floatFromInt(pcm_samples_decoded)) * @as(f64, @floatFromInt(codec_info.getChannels())) + 7200.0));
                const output_mp3_sample_buffer = try allocator.alloc(u8, output_mp3_buffer_size_bytes);
                errdefer allocator.free(output_mp3_sample_buffer);
                @memset(output_mp3_sample_buffer, 0);

                std.log.debug("subsong_sample_data - output buffer created with {} bytes", .{output_mp3_buffer_size_bytes});

                const lame_global_state = try libmp3lame.init();
                defer libmp3lame.close(lame_global_state) catch |err| {
                    std.log.warn("Failed closing mp3 stream - Error: {}", .{err});
                };

                try libmp3lame.setBitRate(lame_global_state, 160); // TODO: Lookup from table? Pass on command line?
                const channel_count_to_tell_lame = if (codec_info.getChannels() > 2) 2 else codec_info.getChannels();
                try libmp3lame.setNumChannels(lame_global_state, channel_count_to_tell_lame);
                try libmp3lame.setNumSamples(lame_global_state, pcm_samples_decoded * 4); // TODO: Don't hard-code multiplier
                try libmp3lame.setInputSampleRate(lame_global_state, @intCast(subsong_header.sample_rate_type.getFrequency() * 2)); // TODO: Is a multiplier right? Don't hard-code it either way
                try libmp3lame.setOutputSampleRate(lame_global_state, @intCast(subsong_header.sample_rate_type.getFrequency()));
                try libmp3lame.setWriteId3tagAutomatic(lame_global_state, false);
                try libmp3lame.setIsOriginal(lame_global_state, false);

                try libmp3lame.initParams(lame_global_state);

                std.log.debug("subsong_sample_data - mp3 encoder initialized - beginning mp3 encode from pcm16", .{});

                const channel_count = if (channel_override) |override| override else codec_info.getChannels();
                const output_mp3_samples_size_bytes = switch (channel_count) {
                    1 => try libmp3lame.encodeBuffer(lame_global_state, pcm_sample_buffer, pcm_sample_buffer, pcm_samples_decoded, output_mp3_sample_buffer),
                    2 => try libmp3lame.encodeBufferInterleaved(lame_global_state, pcm_sample_buffer, pcm_samples_decoded, output_mp3_sample_buffer),
                    4 => try libmp3lame.encodeBufferInterleaved(lame_global_state, pcm_sample_buffer, pcm_samples_decoded * 2, output_mp3_sample_buffer), // TODO: More globally handle smple doubling
                    else => {
                        std.log.err("ATRAC9: Handling for input file channel count not yet implemented: {}", .{channel_count});
                        return error.ChannelCountNotYetImplemented;
                    },
                };
                try mp3_sample_data_per_subsong.append(output_mp3_sample_buffer[0..output_mp3_samples_size_bytes]);

                subsong_sample_data_total_size_bytes += output_mp3_samples_size_bytes;

                std.log.debug(
                    \\subsong_sample_data - finished encoding all samples
                    \\  encoded {} bytes
                    \\  encoded sample data size total: {}
                    \\  encoded subsong count now: {}
                ,
                    .{
                        output_mp3_samples_size_bytes,
                        subsong_sample_data_total_size_bytes,
                        mp3_sample_data_per_subsong.items.len,
                    },
                );

                temp_delete_this += 1; // TODO: DELETE THIS
            },

            .end_of_tokens => {
                std.log.debug("Got end_of_tokens token", .{});
            },
        }
    }

    // calculate new file section sizes

    // padding to append to the end of the subsong name table, to make the sample data 32 byte aligned
    const subsong_name_table_padding_size_bytes: usize = getAlignmentPadding(base_header_size_bytes + subsong_headers_size_bytes + subsong_name_table_size_bytes, 32);
    subsong_name_table_size_bytes += subsong_name_table_padding_size_bytes;

    // new sample data size after encoding to mp3
    var subsong_sample_data_size_bytes: usize = 0;
    for (mp3_sample_data_per_subsong.items) |subsong_mp3_sample_data| {
        // padding to append to the end of each subsong sample data, to make the next sample data 32 byte aligned
        const subsong_sample_data_padding_size_bytes: usize = getAlignmentPadding(subsong_mp3_sample_data.len, 32);
        subsong_sample_data_size_bytes += subsong_mp3_sample_data.len + subsong_sample_data_padding_size_bytes;
    }

    std.log.debug(
        \\Calculated new sizes to write to base header
        \\  subsong_name_table_size_bytes: {}
        \\  subsong_sample_data_size_bytes: {}
    ,
        .{
            subsong_name_table_size_bytes,
            subsong_sample_data_size_bytes,
        },
    );

    // write out the file
    var counting_writer = std.io.countingWriter(output_writer);
    const writer = counting_writer.writer();

    // write base header
    try writer.writeAll(&base_header.magic_bytes);
    try writer.writeByte(@as(u8, @truncate(base_header.version_major)) + '0');
    try writer.writeInt(u32, base_header.version_minor, .little);
    try writer.writeInt(u32, @truncate(base_header.subsong_count), .little);
    try writer.writeInt(u32, @truncate(subsong_headers_size_bytes), .little);
    try writer.writeInt(u32, @truncate(subsong_name_table_size_bytes), .little);
    try writer.writeInt(u32, @truncate(subsong_sample_data_size_bytes), .little);
    try writer.writeInt(u32, @intFromEnum(fsb5.SampleDataCodecType.mpeg), .little);
    try writer.writeInt(u32, base_header.flags, .little);

    std.log.debug("Wrote output file base header. New total: {} bytes", .{counting_writer.bytes_written});

    // write base header suffix
    if (base_header.version_minor == 1) {
        try writer.writeInt(u32, 0, .little); // _unknown: u32
    }

    try writer.writeInt(u128, base_header.primary_hash, .little);
    try writer.writeInt(u64, base_header.secondary_hash, .little);

    std.log.debug("Wrote output file base header v{} suffix. New total: {} bytes", .{ base_header.version_minor, counting_writer.bytes_written });

    const actual_base_header_size_bytes = counting_writer.bytes_written;
    std.log.debug("actual_base_header_size_bytes: {}", .{actual_base_header_size_bytes});

    temp_delete_this = 0; // TODO: DELETE THIS

    // write subsong metadata
    var current_subsong_sample_data_offset_bytes: usize = 0;
    for (
        subsong_headers.items,
        mp3_sample_data_per_subsong.items,
        flags_per_subsong.items,
        0..,
    ) |
        subsong_header,
        subsong_mp3_sample_data,
        *subsong_flags,
        subsong_index,
    | {
        if (temp_delete_this >= max_songs_to_encode) continue; // TODO: DELETE THIS

        const sample_multiplier: usize = val: for (subsong_flags.items) |subsong_flag| {
            if (subsong_flag.data == .channel_override) {
                break :val switch (subsong_flag.data.channel_override.override_value) {
                    4 => 2,
                    else => @panic("Unimplemented channel override count"),
                };
            }
        } else 1;

        const subsong_header_data = @as(u64, subsong_header.sample_count * sample_multiplier) << 34 |
            @as(u64, current_subsong_sample_data_offset_bytes) << 7 |
            @as(u64, @intFromEnum(subsong_header.channel_count_type)) << 5 |
            @as(u64, @intFromEnum(subsong_header.sample_rate_type)) << 1 |
            @intFromBool(subsong_header.has_flags) << 0;

        try writer.writeInt(u64, subsong_header_data, .little);

        std.log.debug("Wrote output file subsong {} header. New total: {} bytes", .{ subsong_index, counting_writer.bytes_written });

        // remove any flags we don't want to write
        var current_index: isize = @as(isize, @intCast(subsong_flags.items.len)) - 1;
        while (current_index >= 0) : (current_index -= 1) {
            const index = @as(usize, @intCast(current_index));

            switch (subsong_flags.items[index].data) {
                .loop_info, .unknown_5, .channel_override => {
                    // Leave them in place
                },
                .atrac9_config => {
                    // Remove them
                    _ = subsong_flags.swapRemove(index);
                },
                // TODO: Need to deal with other types?
                else => |tag| {
                    std.log.err("Unhandled subsong flag type: {s}", .{@tagName(tag)});
                    unreachable;
                },
            }
        }

        // write flags for subsong header
        for (subsong_flags.items, 0..) |subsong_flag, subsong_flag_index| {
            // write the subsong flag header
            const has_more_flags = subsong_flag_index < subsong_flags.items.len - 1; // This may have changed after removing flags above
            const subsong_flag_header_data = @as(u32, @intFromEnum(std.meta.activeTag(subsong_flag.data))) << 25 |
                @as(u32, @truncate(subsong_flag.flag_data_size)) << 1 |
                @as(u32, @intFromBool(has_more_flags)) << 0;

            try writer.writeInt(u32, subsong_flag_header_data, .little);

            std.log.debug("Wrote output file subsong {} flag {} header. New total: {} bytes", .{ subsong_index, subsong_flag_index, counting_writer.bytes_written });

            // write the subsong flag data
            var wrote_data = false;
            switch (subsong_flag.data) {
                .loop_info => |loop_info| {
                    try writer.writeInt(u32, @truncate(loop_info.loop_start_sample * sample_multiplier), .little);
                    try writer.writeInt(u32, @truncate(loop_info.loop_end_sample * sample_multiplier), .little);
                    wrote_data = true;
                },
                .unknown_5 => |uk5| {
                    switch (subsong_flag.flag_data_size) {
                        4...256 => {
                            // TODO: Actually decode it?
                            const blah_value = @as([*]const u8, @ptrCast(&uk5))[0..subsong_flag.flag_data_size];
                            try writer.writeAll(blah_value);
                        },
                        else => {
                            std.log.err("Unhandled size ({} bytes) of unknown_5 subsong flag. subsong_index: {} - subsong_flag_index: {}", .{
                                subsong_flag.flag_data_size,
                                subsong_index,
                                subsong_flag_index,
                            });
                            unreachable;
                        },
                    }

                    for (0..subsong_flag.flag_data_size) |_| {}
                    wrote_data = true;
                },
                .channel_override => |chan_over| {
                    try writer.writeByte(chan_over.override_value);
                    wrote_data = true;
                },
                else => unreachable, // TODO: Need to deal with other types?
            }

            if (wrote_data) {
                std.log.debug("Wrote output file subsong {} flag {} data. New total: {} bytes", .{ subsong_index, subsong_flag_index, counting_writer.bytes_written });
            }
        }

        const subsong_sample_data_padding_size_bytes: usize = getAlignmentPadding(subsong_mp3_sample_data.len, 32);
        current_subsong_sample_data_offset_bytes += (subsong_mp3_sample_data.len + subsong_sample_data_padding_size_bytes) / 32;

        temp_delete_this += 1; // TODO: DELETE THIS
    }

    const actual_subsong_headers_size_bytes = counting_writer.bytes_written - actual_base_header_size_bytes;
    std.log.debug("actual_subsong_headers_size_bytes: {}", .{actual_subsong_headers_size_bytes});

    temp_delete_this = 0; // TODO: DELETE THIS

    // write subsong name offsets
    var current_subsong_name_offset_bytes: usize = 4 * subsong_names.items.len;
    for (subsong_names.items, 0..) |subsong_name, subsong_name_index| {
        if (temp_delete_this >= max_songs_to_encode) continue; // TODO: DELETE THIS
        try writer.writeInt(u32, @truncate(current_subsong_name_offset_bytes), .little);
        current_subsong_name_offset_bytes += subsong_name.len + 1;
        std.log.debug("Wrote output file subsong name offset {}. New total: {} bytes", .{ subsong_name_index, counting_writer.bytes_written });
        temp_delete_this += 1; // TODO: DELETE THIS
    }

    temp_delete_this = 0; // TODO: DELETE THIS

    // write subsong names
    for (subsong_names.items, 0..) |subsong_name, subsong_name_index| {
        if (temp_delete_this >= max_songs_to_encode) continue; // TODO: DELETE THIS
        try writer.writeAll(subsong_name);
        try writer.writeByte(0);
        std.log.debug("Wrote output file subsong name {}. New total: {} bytes", .{ subsong_name_index, counting_writer.bytes_written });
        temp_delete_this += 1; // TODO: DELETE THIS
    }

    // write subsong name table padding - round the file up to 32 byte alignment
    try writer.writeByteNTimes(0, subsong_name_table_padding_size_bytes);

    std.log.debug("Wrote output file subsong name table padding. New total: {} bytes", .{counting_writer.bytes_written});

    const actual_subsong_name_table_size_bytes = counting_writer.bytes_written - actual_subsong_headers_size_bytes - actual_base_header_size_bytes;
    std.log.debug("actual_subsong_name_table_size_bytes: {}", .{actual_subsong_name_table_size_bytes});

    temp_delete_this = 0; // TODO: DELETE THIS

    // write converted subsong sample data in new codec (mp3)
    for (mp3_sample_data_per_subsong.items, 0..) |subsong_mp3_sample_data, subsong_sample_data_index| {
        if (temp_delete_this >= max_songs_to_encode) continue; // TODO: DELETE THIS

        try writer.writeAll(subsong_mp3_sample_data);
        std.log.debug("Wrote output file subsong sample data {}. New total: {} bytes", .{ subsong_sample_data_index, counting_writer.bytes_written });

        // write subsong sample data padding - round the file up to 32 byte alignment
        const subsong_sample_data_padding_size_bytes: usize = getAlignmentPadding(subsong_mp3_sample_data.len, 32);
        try writer.writeByteNTimes(0, subsong_sample_data_padding_size_bytes);
        std.log.debug("Wrote output file subsong sample data padding. New total: {} bytes", .{counting_writer.bytes_written});

        temp_delete_this += 1; // TODO: DELETE THIS
    }

    const actual_subsong_sample_data_size_bytes = counting_writer.bytes_written - actual_subsong_name_table_size_bytes - actual_subsong_headers_size_bytes - actual_base_header_size_bytes;
    std.log.debug("actual_subsong_sample_data_size_bytes: {}", .{actual_subsong_sample_data_size_bytes});
}

fn getAlignmentPadding(value: usize, comptime alignment: usize) usize {
    const rem = alignment - @rem(value, alignment);
    const result = if (rem == alignment) 0 else rem;
    return result;
}
