const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const assert = @import("std").debug.assert;

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    // Initial window dimensions
    var window_width: c_int = 800;
    var window_height: c_int = 600;

    const screen = c.SDL_CreateWindow("Bouncing Zig Logo", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, window_width, window_height, c.SDL_WINDOW_OPENGL) orelse
        {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(screen);

    const renderer = c.SDL_CreateRenderer(screen, -1, 0) orelse {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    const zig_bmp = @embedFile("zig.bmp");
    const rw = c.SDL_RWFromConstMem(zig_bmp, zig_bmp.len) orelse {
        c.SDL_Log("Unable to get RWFromConstMem: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer assert(c.SDL_RWclose(rw) == 0);

    const zig_surface = c.SDL_LoadBMP_RW(rw, 0) orelse {
        c.SDL_Log("Unable to load bmp: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_FreeSurface(zig_surface);

    // Surface dimensions
    const surface_width = zig_surface[0].w;
    const surface_height = zig_surface[0].h;

    const zig_texture = c.SDL_CreateTextureFromSurface(renderer, zig_surface) orelse {
        c.SDL_Log("Unable to create texture from surface: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyTexture(zig_texture);

    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    // Set a random starting position
    var x: c_int = rand.intRangeAtMost(c_int, 0, window_width - surface_width);
    var y: c_int = rand.intRangeAtMost(c_int, 0, window_height - surface_height);

    var x_speed: c_int = 2;
    var y_speed: c_int = 2;

    var quit = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                c.SDL_KEYDOWN => {
                    if (event.key.keysym.sym == c.SDLK_q or event.key.keysym.sym == c.SDLK_ESCAPE) {
                        quit = true;
                    }
                },
                c.SDL_WINDOWEVENT => {
                    c.SDL_GetWindowSize(screen, &window_width, &window_height);
                },
                else => {},
            }
        }

        if (x < 0 or (x + surface_width) > window_width) x_speed *= -1;
        if (y < 0 or (y + surface_height) > window_height) y_speed *= -1;

        x += x_speed;
        y += y_speed;

        const dst_rect = c.SDL_Rect{
            .x = x,
            .y = y,
            .w = surface_width,
            .h = surface_height,
        };

        _ = c.SDL_RenderClear(renderer);
        _ = c.SDL_RenderCopy(renderer, zig_texture, null, &dst_rect);
        c.SDL_RenderPresent(renderer);

        c.SDL_Delay(17);
    }
}
