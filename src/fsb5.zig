const builtin = @import("builtin");
const std = @import("std");

pub const ParseError = error{
    InputFileWrongMagicBytes,
    InputFileWrongFsbVersionMajor,
    InputFileWrongFsbVersionMinor,
    InputFileWrongSubsongFlagDataSize,
    InputFileWrongSubsongNameTableExtraDataSize,
    InputFileHadBytesRemaining,
};

pub const File = struct {
    pub fn read(reader: std.io.AnyReader, allocator: std.mem.Allocator) TokenIterator {
        const result = TokenIterator.init(reader, allocator);
        return result;
    }
};

pub const TokenIterator = struct {
    inner_iterator: FileIterator,

    fn init(reader: std.io.AnyReader, allocator: std.mem.Allocator) TokenIterator {
        const result = TokenIterator{
            .inner_iterator = FileIterator.init(reader, allocator),
        };
        return result;
    }

    pub fn free(self: TokenIterator) void {
        self.inner_iterator.free();
    }

    pub fn next(self: *TokenIterator) !?Token {
        var done = false;
        var result: ?Token = null;
        var current_base_header: ?BaseHeader = null;

        while (!done) {
            const file_token = try self.inner_iterator.next();
            if (file_token == null) {
                result = null;
                break;
            }

            switch (file_token.?) {
                .file_base_header => |base_header| {
                    current_base_header = BaseHeader{
                        .magic_bytes = @as(*const [3]u8, @ptrCast(&base_header.magic_bytes_chars)).*,
                        .version_major = try std.fmt.parseInt(u32, @as(*const [1]u8, &base_header.version_major_char), 10),
                        .version_minor = byteSwapIfNeeded(u32, base_header.version_minor, .little),
                        .subsong_count = byteSwapIfNeeded(u32, base_header.subsong_count, .little),
                        .subsong_sample_data_codec = @enumFromInt(byteSwapIfNeeded(u32, base_header.subsong_sample_data_codec, .little)),
                        .flags = byteSwapIfNeeded(u32, base_header.flags, .little),
                        .primary_hash = 0,
                        .secondary_hash = 0,
                    };
                    done = false;
                },

                .file_base_header_v0_suffix => |base_header_v0_suffix| {
                    if (current_base_header) |*base_header| {
                        base_header.primary_hash = base_header_v0_suffix.primary_hash;
                        base_header.secondary_hash = base_header_v0_suffix.secondary_hash;
                        result = Token{
                            .base_header = base_header.*,
                        };
                        done = true;
                    } else {
                        unreachable;
                    }
                },

                .file_base_header_v1_suffix => |base_header_v1_suffix| {
                    if (current_base_header) |*base_header| {
                        base_header.primary_hash = base_header_v1_suffix.primary_hash;
                        base_header.secondary_hash = base_header_v1_suffix.secondary_hash;
                        result = Token{
                            .base_header = base_header.*,
                        };
                        done = true;
                    } else {
                        unreachable;
                    }
                },

                .file_subsong_header => |subsong_header| {
                    result = Token{
                        .subsong_header = SubsongHeader{
                            .has_flags = subsong_header.has_flags,
                            .sample_rate_type = @enumFromInt(@intFromEnum(subsong_header.sample_rate_type)),
                            .channel_count_type = @enumFromInt(@intFromEnum(subsong_header.channel_count_type)),
                            .sample_data_offset = byteSwapIfNeeded(u32, @as(u32, @intCast(subsong_header.sample_data_offset)) << 5, .little),
                            .sample_count = byteSwapIfNeeded(u32, @intCast(subsong_header.sample_count), .little),
                        },
                    };
                    done = true;
                },

                .file_subsong_flag => |subsong_flag| {
                    const flag_data_size = byteSwapIfNeeded(u32, @as(u32, subsong_flag.header.flag_data_size), .little);
                    result = Token{
                        .subsong_flag = SubsongFlag{
                            .has_more_flags = subsong_flag.header.has_more_flags,
                            .flag_data_size = flag_data_size,
                            .data = switch (subsong_flag.header.flag_type) {
                                // TODO: Populate these correctly?
                                .none => SubsongFlagData{ .none = void{} },
                                .channel_override => SubsongFlagData{
                                    .channel_override = .{ .override_value = subsong_flag.data.channel_override.override_value },
                                },
                                .sample_rate_override => SubsongFlagData{
                                    .sample_rate_override = .{ .blah = byteSwapIfNeeded(u32, subsong_flag.data.sample_rate_override.blah, .little) },
                                },
                                .loop_info => SubsongFlagData{
                                    .loop_info = .{
                                        .loop_start_sample = byteSwapIfNeeded(u32, subsong_flag.data.loop_info.loop_start_sample, .little),
                                        .loop_end_sample = byteSwapIfNeeded(u32, subsong_flag.data.loop_info.loop_end_sample, .little),
                                    },
                                },
                                .free_comment_or_sfx_info => SubsongFlagData{ .free_comment_or_sfx_info = void{} },
                                .unknown_5 => SubsongFlagData{
                                    .unknown_5 = switch (flag_data_size) {
                                        4...256 => .{
                                            .blah = subsong_flag.data.unknown_5.blah,
                                        },
                                        else => {
                                            // TODO: Keep track of current flag index etc so we can log it?
                                            std.log.err("Unhandled size ({} bytes) of unknown_5 subsong flag", .{flag_data_size});
                                            unreachable;
                                        },
                                    },
                                },
                                .xma_seek_table => SubsongFlagData{ .xma_seek_table = void{} },
                                .dsp_coefficients => SubsongFlagData{ .dsp_coefficients = void{} },
                                .atrac9_config => SubsongFlagData{
                                    .atrac9_config = switch (subsong_flag.data.atrac9_config.magic_byte_char) {
                                        0xFE => .{
                                            .frame_size_bytes = 0,
                                            .config = @bitCast(byteSwapIfNeeded(u32, @bitCast(subsong_flag.data.atrac9_config.without_frame_size), .little)),
                                        },
                                        else => .{
                                            .frame_size_bytes = byteSwapIfNeeded(u32, subsong_flag.data.atrac9_config.with_frame_size.frame_size_bytes, .little),
                                            .config = @bitCast(byteSwapIfNeeded(u32, @bitCast(subsong_flag.data.atrac9_config.with_frame_size.config), .little)),
                                        },
                                    },
                                },
                                .xwma_config => SubsongFlagData{ .xwma_config = void{} },
                                .vorbis_setup_id_and_seek_table => SubsongFlagData{ .vorbis_setup_id_and_seek_table = void{} },
                                .peak_volume => SubsongFlagData{
                                    .peak_volume = .{ .value = @bitCast(byteSwapIfNeeded(u32, @bitCast(subsong_flag.data.peak_volume.value), .little)) },
                                },
                                .vorbis_intra_layers => SubsongFlagData{
                                    .vorbis_intra_layers = .{ .blah = byteSwapIfNeeded(u32, subsong_flag.data.vorbis_intra_layers.blah, .little) },
                                },
                                .opus_data_size_ignoring_frame_headers => SubsongFlagData{ .opus_data_size_ignoring_frame_headers = void{} },
                            },
                        },
                    };
                    done = true;
                },

                .file_subsong_name_start_offset => {
                    // Nothing to do here
                    done = false;
                },

                .file_subsong_name => |subsong_name| {
                    result = Token{ .subsong_name = subsong_name };
                    done = true;
                },

                .file_subsong_name_table_unused_data => |*subsong_name_table_unused_data| {
                    var data_reader = subsong_name_table_unused_data.data_reader;
                    var reader = data_reader.reader();
                    const extra_bytes_read = try reader.any().discard();

                    if (subsong_name_table_unused_data.data_size_bytes != extra_bytes_read) {
                        return error.InputFileWrongSubsongNameTableExtraDataSize;
                    }

                    done = false;
                },

                .file_subsong_sample_data => |subsong_sample_data| {
                    result = Token{
                        .subsong_sample_data = .{
                            .data_size_bytes = subsong_sample_data.data_size_bytes,
                            .data_reader = subsong_sample_data.data_reader,
                        },
                    };
                    done = true;
                },

                .end_of_file => {
                    result = Token{ .end_of_tokens = void{} };
                    done = true;
                },
            }
        }

        return result;
    }
};

pub const TokenType = enum {
    base_header,
    subsong_header,
    subsong_flag,
    subsong_name,
    subsong_sample_data,
    end_of_tokens,
};

pub const Token = union(TokenType) {
    base_header: BaseHeader,
    subsong_header: SubsongHeader,
    subsong_flag: SubsongFlag,
    subsong_name: [:0]const u8,
    subsong_sample_data: struct {
        data_size_bytes: usize,
        data_reader: std.io.LimitedReader(std.io.AnyReader),
    },
    end_of_tokens: void,
};

pub const BaseHeader = struct {
    magic_bytes: [3]u8,
    version_major: u32,
    version_minor: u32,
    subsong_count: usize,
    subsong_sample_data_codec: SampleDataCodecType,
    flags: u32,
    primary_hash: u128, // TODO: Proper name? What is the hash type?
    secondary_hash: u64, // TODO: Proper name? What is the hash type?

    pub fn getFileSizeBytes(self: BaseHeader) usize {
        const result: usize = @divExact(@bitSizeOf(FileBaseHeader), 8) + @as(
            usize,
            switch (self.version_minor) {
                0 => @divExact(@bitSizeOf(FileBaseHeaderV0Suffix), 8),
                1 => @divExact(@bitSizeOf(FileBaseHeaderV1Suffix), 8),
                else => unreachable,
            },
        );
        return result;
    }
};

pub const SampleDataCodecType = enum(u32) {
    none = 0,
    pcm8 = 1,
    pcm16 = 2,
    pcm24 = 3,
    pcm32 = 4,
    pcm_float_32 = 5,
    gamecube_adpcm = 6,
    ima_adpcm = 7,
    vag = 8,
    hevag = 9,
    xma = 10,
    mpeg = 11,
    celt = 12,
    atrac9 = 13,
    xwma = 14,
    vorbis = 15,
    fad_pcm = 16,
    opus = 17,

    pub fn getDisplayString(self: SampleDataCodecType) []const u8 {
        const result = switch (self) {
            .none => "None",
            .pcm8 => "Pcm8",
            .pcm16 => "Pcm16",
            .pcm24 => "Pcm24",
            .pcm32 => "Pcm32",
            .pcm_float_32 => "PcmFloat32",
            .gamecube_adpcm => "GamecubeADPCM",
            .ima_adpcm => "ImaADPCM",
            .vag => "Vag",
            .hevag => "Hevag",
            .xma => "Xma",
            .mpeg => "Mpeg",
            .celt => "Celt",
            .atrac9 => "Atrac9",
            .xwma => "XWma",
            .vorbis => "Vorbis",
            .fad_pcm => "FadPCM",
            .opus => "Opus",
        };
        return result;
    }
};

pub const SubsongHeader = struct {
    has_flags: bool,
    sample_rate_type: SubsongSampleRateType,
    channel_count_type: SubsongChannelCountType,
    sample_data_offset: usize,
    sample_count: usize,

    pub fn getFileSizeBytes(_: SubsongHeader) usize {
        const result = @divExact(@bitSizeOf(FileSubsongHeader), 8);
        return result;
    }
};

pub const SubsongSampleRateType = enum(u32) {
    sample_rate_4000_hz = 0,
    sample_rate_8000_hz = 1,
    sample_rate_11000_hz = 2,
    sample_rate_11025_hz = 3,
    sample_rate_16000_hz = 4,
    sample_rate_22050_hz = 5,
    sample_rate_24000_hz = 6,
    sample_rate_32000_hz = 7,
    sample_rate_44100_hz = 8,
    sample_rate_48000_hz = 9,
    sample_rate_96000_hz = 10,
    // Note: FMOD rejects values of 11 or above

    pub fn getFrequency(self: SubsongSampleRateType) u32 {
        const result: u32 = switch (self) {
            .sample_rate_4000_hz => 4000,
            .sample_rate_8000_hz => 8000,
            .sample_rate_11000_hz => 11000,
            .sample_rate_11025_hz => 11025,
            .sample_rate_16000_hz => 16000,
            .sample_rate_22050_hz => 22050,
            .sample_rate_24000_hz => 24000,
            .sample_rate_32000_hz => 32000,
            .sample_rate_44100_hz => 44100,
            .sample_rate_48000_hz => 48000,
            .sample_rate_96000_hz => 96000,
        };
        return result;
    }
};

pub const SubsongChannelCountType = enum(u32) {
    one_channel = 0,
    two_channels = 1,
    six_channels = 2,
    eight_channels = 3,

    pub fn getChannelCount(self: SubsongChannelCountType) usize {
        const result: usize = switch (self) {
            .one_channel => 1,
            .two_channels => 2,
            .six_channels => 6,
            .eight_channels => 8,
        };
        return result;
    }
};

pub const SubsongFlag = struct {
    has_more_flags: bool,
    flag_data_size: usize,
    data: SubsongFlagData,

    pub fn getFlagHeaderFileSizeBytes(_: SubsongFlag) usize {
        const result = @divExact(@bitSizeOf(FileSubsongFlagHeader), 8);
        return result;
    }
};

pub const SubsongFlagData = union(enum) {
    none: void,
    channel_override: struct {
        override_value: u8,
    },
    sample_rate_override: struct {
        blah: u32, // TODO: Right name
    },
    loop_info: struct {
        loop_start_sample: usize,
        loop_end_sample: usize,

        pub fn getFileSizeBytes(_: @This()) usize {
            const result = @divExact(@bitSizeOf(std.meta.TagPayload(FileSubsongFlagData, .loop_info)), 8);
            return result;
        }
    },
    free_comment_or_sfx_info: void, // TODO: Right data
    unknown_5: struct {
        // TODO: Right name? Right size? Actually tease apart what this flag is and what it serializes too?
        //       It seems right now it can be at least 68 bytes
        blah: u2048,
    },
    xma_seek_table: void, // TODO: Right data
    dsp_coefficients: void, // TODO: Right data
    atrac9_config: struct {
        frame_size_bytes: usize,
        config: Atrac9Config,
    },
    xwma_config: void, // TODO: Right data
    vorbis_setup_id_and_seek_table: void, // TODO: Right data
    peak_volume: struct {
        value: f32, // TODO: Is this right?
    },
    vorbis_intra_layers: struct {
        blah: u32, // TODO: Right name
    },
    opus_data_size_ignoring_frame_headers: void, // TODO: Right data
};

pub const Atrac9Config = packed union {
    standard: Atrac9StandardConfig,
    layered: Atrac9LayeredConfig,
};

pub const Atrac9StandardConfig = packed struct(u32) {
    magic_byte_char: u8,
    sample_rate_index: u4,
    channel_config_index: u3,
    validation_bit: u1,
    frame_size_bytes: u11,
    superframe_index: u2,
    _unused: u3,
};

pub const Atrac9LayeredConfig = packed struct {
    // TODO: ?
};

const FileIterator = struct {
    reader: std.io.AnyReader,
    allocator: std.mem.Allocator,
    current_expected_token: ?FileTokenType,
    expected_subsong_count: usize,
    subsong_name_start_offsets: ?[]usize, // Used to know size of buffer to allocate
    subsong_names: ?[]?std.ArrayList(u8), // List of buffers to read subsong names into and return to caller
    subsong_sample_data_start_offsets: ?[]usize, // Used to know size of limited reader
    subsong_name_table_size: usize,
    subsong_sample_data_size: usize,
    subsong_name_table_unused_data_size_bytes: usize,
    // TODO: Can we just combine these and reset to 0 before entering each applicable token section?
    current_subsong_header_index: usize,
    current_subsong_name_start_offset_index: usize,
    current_subsong_name_index: usize,
    current_subsong_sample_data_index: usize,

    fn init(reader: std.io.AnyReader, allocator: std.mem.Allocator) FileIterator {
        const result = FileIterator{
            .reader = reader,
            .allocator = allocator,
            .current_expected_token = .file_base_header,
            .expected_subsong_count = 0,
            .subsong_name_start_offsets = null,
            .subsong_names = null,
            .subsong_sample_data_start_offsets = null,
            .subsong_name_table_size = 0,
            .subsong_sample_data_size = 0,
            .subsong_name_table_unused_data_size_bytes = 0,
            .current_subsong_header_index = 0,
            .current_subsong_name_start_offset_index = 0,
            .current_subsong_name_index = 0,
            .current_subsong_sample_data_index = 0,
        };
        return result;
    }

    fn free(self: FileIterator) void {
        if (self.subsong_name_start_offsets) |subsong_name_start_offsets| {
            self.allocator.free(subsong_name_start_offsets);
        }

        if (self.subsong_names) |subsong_names| {
            for (subsong_names) |*subsong_name| {
                if (subsong_name.*) |*name| {
                    name.clearAndFree();
                }
            }
            self.allocator.free(subsong_names);
        }

        if (self.subsong_sample_data_start_offsets) |subsong_sample_data_start_offsets| {
            self.allocator.free(subsong_sample_data_start_offsets);
        }
    }

    fn next(self: *FileIterator) !?FileToken {
        if (self.current_expected_token == null) {
            return null;
        }

        const result = val: {
            switch (self.current_expected_token.?) {
                .file_base_header => {
                    const value = try self.reader.readStruct(FileBaseHeader);

                    const expected_magic_bytes_chars = "FSB";
                    const actual_magic_bytes_chars = @as(*const [3]u8, @ptrCast(&value.magic_bytes_chars));
                    if (!std.mem.eql(u8, actual_magic_bytes_chars, expected_magic_bytes_chars)) {
                        std.log.err("File had wrong magic bytes: {s} (expected FSB)\n", .{actual_magic_bytes_chars});
                        return error.InputFileWrongMagicBytes;
                    }

                    if (value.version_major_char != '5') {
                        std.log.err("File had wrong major version: {s} (expected 5)\n", .{@as(*const [1]u8, @ptrCast(&value.version_major_char))});
                        return error.InputFileWrongFsbVersionMajor;
                    }

                    self.expected_subsong_count = byteSwapIfNeeded(u32, value.subsong_count, .little);

                    self.subsong_name_start_offsets = try self.allocator.alloc(usize, self.expected_subsong_count);
                    @memset(self.subsong_name_start_offsets.?, 0);

                    self.subsong_names = try self.allocator.alloc(?std.ArrayList(u8), self.expected_subsong_count);
                    @memset(self.subsong_names.?, null);

                    self.subsong_sample_data_start_offsets = try self.allocator.alloc(usize, self.expected_subsong_count);
                    @memset(self.subsong_sample_data_start_offsets.?, 0);

                    self.subsong_name_table_size = value.subsong_name_table_size;
                    self.subsong_sample_data_size = value.subsong_sample_data_size;

                    const version_minor = byteSwapIfNeeded(u32, value.version_minor, .little);
                    self.current_expected_token = switch (version_minor) {
                        0 => .file_base_header_v0_suffix,
                        1 => .file_base_header_v1_suffix,
                        else => {
                            std.log.err("File had wrong minor version: {} (expected 0 or 1)\n", .{version_minor});
                            return error.InputFileWrongFsbVersionMinor;
                        },
                    };

                    break :val FileToken{ .file_base_header = value };
                },

                .file_base_header_v0_suffix => {
                    const value = try readStructPacked(self.reader, FileBaseHeaderV0Suffix);
                    self.current_expected_token = if (self.expected_subsong_count > 0) .file_subsong_header else .end_of_file;
                    break :val FileToken{ .file_base_header_v0_suffix = value };
                },

                .file_base_header_v1_suffix => {
                    const value = try readStructPacked(self.reader, FileBaseHeaderV1Suffix);
                    self.current_expected_token = if (self.expected_subsong_count > 0) .file_subsong_header else .end_of_file;
                    break :val FileToken{ .file_base_header_v1_suffix = value };
                },

                .file_subsong_header => {
                    const value = try readStructPacked(self.reader, FileSubsongHeader);

                    // TODO: Specifically handle value.sample_rate_type of 11 or greater with an error, unless Zig is going to error before we get a chance

                    if (self.subsong_sample_data_start_offsets) |subsong_sample_data_start_offsets| {
                        subsong_sample_data_start_offsets[self.current_subsong_header_index] = @as(usize, @intCast(byteSwapIfNeeded(u32, value.sample_data_offset, .little))) << 5;
                    } else {
                        unreachable;
                    }

                    if (value.has_flags) {
                        self.current_expected_token = .file_subsong_flag;
                    } else {
                        try self.completeSubsongHeader();
                    }

                    break :val FileToken{ .file_subsong_header = value };
                },

                .file_subsong_flag => {
                    const header_value = try self.reader.readStruct(FileSubsongFlagHeader);

                    if (header_value.flag_type.getExpectedDataSize()) |expected_data_size| {
                        if (header_value.flag_data_size != expected_data_size) {
                            std.log.err("Subsong flag of type {s} had wrong flag data size - Expected: {} bytes - Actual: {} bytes\n", .{ @tagName(header_value.flag_type), expected_data_size, header_value.flag_data_size });
                            return error.InputFileWrongSubsongFlagDataSize;
                        }
                    }

                    const data_value = switch (header_value.flag_type) {
                        .atrac9_config => a9val: {
                            const buffer_max_size = @divExact(
                                @bitSizeOf(std.meta.FieldType(
                                    std.meta.TagPayload(FileSubsongFlagData, .atrac9_config),
                                    .with_frame_size,
                                )),
                                8,
                            );
                            var buffer: [buffer_max_size]u8 = undefined;

                            try self.reader.readNoEof(buffer[0..header_value.flag_data_size]);

                            const result = FileSubsongFlagData{
                                .atrac9_config = if (buffer[0] == 0xFE) .{
                                    .without_frame_size = .{
                                        .standard = @as(*align(1) const Atrac9StandardConfig, @ptrCast(&buffer[0])).*,
                                    },
                                } else .{
                                    .with_frame_size = .{
                                        // TODO: Is it possible to do the whole thing at once?
                                        .frame_size_bytes = @as(*align(1) const u32, @ptrCast(&buffer[0])).*,
                                        .config = .{
                                            .standard = @as(*align(1) const Atrac9StandardConfig, @ptrCast(&buffer[4])).*,
                                        },
                                    },
                                },
                            };
                            break :a9val result;
                        },

                        .unknown_5 => uk5val: {
                            // TODO: Yeah, this is HIGHLY variable width. I'm getting 28 on track 1 of sprj_pscom.
                            //       Can either try to decode it (ugh), or we can just let it be variable, trust the flag data size, and just load that in and copy it over
                            var data_buffer = std.mem.zeroes([@divExact(@bitSizeOf(std.meta.TagPayload(FileSubsongFlagData, .unknown_5)), 8)]u8);
                            const flag_data_size = header_value.flag_data_size;
                            std.debug.assert(data_buffer.len >= flag_data_size);
                            try self.reader.readNoEof(data_buffer[0..flag_data_size]);
                            break :uk5val FileSubsongFlagData{
                                .unknown_5 = @bitCast(data_buffer),
                            };
                        },

                        inline else => |tag| try readUnion(self.reader, FileSubsongFlagData, tag),
                    };

                    if (header_value.has_more_flags) {
                        // The current expected token will already be set to this. Just here for clarity
                        self.current_expected_token = .file_subsong_flag;
                    } else {
                        try self.completeSubsongHeader();
                    }

                    const value = FileToken{
                        .file_subsong_flag = FileSubsongFlag{
                            .header = header_value,
                            .data = data_value,
                        },
                    };
                    break :val value;
                },

                .file_subsong_name_start_offset => {
                    const value_bytes = try self.reader.readBytesNoEof(@sizeOf(u32));
                    const value = @as(*align(1) const u32, @ptrCast(&value_bytes[0])).*;

                    if (self.subsong_name_start_offsets) |subsong_name_start_offsets| {
                        const offset_value: usize = @intCast(byteSwapIfNeeded(u32, value, .little));
                        subsong_name_start_offsets[self.current_subsong_name_start_offset_index] = offset_value;
                    } else {
                        unreachable;
                    }

                    self.current_subsong_name_start_offset_index += 1;

                    if (self.current_subsong_name_start_offset_index >= self.expected_subsong_count) {
                        self.current_expected_token = .file_subsong_name;
                    }

                    break :val FileToken{ .file_subsong_name_start_offset = value };
                },

                .file_subsong_name => {
                    const next_offset = if (self.current_subsong_name_index < self.expected_subsong_count - 1)
                        self.subsong_name_start_offsets.?[self.current_subsong_name_index + 1]
                    else
                        self.subsong_name_table_size;
                    const current_offset = self.subsong_name_start_offsets.?[self.current_subsong_name_index];
                    const data_size_bytes = next_offset - current_offset;

                    var song_name_data = std.ArrayList(u8).init(self.allocator);
                    errdefer song_name_data.clearAndFree();

                    var song_name_table_reader = std.io.limitedReader(self.reader, data_size_bytes);
                    try song_name_table_reader.reader().streamUntilDelimiter(song_name_data.writer(), 0, null);
                    self.subsong_names.?[self.current_subsong_name_index] = song_name_data;
                    const subsong_name: [:0]const u8 = @ptrCast(std.mem.sliceTo(song_name_data.items, 0));

                    self.current_subsong_name_index += 1;

                    if (self.current_subsong_name_index >= self.expected_subsong_count) {
                        if (subsong_name.len + 1 < data_size_bytes) {
                            self.subsong_name_table_unused_data_size_bytes = data_size_bytes - (subsong_name.len + 1);
                            self.current_expected_token = .file_subsong_name_table_unused_data;
                        } else {
                            self.current_expected_token = .file_subsong_sample_data;
                        }
                    }

                    break :val FileToken{ .file_subsong_name = subsong_name };
                },

                .file_subsong_name_table_unused_data => {
                    const song_name_table_reader = std.io.limitedReader(self.reader, self.subsong_name_table_unused_data_size_bytes);

                    self.current_expected_token = .file_subsong_sample_data;

                    break :val FileToken{
                        .file_subsong_name_table_unused_data = .{
                            .data_size_bytes = self.subsong_name_table_unused_data_size_bytes,
                            .data_reader = song_name_table_reader,
                        },
                    };
                },

                .file_subsong_sample_data => {
                    const next_offset = if (self.current_subsong_sample_data_index < self.expected_subsong_count - 1)
                        self.subsong_sample_data_start_offsets.?[self.current_subsong_sample_data_index + 1]
                    else
                        self.subsong_sample_data_size;
                    const current_offset = self.subsong_sample_data_start_offsets.?[self.current_subsong_sample_data_index];
                    const data_size_bytes = next_offset - current_offset;

                    const limited_reader = std.io.limitedReader(self.reader, data_size_bytes);

                    self.current_subsong_sample_data_index += 1;

                    if (self.current_subsong_sample_data_index >= self.expected_subsong_count) {
                        self.current_expected_token = .end_of_file;
                    }

                    break :val FileToken{
                        .file_subsong_sample_data = .{
                            .data_size_bytes = data_size_bytes,
                            .data_reader = limited_reader,
                        },
                    };
                },

                .end_of_file => {
                    // TODO: Re-enable this assert
                    // const data_remaining_after_reading_last_sample_size_bytes = try self.reader.discard();

                    // if (data_remaining_after_reading_last_sample_size_bytes > 0) {
                    //     std.log.err("File had data remaining at end: {} bytes (expected 0)\n", .{data_remaining_after_reading_last_sample_size_bytes});
                    //     return error.InputFileHadBytesRemaining;
                    // }

                    self.current_expected_token = null;

                    break :val FileToken{ .end_of_file = void{} };
                },
            }
        };

        return result;
    }

    fn completeSubsongHeader(self: *FileIterator) !void {
        self.current_subsong_header_index += 1;

        if (self.current_subsong_header_index < self.expected_subsong_count) {
            self.current_expected_token = .file_subsong_header;
        } else {
            self.current_expected_token = .file_subsong_name_start_offset;
        }
    }
};

const FileTokenType = enum {
    file_base_header,
    file_base_header_v0_suffix,
    file_base_header_v1_suffix,
    file_subsong_header,
    file_subsong_flag,
    file_subsong_name_start_offset,
    file_subsong_name,
    file_subsong_name_table_unused_data,
    file_subsong_sample_data,
    end_of_file,
};

/// This union contains the actual bytes in the shape that they appear in the file, with as little processing as possible.
/// When structs have variable size, those may be returned partly unpacked, since the file format doesn't add padding after union-style structs.
/// Only sample data will return a reader instead of a copy of the data.
/// Multi-byte integers will be returned unprocessed, so will be in little endian like in the file, even if the system is big endian.
/// The string and multi-byte data in these tokens will be freed when FileIterator.free is called.
const FileToken = union(FileTokenType) {
    file_base_header: FileBaseHeader,
    file_base_header_v0_suffix: FileBaseHeaderV0Suffix,
    file_base_header_v1_suffix: FileBaseHeaderV1Suffix,
    file_subsong_header: FileSubsongHeader,
    file_subsong_flag: FileSubsongFlag,
    file_subsong_name_start_offset: u32,
    file_subsong_name: [:0]const u8,
    file_subsong_name_table_unused_data: struct {
        data_size_bytes: usize,
        data_reader: std.io.LimitedReader(std.io.AnyReader),
    },
    file_subsong_sample_data: struct {
        data_size_bytes: usize,
        data_reader: std.io.LimitedReader(std.io.AnyReader),
    },
    end_of_file: void,
};

const FileBaseHeader = packed struct(u256) {
    magic_bytes_chars: u24,
    version_major_char: u8,
    version_minor: u32,
    subsong_count: u32,
    subsong_header_size: u32,
    subsong_name_table_size: u32,
    subsong_sample_data_size: u32,
    subsong_sample_data_codec: u32,
    flags: u32,
};

const FileBaseHeaderV0Suffix = packed struct(u192) {
    primary_hash: u128, // TODO: Proper name? What is the hash type?
    secondary_hash: u64, // TODO: Proper name? What is the hash type?
};

const FileBaseHeaderV1Suffix = packed struct(u224) {
    _unknown: u32,
    primary_hash: u128, // TODO: Proper name? What is the hash type?
    secondary_hash: u64, // TODO: Proper name? What is the hash type?
};

const FileSubsongHeader = packed struct(u64) {
    has_flags: bool,
    sample_rate_type: FileSubsongSampleRateType,
    channel_count_type: FileSubsongChannelCountType,
    sample_data_offset: u27,
    sample_count: u30,
};

const FileSubsongSampleRateType = enum(u4) {
    sample_rate_4000_hz = 0,
    sample_rate_8000_hz = 1,
    sample_rate_11000_hz = 2,
    sample_rate_11025_hz = 3,
    sample_rate_16000_hz = 4,
    sample_rate_22050_hz = 5,
    sample_rate_24000_hz = 6,
    sample_rate_32000_hz = 7,
    sample_rate_44100_hz = 8,
    sample_rate_48000_hz = 9,
    sample_rate_96000_hz = 10,
    // Note: FMOD rejects values of 11 or above
};

const FileSubsongChannelCountType = enum(u2) {
    one_channel = 0,
    two_channels = 1,
    six_channels = 2,
    eight_channels = 3,
};

const FileSubsongFlag = struct {
    header: FileSubsongFlagHeader,
    data: FileSubsongFlagData,
};

const FileSubsongFlagHeader = packed struct(u32) {
    has_more_flags: bool,
    flag_data_size: u24,
    flag_type: FileSubsongFlagType,
};

const FileSubsongFlagType = enum(u7) {
    none = 0,
    channel_override = 1,
    sample_rate_override = 2,
    loop_info = 3,
    free_comment_or_sfx_info = 4, // TODO: Not sure which?
    unknown_5 = 5,
    xma_seek_table = 6,
    dsp_coefficients = 7,
    // TODO: 8 is not specified?
    atrac9_config = 9,
    xwma_config = 10,
    vorbis_setup_id_and_seek_table = 11,
    peak_volume = 13,
    vorbis_intra_layers = 14,
    opus_data_size_ignoring_frame_headers = 15,
    // TODO: Values above 15?

    fn getExpectedDataSize(self: FileSubsongFlagType) ?u24 {
        // u24 to match the type of flag_data_size in subsong_flag.base_data.
        // return null if it isn't a static value for that flag type, and needs to be further disambiguated when read.
        const result: ?u24 = switch (self) {
            .none => 0,
            .channel_override => 1,
            .sample_rate_override => 4,
            .loop_info => 8,
            .free_comment_or_sfx_info => 0, // TODO: ?
            .unknown_5 => null, // Can be 4 or 8
            .xma_seek_table => 0, // TODO: ?
            .dsp_coefficients => 0, // TODO: ? The switch statement stores the flag offset and defers the decision to later logic
            .atrac9_config => null, // TODO: Is 8 if the first byte is NOT 0xFE
            .xwma_config => 0, // TODO: ? The switch statement stores the flag offset and defers the decision to later logic
            .vorbis_setup_id_and_seek_table => 0, // TODO: ? The switch statement stores the flag offset and defers the decision to later logic
            .peak_volume => 4,
            .vorbis_intra_layers => 4,
            .opus_data_size_ignoring_frame_headers => 0, // TODO: ?
        };
        return result;
    }
};

const FileSubsongFlagData = union(FileSubsongFlagType) {
    none: void,
    channel_override: packed struct(u8) {
        override_value: u8,
    },
    sample_rate_override: packed struct(u32) {
        blah: u32, // TODO: Right name
    },
    loop_info: packed struct(u64) {
        loop_start_sample: u32,
        loop_end_sample: u32,
    },
    free_comment_or_sfx_info: void, // TODO: Right data
    unknown_5: packed struct(u2048) {
        blah: u2048, // TODO: Some upper bound for size?
    },
    xma_seek_table: void, // TODO: Right data
    dsp_coefficients: void, // TODO: Right data
    atrac9_config: packed union {
        magic_byte_char: u8,
        with_frame_size: Atrac9ConfigWithFrameSize,
        without_frame_size: Atrac9Config,
    },
    xwma_config: void, // TODO: Right data
    vorbis_setup_id_and_seek_table: void, // TODO: Right data
    peak_volume: packed struct(u32) {
        value: f32, // TODO: Is this right?
    },
    vorbis_intra_layers: packed struct(u32) {
        blah: u32, // TODO: Right name
    },
    opus_data_size_ignoring_frame_headers: void, // TODO: Right data
};

const Atrac9ConfigWithFrameSize = packed struct {
    frame_size_bytes: u32,
    config: Atrac9Config,
};

/// Byte swaps the data if the specified endian doesn't match the target architecture's (CPU's) endian
fn byteSwapIfNeeded(comptime T: type, value: T, endian: std.builtin.Endian) T {
    return if (endian == builtin.cpu.arch.endian()) value else @byteSwap(value);
}

/// TODO: This PR should cover this case with plain `reader.readStruct` when it gets merged - https://giithub.com/ziglang/zig/pull/21601
fn readStructPacked(reader: std.io.AnyReader, comptime T: type) anyerror!T {
    comptime std.debug.assert(@typeInfo(T).@"struct".layout == .@"packed");
    var bytes: [@divExact(@bitSizeOf(T), 8)]u8 = undefined;
    try reader.readNoEof(&bytes);
    return @bitCast(bytes);
}

fn readUnion(reader: std.io.AnyReader, comptime T: type, comptime tag: std.meta.Tag(T)) !T {
    const result = switch (@typeInfo(std.meta.TagPayload(T, tag))) {
        .@"struct" => @unionInit(T, @tagName(tag), try readStructPacked(reader, std.meta.TagPayload(T, tag))),
        .void => @unionInit(T, @tagName(tag), void{}),
        else => @compileError("Unhandled union payload type: " ++ @typeName(std.meta.TagPayload(T, tag))),
    };
    return result;
}
