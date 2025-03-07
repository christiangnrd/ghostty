const std = @import("std");
const build_config = @import("../build_config.zig");

const log = std.log.scoped(.i18n);

/// Supported locales for the application. This must be kept up to date
/// with the translations available in the `po/` directory; this is used
/// by our build process as well runtime libghostty APIs.
///
/// The order also matters. For incomplete locale information (i.e. only
/// a language code available), the first match is used. For example, if
/// we know the user requested `zh` but has no region code, then we'd pick
/// the first locale that matches `zh`.
///
/// For ordering, we prefer:
///
///   1. The most common locales first, since there are places in the code
///      where we do linear searches for a locale and we want to minimize
///      the number of iterations for the common case.
///
///   2. Alphabetical for otherwise equally common locales.
///
///   3. Most preferred locale for a language without a country code.
///
pub const locales = [_][:0]const u8{
    "zh_CN.UTF-8",
};

/// Set for faster membership lookup of locales.
pub const locales_map = map: {
    var kvs: [locales.len]struct { []const u8 } = undefined;
    for (locales, 0..) |locale, i| kvs[i] = .{locale};
    break :map std.StaticStringMap(void).initComptime(kvs);
};

pub const InitError = error{
    InvalidResourcesDir,
    OutOfMemory,
};

/// Initialize i18n support for the application. This should be
/// called automatically by the global state initialization
/// in global.zig.
///
/// This calls `bindtextdomain` for gettext with the proper directory
/// of translations. This does NOT call `textdomain` as we don't
/// want to set the domain for the entire application since this is also
/// used by libghostty.
pub fn init(resources_dir: []const u8) InitError!void {
    // Our resources dir is always nested below the share dir that
    // is standard for translations.
    const share_dir = std.fs.path.dirname(resources_dir) orelse
        return error.InvalidResourcesDir;

    // Build our locale path
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = std.fmt.bufPrintZ(&buf, "{s}/locale", .{share_dir}) catch
        return error.OutOfMemory;

    // Bind our bundle ID to the given locale path
    log.debug("binding domain={s} path={s}", .{ build_config.bundle_id, path });
    _ = bindtextdomain(build_config.bundle_id, path.ptr) orelse
        return error.OutOfMemory;
}

/// Finds the closest matching locale for a given language code.
pub fn closestLocaleForLanguage(lang: []const u8) ?[:0]const u8 {
    for (locales) |locale| {
        const idx = std.mem.indexOfScalar(u8, locale, '_') orelse continue;
        if (std.mem.eql(u8, locale[0..idx], lang)) {
            return locale;
        }
    }

    return null;
}

/// Translate a message for the Ghostty domain.
pub fn _(msgid: [*:0]const u8) [*:0]const u8 {
    return dgettext(build_config.bundle_id, msgid);
}

// Manually include function definitions for the gettext functions
// as libintl.h isn't always easily available (e.g. in musl)
extern fn bindtextdomain(domainname: [*:0]const u8, dirname: [*:0]const u8) ?[*:0]const u8;
extern fn textdomain(domainname: [*:0]const u8) ?[*:0]const u8;
extern fn gettext(msgid: [*:0]const u8) [*:0]const u8;
extern fn dgettext(domainname: [*:0]const u8, msgid: [*:0]const u8) [*:0]const u8;
