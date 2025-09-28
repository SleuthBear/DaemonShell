package main

import "core:fmt"
import "core:c"
import "core:os"
import "core:container/queue"
import "core:time"
import gl "vendor:OpenGL"
import "vendor:glfw"
import ds "daemonshell"
import tr "text_render"
import "ui"

GL_MAJOR_VERSION : c.int : 3
GL_MINOR_VERSION :: 3
WIDTH: f32 = 800
HEIGHT: f32 = 600

// TODO cleanup function for game layers
main :: proc() {
        if int(glfw.Init()) != 1 {
                fmt.println("Failed to initialize glfw")
                return
        }
        glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3) 
        glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
        glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
        glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
        glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE)
        defer glfw.Terminate()

        window := glfw.CreateWindow(i32(WIDTH), i32(HEIGHT), "DaemonShell", nil, nil)
        if window == nil {
                fmt.println("Failed to create window")
                return
        }
    
        glfw.MakeContextCurrent(window)
        glfw.SwapInterval(1)
        gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)
        gl.Enable(gl.BLEND)
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
        glfw.SetWindowSizeCallback(window, window_size_callback)
        glfw.SetFramebufferSizeCallback(window, frame_buffer_callback)

        // Create required game objects
        game_stack: queue.Queue(ds.Layer)
        queue.init(&game_stack)

        text_shader, text_shade_ok := gl.load_shaders_file("shaders/text.vert", "shaders/text.frag")
        if !text_shade_ok {
                fmt.println("Failed to create text")
                os.exit(1)
        }
        // TODO the if statement in this shader is slow. If we removed it we could have better performance with
        // Only 1 more draw call. 
        shader, shader_ok := gl.load_shaders_file("shaders/ui.vert", "shaders/ui.frag")
        if !shader_ok {
                fmt.println("Failed to create shader")
                os.exit(1)
        }

        terminal := ds.init_terminal(&WIDTH, &HEIGHT, text_shader, shader, &game_stack)
        queue.push_back(&game_stack, ds.Layer{&terminal, ds.update_terminal, ds.cleanup_terminal})
        
        main_menu := ds.init_main_menu(&WIDTH, &HEIGHT, text_shader, shader, terminal.chars, terminal.tex, &terminal)
        queue.push_back(&game_stack, ds.Layer{main_menu, ds.update_main_menu, ds.cleanup_main_menu})

        imp := ds.init_imp(shader, text_shader, terminal.tex, terminal.chars, &WIDTH, &HEIGHT)
        terminal.imp = imp

        
        st := time.Stopwatch{_accumulation = 1600000}
        frame_count: f64 = 0
        total_time: f64 = 0
        for !glfw.WindowShouldClose(window) {
                time.stopwatch_stop(&st)
                dt := time.duration_seconds(time.stopwatch_duration(st))
                time.stopwatch_reset(&st)
                time.stopwatch_start(&st) 

                glfw.PollEvents()
                gl.ClearColor(0.0, 0.0, 0.0, 1.0)
                gl.Clear(gl.COLOR_BUFFER_BIT)
                


                // This will use the current shader, so it must be set outside the render context. WITH the texture map.
                layer: ds.Layer = queue.back(&game_stack)
                if layer.update(layer.state, window, dt) == 1 {
                        layer.cleanup(layer.state)
                        queue.pop_back(&game_stack)
                }

                glfw.SwapBuffers((window))
        }

}

window_size_callback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
        WIDTH = f32(width)
        HEIGHT = f32(height)
}

frame_buffer_callback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
        WIDTH = f32(width)
        HEIGHT = f32(height)   
}
