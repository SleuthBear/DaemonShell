
package main
import "core:fmt"
import "core:c"

import gl "vendor:OpenGL"
import "vendor:glfw"
import _t "text"
import _tml "terminal"

GL_MAJOR_VERSION : c.int : 3
GL_MINOR_VERSION :: 3
WIDTH: f32 = 800
HEIGHT: f32 = 600

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


        window := glfw.CreateWindow(i32(WIDTH), i32(HEIGHT), "Odin Shell", nil, nil)
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
        shade, shade_ok := gl.load_shaders_file("../shaders/text.vert", "../shaders/text.frag")
        terminal := _tml.init_terminal(&WIDTH, &HEIGHT, shade)

        
        for !glfw.WindowShouldClose(window) {
                glfw.PollEvents()
                gl.ClearColor(0.0, 0.0, 0.0, 1.0)
                gl.Clear(gl.COLOR_BUFFER_BIT)
                
                // This will use the current shader, so it must be set outside the render context. WITH the texture map.
                _tml.update(&terminal, window)
                
                glfw.SwapBuffers((window))
        }
}

window_size_callback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
    WIDTH = f32(width)
    HEIGHT = f32(height)
}