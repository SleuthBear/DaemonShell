package ui

import "core:fmt"
import "core:os"
import gl "vendor:OpenGL"
import "vendor:glfw"
import lin "core:math/linalg/glsl"
import tr "../text_render"

UI :: struct {
        width, height: ^f32,
        vecs: [dynamic]f32,
        text_vecs: [dynamic]f32,
        shader, text_shader, VAO, VBO, atlas, tex: u32,
        layout: Layout,
        chars: [128]tr.Character,
        active: bool
}

Layout :: struct {
        row, col: int,
        col_width, row_height: f32,
        ys: []f32,
}

Bias :: enum {
        Center,
}

Button_Config :: struct {
        width, height: f32,
        color: [3]f32,
        border_color: [3]f32,
        border_width: f32,
        text_color: [3]f32,
        hover_color: [3]f32,
        bias: Bias
}

Image_Config :: struct {
        width, height: f32,
        color: [3]f32,
        uv_top_left: [2]f32,
        uv_bottom_right: [2]f32,
}

UI_Config :: struct {
        layout: Layout,
        width, height: ^f32,
        shader, text_shader, atlas, tex: u32,
        chars: [128]tr.Character,        
        use_shader, use_text_shader: bool,
}

init_ui :: proc(config: UI_Config) -> ^UI {
        ui := new(UI)
        // Use shaders if they are provided, otherwise make them yourself. u32 defaults to 0 and no default struct values,
        // so this is required.
        ok: bool
        if config.shader > 0 {
                ui.shader = config.shader
        } else {
                ui.shader, ok = gl.load_shaders_file("../shaders/ui.vert", "../shaders/ui.frag")
                if !ok {
                        fmt.println("Failed to create ui shader")
                        os.exit(1)
                } 
        }
        if config.text_shader > 0 {
                ui.text_shader = config.text_shader
        } else {
                ui.text_shader, ok = gl.load_shaders_file("../shaders/text.vert", "../shaders/text.frag")
                if !ok {
                        fmt.println("Failed to create ui text shader")
                        os.exit(1)
                }
        }
        ui.layout = config.layout
        ui.width = config.width
        ui.height = config.height
        ui.chars = config.chars
        ui.atlas = config.atlas
        ui.tex = config.tex
        ui.vecs = make([dynamic]f32)
        ui.text_vecs = make([dynamic]f32)
        ui.layout.row_height = ui.height^ / f32(ui.layout.row)
        ui.layout.col_width = ui.width^ / f32(ui.layout.col)
        ui.layout.ys = make([]f32, ui.layout.row * ui.layout.col)
        ui.active = true
        gl.GenVertexArrays(1, &ui.VAO)
        gl.GenBuffers(1, &ui.VBO)
        return ui
}

render :: proc(ui: ^UI) {
        // Draw the boxes
        gl.UseProgram(ui.shader)
        ortho: matrix[4,4]f32 = lin.mat4Ortho3d(0, ui.width^, 0, ui.height^, -1.0, 10.0);
        gl.UniformMatrix4fv(gl.GetUniformLocation(ui.shader, "projection"), 1, gl.FALSE, &ortho[0, 0]);
        gl.BindVertexArray(ui.VAO)
        gl.BindBuffer(gl.ARRAY_BUFFER, ui.VBO)  
        if ui.tex != 0 {
                gl.BindTexture(gl.TEXTURE_2D, ui.tex)
        }
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8*size_of(f32), uintptr(0))
        gl.EnableVertexAttribArray(0)
        gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8*size_of(f32), uintptr(3*size_of(f32)))
        gl.EnableVertexAttribArray(1)
        gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 8*size_of(f32), uintptr(6*size_of(f32)))
        gl.EnableVertexAttribArray(2)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(f32)*len(ui.vecs), rawptr(&ui.vecs[0]), gl.STATIC_DRAW)
        gl.DrawArrays(gl.TRIANGLES, 0, i32(len(ui.vecs) / 8))
        // Draw the text
        gl.UseProgram(ui.text_shader)
        gl.BindTexture(gl.TEXTURE_2D, ui.atlas)
        gl.UniformMatrix4fv(gl.GetUniformLocation(ui.text_shader, "projection"), 1, gl.FALSE, &ortho[0, 0]);
        tr.render(ui.text_vecs, ui.atlas, ui.VAO, ui.VBO)
        // Clear the data
        for i in 0..<len(ui.layout.ys) {
                ui.layout.ys[i] = 0
        }
        clear(&ui.vecs)
        clear(&ui.text_vecs)
}

button :: proc(window: glfw.WindowHandle, ui: ^UI, text: string, row: int, col: int, config: Button_Config) -> bool {
        left: f32
        switch config.bias {
                case Bias.Center: {
                        left = f32(col) * ui.layout.col_width + (ui.layout.col_width - config.width) / 2
                }
        }
        // Count from the bottom
        top: f32 = f32(row + 1) * ui.layout.row_height - ui.layout.ys[row*col + col]
        if config.border_width > 0 {
                bw := config.border_width
                append(&ui.vecs, 
                        left,                   top,                      -0.2, config.border_color.x, config.border_color.y, config.border_color.z,     -1, -1,
                        left,                   top-config.height,        -0.2, config.border_color.x, config.border_color.y, config.border_color.z,     -1, -1,
                        left+config.width,      top,                      -0.2, config.border_color.x, config.border_color.y, config.border_color.z,     -1, -1,
                        left+config.width,      top-config.height,        -0.2, config.border_color.x, config.border_color.y, config.border_color.z,     -1, -1,
                        left+config.width,      top,                      -0.2, config.border_color.x, config.border_color.y, config.border_color.z,     -1, -1,
                        left,                   top-config.height,        -0.2, config.border_color.x, config.border_color.y, config.border_color.z,     -1, -1,

                        left+bw,                   top-bw,                    -0.1, config.color.x, config.color.y, config.color.z,     -1, -1,
                        left+bw,                   top-config.height+bw,      -0.1, config.color.x, config.color.y, config.color.z,     -1, -1,
                        left+config.width - bw,    top-bw,                    -0.1, config.color.x, config.color.y, config.color.z,     -1, -1,
                        left+config.width - bw,    top-config.height+bw,      -0.1, config.color.x, config.color.y, config.color.z,     -1, -1,
                        left+config.width - bw,    top-bw,                    -0.1, config.color.x, config.color.y, config.color.z,     -1, -1,
                        left+bw,                   top-config.height+bw,      -0.1, config.color.x, config.color.y, config.color.z,     -1, -1,
        )
        } else {
                append(&ui.vecs, 
                        left,                   top,                      -0.1, config.color.x, config.color.y, config.color.z,     -1, -1,
                        left,                   top-config.height,        -0.1, config.color.x, config.color.y, config.color.z,     -1, -1,
                        left+config.width,      top,                      -0.1, config.color.x, config.color.y, config.color.z,     -1, -1,
                        left+config.width,      top-config.height,        -0.1, config.color.x, config.color.y, config.color.z,     -1, -1,
                        left+config.width,      top,                      -0.1, config.color.x, config.color.y, config.color.z,     -1, -1,
                        left,                   top-config.height,        -0.1, config.color.x, config.color.y, config.color.z,     -1, -1,
                )
        }
        // Push the text vectors
        text_width := config.width-20-config.border_width*2
        text_height := config.height-20-config.border_width*2
        text_left := left + config.border_width + 10
        text_top := top - config.border_width - 10
        tr.wrap_center_and_push(text, &ui.text_vecs, ui.chars, text_left, text_top, text_width, text_height, config.text_color)
        
        ui.layout.ys[row*col+col] += config.height + 20
        if glfw.GetMouseButton(window, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS {
                x, y := glfw.GetCursorPos(window)
                y = f64(ui.height^) - y
                if f64(left) < x && x < f64(left+config.width) && y < f64(top) && f64(top-config.height) < y {
                        return true
                }
        }
        return false
}

// TODO make this cleaner?
image :: proc(ui: ^UI, x, y: f32, config: Image_Config) {
        append(&ui.vecs,
                        x,                   y,                      -0.1, config.color.x, config.color.y, config.color.z,     config.uv_top_left.x,      config.uv_top_left.y,
                        x,                   y-config.height,        -0.1, config.color.x, config.color.y, config.color.z,     config.uv_top_left.x,      config.uv_bottom_right.y,
                        x+config.width,      y,                      -0.1, config.color.x, config.color.y, config.color.z,     config.uv_bottom_right.x,  config.uv_top_left.y,
                        x+config.width,      y-config.height,        -0.1, config.color.x, config.color.y, config.color.z,     config.uv_bottom_right.x,  config.uv_bottom_right.y,
                        x+config.width,      y,                      -0.1, config.color.x, config.color.y, config.color.z,     config.uv_bottom_right.x,  config.uv_top_left.y,
                        x,                   y-config.height,        -0.1, config.color.x, config.color.y, config.color.z,     config.uv_top_left.x,      config.uv_bottom_right.y,
                )
}

update_layout :: proc(ui: ^UI) {
        ui.layout.row_height = ui.height^ / f32(ui.layout.row)
        ui.layout.col_width = ui.width^ / f32(ui.layout.col)
        ui.layout.ys = make([]f32, ui.layout.row * ui.layout.col)
}

cleanup :: proc(ui: ^UI) {
        delete(ui.vecs)
        delete(ui.text_vecs)
        free(ui)
}