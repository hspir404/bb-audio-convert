const builtin = @import("builtin");
const std = @import("std");
const libmp3lame_c = @import("libmp3lame_c");

pub usingnamespace libmp3lame_c; // TODO: Remove this after making some wrappers

extern fn is_lame_global_flags_valid(global_flags: ?*const libmp3lame_c.lame_global_flags) c_int;
extern fn is_lame_internal_flags_valid(global_flags: ?*const libmp3lame_c.lame_internal_flags) c_int;

pub const Mp3LameError = error{
    BufferTooSmall,
    OutOfMemory,
    InitNotCalled,
    PsychoAcousticError,
    ReplayGainError,
    UnknownError,
};

/// Only needed for getter functions that can return 0 in both success and error cases, that have no way to disambiguate
inline fn isLameGlobalFlagsValid(global_flags: *const libmp3lame_c.lame_global_flags) bool {
    const value = is_lame_global_flags_valid(global_flags);
    const result = value != 0;
    return result;
}

/// Only needed for getter functions that can return 0 in both success and error cases,
/// that have no way to disambiguate, that also call this function internally.
inline fn isLameInternalFlagsValid(global_flags: *const libmp3lame_c.lame_global_flags) bool {
    const value = is_lame_internal_flags_valid(global_flags.internal_flags);
    const result = value != 0;
    return result;
}

pub fn init() Mp3LameError!*libmp3lame_c.lame_global_flags {
    const result = libmp3lame_c.lame_init();
    return result orelse error.UnknownError;
}

pub fn close(global_flags: *libmp3lame_c.lame_global_flags) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_close(global_flags);
    const result = switch (status_code) {
        0 => Status.okay,
        -3 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn initParams(global_flags: *libmp3lame_c.lame_global_flags) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_init_params(global_flags);
    const result = switch (status_code) {
        0 => Status.okay,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn setNumSamples(global_flags: *libmp3lame_c.lame_global_flags, num_samples: usize) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_num_samples(global_flags, @intCast(num_samples));
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getNumSamples(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!usize {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_num_samples(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub fn setInputSampleRate(global_flags: *libmp3lame_c.lame_global_flags, sample_rate: i32) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_in_samplerate(global_flags, sample_rate);
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getInputSampleRate(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!i32 {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_in_samplerate(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub fn setNumChannels(global_flags: *libmp3lame_c.lame_global_flags, num_channels: usize) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_num_channels(global_flags, @intCast(num_channels));
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getNumChannels(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!usize {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_num_channels(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub fn setScale(global_flags: *libmp3lame_c.lame_global_flags, scale: f32) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_scale(global_flags, scale);
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getScale(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!f32 {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_scale(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub fn setScaleLeftChannel(global_flags: *libmp3lame_c.lame_global_flags, scale: f32) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_scale_left(global_flags, scale);
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getScaleLeftChannel(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!f32 {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_scale_left(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub fn setScaleRightChannel(global_flags: *libmp3lame_c.lame_global_flags, scale: f32) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_scale_right(global_flags, scale);
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getScaleRightChannel(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!f32 {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_scale_right(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub fn setOutputSampleRate(global_flags: *libmp3lame_c.lame_global_flags, sample_rate: i32) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_out_samplerate(global_flags, sample_rate);
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getOutputSampleRate(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!i32 {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_out_samplerate(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

// TODO:
// int lame_set_analysis(lame_global_flags * gfp, int analysis)
// int lame_get_analysis(const lame_global_flags * gfp)
// int lame_set_bWriteVbrTag(lame_global_flags * gfp, int bWriteVbrTag)
// int lame_get_bWriteVbrTag(const lame_global_flags * gfp)
// int lame_set_decode_only(lame_global_flags * gfp, int decode_only)
// int lame_get_decode_only(const lame_global_flags * gfp)
// int lame_set_ogg(lame_global_flags * gfp, int ogg)
// int lame_get_ogg(const lame_global_flags * gfp)

pub fn setEncodingQualityLevel(global_flags: *libmp3lame_c.lame_global_flags, quality_level: EncodingQualityLevel) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_quality(global_flags, quality_level);
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getEncodingQualityLevel(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!EncodingQualityLevel {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_quality(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub const EncodingQualityLevel = enum(i32) {
    best_and_slowest0 = 0,
    good1 = 1,
    good2 = 2,
    good3 = 3,
    medium4 = 4,
    medium5 = 5,
    medium6 = 6,
    okay7 = 7,
    okay8 = 8,
    worst_and_fastest9 = 9,
};

pub fn setMpegMode(global_flags: *libmp3lame_c.lame_global_flags, mpeg_mode: MpegMode) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_mode(global_flags, mpeg_mode);
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getMpegMode(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!MpegMode {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_mode(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub const MpegMode = enum(i32) {
    stereo = libmp3lame_c.STEREO,
    joint_stereo = libmp3lame_c.JOINT_STEREO,
    dual_channel = libmp3lame_c.DUAL_CHANNEL,
    mono = libmp3lame_c.MONO,
    not_set = libmp3lame_c.NOT_SET,
    max_indicator = libmp3lame_c.MAX_INDICATOR,
};

// TODO:
// int lame_set_force_ms(lame_global_flags * gfp, int force_ms)
// int lame_get_force_ms(const lame_global_flags * gfp)
// int lame_set_free_format(lame_global_flags * gfp, int free_format)
// int lame_get_free_format(const lame_global_flags * gfp)
// int lame_set_findReplayGain(lame_global_flags * gfp, int findReplayGain)
// int lame_get_findReplayGain(const lame_global_flags * gfp)
// int lame_set_decode_on_the_fly(lame_global_flags * gfp, int decode_on_the_fly)
// int lame_get_decode_on_the_fly(const lame_global_flags * gfp)
// int lame_set_findPeakSample(lame_global_flags * gfp, int arg)
// int lame_get_findPeakSample(const lame_global_flags * gfp)
// int lame_set_ReplayGain_input(lame_global_flags * gfp, int arg)
// int lame_get_ReplayGain_input(const lame_global_flags * gfp)
// int lame_set_ReplayGain_decode(lame_global_flags * gfp, int arg)
// int lame_get_ReplayGain_decode(const lame_global_flags * gfp)
// int lame_set_nogap_total(lame_global_flags * gfp, int the_nogap_total)
// int lame_get_nogap_total(const lame_global_flags * gfp)
// int lame_set_nogap_currentindex(lame_global_flags * gfp, int the_nogap_index)
// int lame_get_nogap_currentindex(const lame_global_flags * gfp)

// TODO: Hook these up for logging purposes? va_list is a bit difficult though...
// int lame_set_errorf(lame_global_flags * gfp, void (*func) (const char *, va_list))
// int lame_set_debugf(lame_global_flags * gfp, void (*func) (const char *, va_list))
// int lame_set_msgf(lame_global_flags * gfp, void (*func) (const char *, va_list))

pub fn setBitRate(global_flags: *libmp3lame_c.lame_global_flags, bit_rate: i32) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_brate(global_flags, bit_rate);
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getBitRate(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!i32 {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_brate(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub fn setCompressionRatio(global_flags: *libmp3lame_c.lame_global_flags, compression_ratio: f32) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_compression_ratio(global_flags, compression_ratio);
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getCompressionRatio(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!i32 {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_compression_ratio(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub fn setIsCopyrighted(global_flags: *libmp3lame_c.lame_global_flags, value: bool) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_copyright(global_flags, @intFromBool(value));
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getIsCopyrighted(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!bool {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_copyright(global_flags);
        return value != 0;
    } else {
        return error.InitNotCalled;
    }
}

pub fn setIsOriginal(global_flags: *libmp3lame_c.lame_global_flags, value: bool) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_original(global_flags, @intFromBool(value));
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getIsOriginal(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!bool {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_original(global_flags);
        return value != 0;
    } else {
        return error.InitNotCalled;
    }
}

// TODO:
// int lame_set_error_protection(lame_global_flags * gfp, int error_protection)
// int lame_get_error_protection(const lame_global_flags * gfp)
// int lame_set_extension(lame_global_flags * gfp, int extension)
// int lame_get_extension(const lame_global_flags * gfp)
// int lame_set_strict_ISO(lame_global_flags * gfp, int val)
// int lame_get_strict_ISO(const lame_global_flags * gfp)
// int lame_set_disable_reservoir(lame_global_flags * gfp, int disable_reservoir)
// int lame_get_disable_reservoir(const lame_global_flags * gfp)
// int lame_set_experimentalX(lame_global_flags * gfp, int experimentalX)
// int lame_get_experimentalX(const lame_global_flags * gfp)
// int lame_set_quant_comp(lame_global_flags * gfp, int quant_type)
// int lame_get_quant_comp(const lame_global_flags * gfp)
// int lame_set_quant_comp_short(lame_global_flags * gfp, int quant_type)
// int lame_get_quant_comp_short(const lame_global_flags * gfp)
// int lame_set_experimentalY(lame_global_flags * gfp, int experimentalY)
// int lame_get_experimentalY(const lame_global_flags * gfp)
// int lame_set_experimentalZ(lame_global_flags * gfp, int experimentalZ)
// int lame_get_experimentalZ(const lame_global_flags * gfp)
// int lame_set_exp_nspsytune(lame_global_flags * gfp, int exp_nspsytune)
// int lame_get_exp_nspsytune(const lame_global_flags * gfp)

pub fn setVbrMode(global_flags: *libmp3lame_c.lame_global_flags, vbr_mode: VbrMode) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_VBR(global_flags, vbr_mode);
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getVbrMode(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!VbrMode {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_VBR(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub const VbrMode = enum(i32) {
    vbr_off = libmp3lame_c.vbr_off,
    vbr_mt = libmp3lame_c.vbr_mt,
    vbr_rh = libmp3lame_c.vbr_rh,
    vbr_abr = libmp3lame_c.vbr_abr,
    vbr_mtrh = libmp3lame_c.vbr_mtrh,
    vbr_max_indicator = libmp3lame_c.vbr_max_indicator,
};

// TODO:
// int lame_set_VBR_q(lame_global_flags * gfp, int VBR_q)
// int lame_get_VBR_q(const lame_global_flags * gfp)

pub fn setVbrQuality(global_flags: *libmp3lame_c.lame_global_flags, quality_level: f32) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_VBR_quality(global_flags, quality_level);
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub fn getVbrQuality(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!f32 {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_VBR_quality(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

// TODO:
// int lame_set_VBR_mean_bitrate_kbps(lame_global_flags * gfp, int VBR_mean_bitrate_kbps)
// int lame_get_VBR_mean_bitrate_kbps(const lame_global_flags * gfp)
// int lame_set_VBR_min_bitrate_kbps(lame_global_flags * gfp, int VBR_min_bitrate_kbps)
// int lame_get_VBR_min_bitrate_kbps(const lame_global_flags * gfp)
// int lame_set_VBR_max_bitrate_kbps(lame_global_flags * gfp, int VBR_max_bitrate_kbps)
// int lame_get_VBR_max_bitrate_kbps(const lame_global_flags * gfp)
// int lame_set_VBR_hard_min(lame_global_flags * gfp, int VBR_hard_min)
// int lame_get_VBR_hard_min(const lame_global_flags * gfp)
// int lame_set_lowpassfreq(lame_global_flags * gfp, int lowpassfreq)
// int lame_get_lowpassfreq(const lame_global_flags * gfp)
// int lame_set_lowpasswidth(lame_global_flags * gfp, int lowpasswidth)
// int lame_get_lowpasswidth(const lame_global_flags * gfp)
// int lame_set_highpassfreq(lame_global_flags * gfp, int highpassfreq)
// int lame_get_highpassfreq(const lame_global_flags * gfp)
// int lame_set_highpasswidth(lame_global_flags * gfp, int highpasswidth)
// int lame_get_highpasswidth(const lame_global_flags * gfp)
// int lame_set_maskingadjust(lame_global_flags * gfp, float adjust)
// float lame_get_maskingadjust(const lame_global_flags * gfp)
// int lame_set_maskingadjust_short(lame_global_flags * gfp, float adjust)
// float lame_get_maskingadjust_short(const lame_global_flags * gfp)
// int lame_set_ATHonly(lame_global_flags * gfp, int ATHonly)
// int lame_get_ATHonly(const lame_global_flags * gfp)
// int lame_set_ATHshort(lame_global_flags * gfp, int ATHshort)
// int lame_get_ATHshort(const lame_global_flags * gfp)
// int lame_set_noATH(lame_global_flags * gfp, int noATH)
// int lame_get_noATH(const lame_global_flags * gfp)
// int lame_set_ATHtype(lame_global_flags * gfp, int ATHtype)
// int lame_get_ATHtype(const lame_global_flags * gfp)
// int lame_set_ATHcurve(lame_global_flags * gfp, float ATHcurve)
// float lame_get_ATHcurve(const lame_global_flags * gfp)
// int lame_set_ATHlower(lame_global_flags * gfp, float ATHlower)
// float lame_get_ATHlower(const lame_global_flags * gfp)
// int lame_set_athaa_type(lame_global_flags * gfp, int athaa_type)
// int lame_get_athaa_type(const lame_global_flags * gfp)
// int lame_set_athaa_loudapprox(lame_global_flags * gfp, int athaa_loudapprox)
// int lame_get_athaa_loudapprox(const lame_global_flags * gfp)
// int lame_set_athaa_sensitivity(lame_global_flags * gfp, float athaa_sensitivity)
// float lame_get_athaa_sensitivity(const lame_global_flags * gfp)
// int lame_set_allow_diff_short(lame_global_flags * gfp, int allow_diff_short)
// int lame_get_allow_diff_short(const lame_global_flags * gfp)
// int lame_set_useTemporal(lame_global_flags * gfp, int useTemporal)
// int lame_get_useTemporal(const lame_global_flags * gfp)
// int lame_set_interChRatio(lame_global_flags * gfp, float ratio)
// float lame_get_interChRatio(const lame_global_flags * gfp)
// int lame_set_substep(lame_global_flags * gfp, int method)
// int lame_get_substep(const lame_global_flags * gfp)
// int lame_set_sfscale(lame_global_flags * gfp, int val)
// int lame_get_sfscale(const lame_global_flags * gfp)
// int lame_set_subblock_gain(lame_global_flags * gfp, int sbgain)
// int lame_get_subblock_gain(const lame_global_flags * gfp)
// int lame_set_no_short_blocks(lame_global_flags * gfp, int no_short_blocks)
// int lame_get_no_short_blocks(const lame_global_flags * gfp)
// int lame_set_force_short_blocks(lame_global_flags * gfp, int short_blocks)
// int lame_get_force_short_blocks(const lame_global_flags * gfp)
// int lame_set_short_threshold_lrm(lame_global_flags * gfp, float lrm)
// float lame_get_short_threshold_lrm(const lame_global_flags * gfp)
// int lame_set_short_threshold_s(lame_global_flags * gfp, float s)
// float lame_get_short_threshold_s(const lame_global_flags * gfp)
// int lame_set_short_threshold(lame_global_flags * gfp, float lrm, float s)
// int lame_set_emphasis(lame_global_flags * gfp, int emphasis)
// int lame_get_emphasis(const lame_global_flags * gfp)

pub fn getVersion(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!MpegVersion {
    if (isLameGlobalFlagsValid(global_flags) and isLameInternalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_version(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub const MpegVersion = enum(i32) {
    unknown = -1,
    mpeg_2 = 0,
    mpeg_1 = 1,
    mpeg_2_5 = 2,
};

pub fn getEncoderDelay(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!i32 {
    if (isLameGlobalFlagsValid(global_flags) and isLameInternalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_encoder_delay(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub fn getEncoderPadding(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!i32 {
    if (isLameGlobalFlagsValid(global_flags) and isLameInternalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_encoder_padding(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub fn getFrameSize(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!i32 {
    if (isLameGlobalFlagsValid(global_flags) and isLameInternalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_framesize(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub fn getFrameNum(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!i32 {
    if (isLameGlobalFlagsValid(global_flags) and isLameInternalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_frameNum(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub fn getMfSamplesToEncode(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!i32 { // TODO: What does mf stand for?
    if (isLameGlobalFlagsValid(global_flags) and isLameInternalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_mf_samples_to_encode(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub fn getSizeMp3Buffer(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!i32 {
    if (isLameGlobalFlagsValid(global_flags) and isLameInternalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_size_mp3buffer(global_flags);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

// TODO:?
// int lame_get_RadioGain(const lame_global_flags * gfp)
// int lame_get_AudiophileGain(const lame_global_flags * gfp)
// float lame_get_PeakSample(const lame_global_flags * gfp)
// int lame_get_noclipGainChange(const lame_global_flags * gfp)
// float lame_get_noclipScale(const lame_global_flags * gfp)

pub fn getTotalFrames(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!usize {
    if (isLameGlobalFlagsValid(global_flags) and isLameInternalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_totalframes(global_flags);
        return value != 0;
    } else {
        return error.InitNotCalled;
    }
}

// TODO:?
// int lame_set_preset(lame_global_flags * gfp, int preset)

pub fn setAsmOptimizations(global_flags: *libmp3lame_c.lame_global_flags, optimization_type: AsmOptimizationsType, value: bool) Mp3LameError!void {
    const status_code = libmp3lame_c.lame_set_asm_optimizations(global_flags, optimization_type, @intFromBool(value));
    const result = switch (status_code) {
        0 => Status.okay,
        -1 => Status.init_not_called,
        else => Status.unknown_error,
    };
    if (result.getError()) |err| {
        return err;
    }
}

pub const AsmOptimizationsType = enum(i32) {
    mmx = 1,
    amd_3dnow = 2,
    sse = 3,
};

pub fn setWriteId3tagAutomatic(global_flags: *libmp3lame_c.lame_global_flags, value: bool) Mp3LameError!void {
    if (isLameGlobalFlagsValid(global_flags)) {
        libmp3lame_c.lame_set_write_id3tag_automatic(global_flags, @intFromBool(value));
    } else {
        return error.InitNotCalled;
    }
}

pub fn getWriteId3tagAutomatic(global_flags: *const libmp3lame_c.lame_global_flags) Mp3LameError!bool {
    if (isLameGlobalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_write_id3tag_automatic(global_flags);
        return value != 0;
    } else {
        return error.InitNotCalled;
    }
}

// void lame_set_tune(lame_global_flags * gfp, float val)
// void lame_set_msfix(lame_global_flags * gfp, double msfix)
// float lame_get_msfix(const lame_global_flags * gfp)

pub fn getMaximumNumberOfSamples(global_flags: *const libmp3lame_c.lame_global_flags, buffer_size_bytes: usize) Mp3LameError!usize {
    if (isLameGlobalFlagsValid(global_flags) and isLameInternalFlagsValid(global_flags)) {
        const value = libmp3lame_c.lame_get_maximum_number_of_samples(global_flags, buffer_size_bytes);
        return value;
    } else {
        return error.InitNotCalled;
    }
}

pub fn encodeBuffer(
    global_flags: *libmp3lame_c.lame_global_flags,
    left_buffer: []const i16,
    right_buffer: []const i16,
    sample_count: usize,
    output_buffer: []u8,
) Mp3LameError!usize {
    const status_code = libmp3lame_c.lame_encode_buffer(
        global_flags,
        left_buffer.ptr,
        right_buffer.ptr,
        @intCast(sample_count),
        output_buffer.ptr,
        0,
    );
    const result: Status = switch (status_code) {
        0 => .okay,
        -1 => .buffer_too_small,
        -2 => .out_of_memory,
        -3 => .init_not_called,
        -4 => .psycho_acoustic_error,
        -6 => .replay_gain_error,
        else => |val| if (val < 0) .unknown_error else .okay, // TODO: Can it return a positive number?
    };
    if (result.getError()) |err| {
        return err;
    }
    return @intCast(status_code); // Sample count
}

pub fn encodeBufferInterleaved(
    global_flags: *libmp3lame_c.lame_global_flags,
    interleaved_buffers: []const i16,
    sample_count: usize,
    output_buffer: []u8,
) Mp3LameError!usize {
    const status_code = libmp3lame_c.lame_encode_buffer_interleaved(
        global_flags,
        @ptrCast(@constCast(interleaved_buffers.ptr)), // This is fine for now. The code it immediately calls passes it as const to a subsequent function
        @intCast(sample_count),
        output_buffer.ptr,
        0,
    );
    const result: Status = switch (status_code) {
        0 => .okay,
        -1 => .buffer_too_small,
        -2 => .out_of_memory,
        -3 => .init_not_called,
        -4 => .psycho_acoustic_error,
        -6 => .replay_gain_error,
        else => |val| if (val < 0) .unknown_error else .okay, // TODO: Can it return a positive number?
    };
    if (result.getError()) |err| {
        return err;
    }
    return @intCast(status_code); // Sample count
}

pub fn initDecoder() Mp3LameError!*libmp3lame_c.hip_global_flags {
    const result = libmp3lame_c.hip_decode_init();
    // TODO: Do these? Not sure how easy the va_list interface is to deal with
    // pub extern fn hip_set_errorf(gfp: hip_t, f: lame_report_function) void;
    // pub extern fn hip_set_debugf(gfp: hip_t, f: lame_report_function) void;
    // pub extern fn hip_set_msgf(gfp: hip_t, f: lame_report_function) void;
    return result orelse error.UnknownError;
}

pub fn freeDecoder(decoder: *libmp3lame_c.hip_global_flags) void {
    const result = libmp3lame_c.hip_decode_exit(decoder);
    std.debug.assert(result == 0); // Code never returns anything but this
}

pub fn decode(decoder: *libmp3lame_c.hip_global_flags, input_buffer: []const u8, output_pcm_left: []i16, output_pcm_right: []i16) Mp3LameError!usize {
    const result = libmp3lame_c.hip_decode(decoder, @constCast(input_buffer.ptr), input_buffer.len, @ptrCast(output_pcm_left.ptr), @ptrCast(output_pcm_right.ptr));
    if (result < 0) {
        return error.UnknownError;
    }
    return @intCast(result);
}

pub fn decodeHeaders(decoder: *libmp3lame_c.hip_global_flags, input_buffer: []const u8, output_pcm_left: []i16, output_pcm_right: []i16, output_mp3_data: *libmp3lame_c.mp3data_struct) Mp3LameError!usize {
    const result = libmp3lame_c.hip_decode_headers(decoder, @constCast(input_buffer.ptr), input_buffer.len, @ptrCast(output_pcm_left.ptr), @ptrCast(output_pcm_right.ptr), output_mp3_data);
    if (result < 0) {
        return error.UnknownError;
    }
    return @intCast(result);
}

pub fn decode1(decoder: *libmp3lame_c.hip_global_flags, input_buffer: []const u8, output_pcm_left: []i16, output_pcm_right: []i16) Mp3LameError!usize {
    const result = libmp3lame_c.hip_decode1(decoder, @constCast(input_buffer.ptr), input_buffer.len, @ptrCast(output_pcm_left.ptr), @ptrCast(output_pcm_right.ptr));
    if (result < 0) {
        return error.UnknownError;
    }
    return @intCast(result);
}

pub fn decode1Headers(decoder: *libmp3lame_c.hip_global_flags, input_buffer: []const u8, output_pcm_left: []i16, output_pcm_right: []i16, output_mp3_data: *libmp3lame_c.mp3data_struct) Mp3LameError!usize {
    const result = libmp3lame_c.hip_decode1_headers(decoder, @constCast(input_buffer.ptr), input_buffer.len, @ptrCast(output_pcm_left.ptr), @ptrCast(output_pcm_right.ptr), output_mp3_data);
    if (result < 0) {
        return error.UnknownError;
    }
    return @intCast(result);
}

pub fn decode1HeadersB(decoder: *libmp3lame_c.hip_global_flags, input_buffer: []const u8, output_pcm_left: []i16, output_pcm_right: []i16, output_mp3_data: *libmp3lame_c.mp3data_struct, output_encoder_delay: *usize, output_encoder_padding: *usize) Mp3LameError!usize {
    var encoder_delay: c_int = 0;
    var encoder_padding: c_int = 0;
    const result = libmp3lame_c.hip_decode1_headersB(decoder, @constCast(input_buffer.ptr), input_buffer.len, @ptrCast(output_pcm_left.ptr), @ptrCast(output_pcm_right.ptr), output_mp3_data, &encoder_delay, &encoder_padding);
    if (result < 0) {
        return error.UnknownError;
    }
    output_encoder_delay.* = @intCast(encoder_delay);
    output_encoder_padding.* = @intCast(encoder_padding);
    return @intCast(result);
}

pub const Status = enum(c_int) {
    okay = 0,
    buffer_too_small = -1,
    out_of_memory = -2,
    init_not_called = -3,
    psycho_acoustic_error = -4,
    replay_gain_error = -6,
    unknown_error = -10,

    pub fn getError(self: Status) ?Mp3LameError {
        const result: ?Mp3LameError = switch (self) {
            .okay => null,
            .buffer_too_small => error.BufferTooSmall,
            .out_of_memory => error.OutOfMemory,
            .init_not_called => error.InitNotCalled,
            .psycho_acoustic_error => error.PsychoAcousticError,
            .replay_gain_error => error.ReplayGainError,
            .unknown_error => error.UnknownError,
        };
        return result;
    }
};
