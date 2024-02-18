const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;

const imgui = @import("imgui");
const imgui_mach = imgui.backends.mach;

pub const App = @This();

pub var window_size: [2]f32 = undefined;
pub var framebuffer_size: [2]f32 = undefined;
pub var content_scale: [2]f32 = undefined;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator: std.mem.Allocator = undefined;

f: f32 = 0.0,
color: [3]f32 = .{ 0.0, 255.0, 0.0 },

pub fn init(_: *App) !void {
    allocator = gpa.allocator();
    try core.init(.{
        .title = "pixani",
        .headless = false,
        .power_preference = .high_performance,
        .size = .{
            .width = 1000,
            .height = 800,
        },
    });
    imgui.setZigAllocator(&allocator);
    _ = imgui.createContext(null);
    try imgui_mach.init(
        allocator,
        core.device,
        .{
            .mag_filter = .nearest,
            .min_filter = .nearest,
            .mipmap_filter = .nearest,
        },
    );

    var io = imgui.getIO();
    io.config_flags |= imgui.ConfigFlags_NavEnableKeyboard;
    io.font_global_scale = 1.0 / io.display_framebuffer_scale.y;
}

pub fn deinit(_: *App) void {
    imgui_mach.shutdown();
    imgui.destroyContext(null);

    core.deinit();

    _ = gpa.detectLeaks();
    _ = gpa.deinit();
}

pub fn update(app: *App) !bool {

    // 事件处理
    var iter = core.pollEvents();
    while (iter.next()) |event| {
        _ = imgui_mach.processEvent(event);
        switch (event) {
            .key_press => {
                switch (event.key_press.key) {
                    .escape => {
                        return true;
                    },
                    else => {},
                }
            },
            .close => {
                return true;
            },
            else => {},
        }
    }

    imgui_mach.newFrame() catch {};
    imgui.newFrame();

    imgui.text("Hello, world!");
    _ = imgui.sliderFloat("float", &app.f, 0.0, 1.0);
    _ = imgui.colorEdit3("color", &app.color, imgui.ColorEditFlags_None);
    imgui.showDemoWindow(null);

    imgui.render();

    // 绘制
    const back_buffer_view = core.swap_chain.getCurrentTextureView().?;
    defer back_buffer_view.release();
    const color_attachment = gpu.RenderPassColorAttachment{
        .view = back_buffer_view,
        .clear_value = gpu.Color{
            .r = 0.0 / 255.0,
            .g = 255.0 / 255.0,
            .b = 0.0 / 255.0,
            .a = 1.0,
        },
        .load_op = .clear,
        .store_op = .store,
    };

    const encoder = core.device.createCommandEncoder(null);
    defer encoder.release();
    const render_pass_descriptor = gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{color_attachment},
    });

    const pass = encoder.beginRenderPass(&render_pass_descriptor);
    defer pass.release();
    imgui_mach.renderDrawData(imgui.getDrawData().?, pass) catch {};

    pass.end();

    var command = encoder.finish(null);
    defer command.release();

    core.queue.submit(&[_]*gpu.CommandBuffer{command});
    core.swap_chain.present();

    return false;
}
