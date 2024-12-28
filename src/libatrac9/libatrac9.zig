const std = @import("std");
const libatrac9_c = @import("libatrac9_c");

pub const Atrac9Error = error{
    NotImplemented,

    BadConfigData,

    UnpackSuperframeFlagInvalid,
    UnpackReuseBandParamsInvalid,
    UnpackBandParamsInvalid,

    UnpackGradBoundaryInvalid,
    UnpackGradStartUnitOob,
    UnpackGradEndUnitOob,
    UnpackGradStartValueOob,
    UnpackGradEndValueOob,
    UnpackGradEndUnitInvalid,

    UnpackScaleFactorModeInvalid,
    UnpackScaleFactorOob,

    UnpackExtensionDataInvalid,
};

pub const ChannelConfig = struct {
    channel_config: libatrac9_c.ChannelConfig = .{},
};

pub const CodecInfo = struct {
    codec_info: libatrac9_c.CodecInfo = .{},

    pub fn getChannels(self: CodecInfo) usize {
        return @intCast(self.codec_info.Channels);
    }

    pub fn getChannelConfigIndex(self: CodecInfo) usize {
        return @intCast(self.codec_info.ChannelConfigIndex);
    }

    pub fn getSamplingRate(self: CodecInfo) usize {
        return @intCast(self.codec_info.SamplingRate);
    }

    pub fn getSuperframeSize(self: CodecInfo) usize {
        return @intCast(self.codec_info.SuperframeSize);
    }

    pub fn getFramesInSuperframe(self: CodecInfo) usize {
        return @intCast(self.codec_info.FramesInSuperframe);
    }

    pub fn getFrameSamples(self: CodecInfo) usize {
        return @intCast(self.codec_info.FrameSamples);
    }

    pub fn getWlength(self: CodecInfo) usize {
        return @intCast(self.codec_info.Wlength);
    }
};

pub const ConfigData = struct {
    config_data: libatrac9_c.ConfigData = .{},
};

fn opaqueStruct(comptime T: type, comptime elem_bit_size: usize) type {
    if (@rem(@bitSizeOf(T), elem_bit_size) != 0) {
        @compileError(std.fmt.comptimePrint(
            "Bit size of type {s} ({}) is not divisible by {} - Need to switch type of elem_bit_size",
            .{ @typeName(T), @bitSizeOf(T), elem_bit_size },
        ));
    }
    return [@divExact(@bitSizeOf(T), elem_bit_size)]std.meta.Int(.unsigned, elem_bit_size);
}

pub const Handle = struct {
    handle: libatrac9_c.Atrac9Handle = .{},
};

extern fn Atrac9InitDecoder(handle: ?*anyopaque, pConfigData: [*c]u8) c_int;
extern fn Atrac9Decode(handle: ?*anyopaque, pAtrac9Buffer: [*c]const u8, pPcmBuffer: [*c]c_short, pNBytesUsed: [*c]c_int) c_int;
extern fn Atrac9GetCodecInfo(handle: ?*anyopaque, pCodecInfo: [*c]libatrac9_c.CodecInfo) c_int;

pub fn initDecoder(handle: *Handle, config_data: u32) Atrac9Error!void {
    var config_data_tmp = config_data;
    const status: Status = @enumFromInt(Atrac9InitDecoder(&handle.handle, @ptrCast(&config_data_tmp)));
    if (status.getError()) |err| {
        return err;
    }
}

pub fn decode(handle: *Handle, input_atrac9_buffer: []const u8, output_pcm_buffer: []i16) Atrac9Error!usize {
    var result: c_int = undefined;
    const status: Status = @enumFromInt(Atrac9Decode(&handle.handle, input_atrac9_buffer.ptr, output_pcm_buffer.ptr, &result));
    if (status.getError()) |err| {
        return err;
    }
    return @intCast(result);
}

pub fn getCodecInfo(handle: *Handle) Atrac9Error!CodecInfo {
    var result_tmp = libatrac9_c.CodecInfo{};
    const status: Status = @enumFromInt(Atrac9GetCodecInfo(&handle.handle, @ptrCast(&result_tmp)));
    if (status.getError()) |err| {
        return err;
    }
    const result = CodecInfo{ .codec_info = result_tmp };
    return result;
}

pub const Status = enum(c_int) {
    err_success = libatrac9_c.ERR_SUCCESS,

    err_not_implemented = @bitCast(libatrac9_c.ERR_NOT_IMPLEMENTED),

    err_bad_config_data = @bitCast(libatrac9_c.ERR_BAD_CONFIG_DATA),

    err_unpack_superframe_flag_invalid = @bitCast(libatrac9_c.ERR_UNPACK_SUPERFRAME_FLAG_INVALID),
    err_unpack_reuse_band_params_invalid = @bitCast(libatrac9_c.ERR_UNPACK_REUSE_BAND_PARAMS_INVALID),
    err_unpack_band_params_invalid,

    err_unpack_grad_boundary_invalid = @bitCast(libatrac9_c.ERR_UNPACK_GRAD_BOUNDARY_INVALID),
    err_unpack_grad_start_unit_oob,
    err_unpack_grad_end_unit_oob,
    err_unpack_grad_start_value_oob,
    err_unpack_grad_end_value_oob,
    err_unpack_grad_end_unit_invalid,

    err_unpack_scale_factor_mode_invalid,
    err_unpack_scale_factor_oob,

    err_unpack_extension_data_invalid,

    pub fn getError(self: Status) ?Atrac9Error {
        const result: ?Atrac9Error = switch (self) {
            .err_success => null,
            .err_not_implemented => error.NotImplemented,
            .err_bad_config_data => error.BadConfigData,
            .err_unpack_superframe_flag_invalid => error.UnpackSuperframeFlagInvalid,
            .err_unpack_reuse_band_params_invalid => error.UnpackReuseBandParamsInvalid,
            .err_unpack_band_params_invalid => error.UnpackBandParamsInvalid,
            .err_unpack_grad_boundary_invalid => error.UnpackGradBoundaryInvalid,
            .err_unpack_grad_start_unit_oob => error.UnpackGradStartUnitOob,
            .err_unpack_grad_end_unit_oob => error.UnpackGradEndUnitOob,
            .err_unpack_grad_start_value_oob => error.UnpackGradStartValueOob,
            .err_unpack_grad_end_value_oob => error.UnpackGradEndValueOob,
            .err_unpack_grad_end_unit_invalid => error.UnpackGradEndUnitInvalid,
            .err_unpack_scale_factor_mode_invalid => error.UnpackScaleFactorModeInvalid,
            .err_unpack_scale_factor_oob => error.UnpackScaleFactorOob,
            .err_unpack_extension_data_invalid => error.UnpackExtensionDataInvalid,
        };
        return result;
    }
};
