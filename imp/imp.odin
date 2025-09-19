package imp

import _t "../text"
import "../util"
import gl "vendor:OpenGL"
import "vendor:glfw"
import lin "core:math/linalg/glsl"
import "core:os"
import "core:fmt"
import "core:encoding/json"

chars_per_second :: 50.0
// TODO is imp just a fancy ui? 
// Still good to make it distinct I think
Imp :: struct {
        shader, text_shader, atlas, tex: u32,
        text: string,
        screen_width, screen_height: ^f32,
        VAO, VBO: u32,
        time: f64,
        time_to_speak: f64,
        chars_to_print: f64,
        col: [3]f32,
        chars: [128]_t.Character,
        active: bool,
        vecs: [dynamic]f32,
        text_vecs: [dynamic]f32,
        dialogue: map[string]([dynamic][2]string),
}

frames := [5][2]f32{
        {0.125, 0.000},
        {0.250, 0.125},
        {0.375, 0.250},
        {0.500, 0.375},
        {0.625, 0.500},
}

init_imp :: proc(shader, text_shader, atlas: u32, chars: [128]_t.Character, screen_width, screen_height: ^f32) -> ^Imp {
        imp := new(Imp)
        imp.shader = shader
        imp.text_shader = text_shader
        imp.atlas = atlas
        imp.screen_width = screen_width
        imp.screen_height = screen_height
        imp.vecs = make([dynamic]f32)
        imp.text_vecs = make([dynamic]f32)
        imp.active = true
        imp.tex = util.load_texture("../resources/imp.png")
        imp.col = {1.0, 0.5, 0.5}
        imp.chars = chars
        gl.GenVertexArrays(1, &imp.VAO)
        gl.GenBuffers(1, &imp.VBO)
        get_dialogue(&imp.dialogue, "../resources/dialogue.json")
        return imp
}

update :: proc(imp: ^Imp, window: glfw.WindowHandle, dt: f64) -> int {
        // todo add delta time to update call
        imp.time += dt
        imp.time_to_speak -= dt
        if int(imp.chars_to_print) < len(imp.text) {
                imp.chars_to_print += dt*chars_per_second
        }
        render(imp)
        return 0
}
 
render :: proc(imp: ^Imp) {
        scale: f32 = 140.0
        x: f32 = imp.screen_width^*0.80
        y: f32 = imp.screen_height^
        uv: [2]f32 = frames[int(imp.time*10) % 5]
        append(&imp.vecs, 
                x,              y,                 0.1,    imp.col.r, imp.col.g, imp.col.b,  uv[0], 0.0,
                x,              y - scale,         0.1,    imp.col.r, imp.col.g, imp.col.b,  uv[0], 0.25,
                x + scale,      y - scale,         0.1,    imp.col.r, imp.col.g, imp.col.b,  uv[1], 0.25,

                x,              y,                 0.1,    imp.col.r, imp.col.g, imp.col.b,  uv[0], 0.0,
                x + scale,      y - scale,         0.1,    imp.col.r, imp.col.g, imp.col.b,  uv[1], 0.25,
                x + scale,      y,                 0.1,    imp.col.r, imp.col.g, imp.col.b,  uv[1], 0.0,
        )
        if imp.time_to_speak > 0 {
                line_height: f32 = 25
                char_scale := _t.calc_char_scale(imp.chars, line_height)
                wraps := _t.wrap_lines(imp.text, imp.chars, 1.5*scale-20, char_scale)
                defer delete(wraps) 
                sub_wraps := make([dynamic]u32)
                fmt.println(len(sub_wraps))
                defer delete(sub_wraps)
                counter: f64 = 0
                for wrap in wraps {
                        to_add := min(wrap, u32(imp.chars_to_print-counter))
                        if to_add == 0 {
                                break
                        }
                        append(&sub_wraps, to_add)
                        counter += f64(to_add)
                        
                }
                box_depth: f32 = f32(len(sub_wraps))*line_height + 20.0
                append(&imp.vecs,
                        x-1.5*scale,    y-0.3*scale,            0.1,  1.0, 1.0, 1.0,  -1, -1,
                        x-1.5*scale,    y-0.3*scale-box_depth,  0.1,  1.0, 1.0, 1.0,  -1, -1,
                        x,              y-0.3*scale-box_depth,  0.1,  1.0, 1.0, 1.0,  -1, -1,

                        x-1.5*scale,    y-0.3*scale,            0.1,  1.0, 1.0, 1.0,  -1, -1,
                        x,              y-0.3*scale-box_depth,  0.1,  1.0, 1.0, 1.0,  -1, -1,
                        x,              y-0.3*scale,            0.1,  1.0, 1.0, 1.0,  -1, -1,

                        x+0.1*scale,    y-0.4*scale,            0.1,  1.0, 1.0, 1.0,  -1, -1,
                        x,              y-0.45*scale,           0.1,  1.0, 1.0, 1.0,  -1, -1,
                        x,              y-0.35*scale,           0.1,  1.0, 1.0, 1.0,  -1, -1,
                )
                _t.push_wrapped(imp.text[:int(imp.chars_to_print)], &imp.text_vecs, sub_wraps, imp.chars, x-1.5*scale+10, y-0.3*scale-10, line_height, {0,0.0,0})
        }
        
        gl.UseProgram(imp.shader)
        ortho: matrix[4,4]f32 = lin.mat4Ortho3d(0, imp.screen_width^, 0, imp.screen_height^, -1.0, 10.0);
        gl.UniformMatrix4fv(gl.GetUniformLocation(imp.shader, "projection"), 1, gl.FALSE, &ortho[0, 0]);
        gl.BindVertexArray(imp.VAO)
        gl.BindBuffer(gl.ARRAY_BUFFER, imp.VBO)  
        gl.BindTexture(gl.TEXTURE_2D, imp.tex)
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8*size_of(f32), uintptr(0))
        gl.EnableVertexAttribArray(0)
        gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8*size_of(f32), uintptr(3*size_of(f32)))
        gl.EnableVertexAttribArray(1)
        gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 8*size_of(f32), uintptr(6*size_of(f32)))
        gl.EnableVertexAttribArray(2)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(f32)*len(imp.vecs), rawptr(&imp.vecs[0]), gl.STATIC_DRAW)
        gl.DrawArrays(gl.TRIANGLES, 0, i32(len(imp.vecs) / 8))
        // Draw the text
        gl.UseProgram(imp.text_shader)
        gl.BindTexture(gl.TEXTURE_2D, imp.atlas)
        gl.UniformMatrix4fv(gl.GetUniformLocation(imp.text_shader, "projection"), 1, gl.FALSE, &ortho[0, 0]);
        _t.render(imp.text_vecs, imp.atlas, imp.VAO, imp.VBO)
        // Clear the data
        clear(&imp.vecs)
        clear(&imp.text_vecs)
}

get_dialogue :: proc(dialogue: ^map[string]([dynamic][2]string), path: string) {
        data, ok := os.read_entire_file_from_filename(path)
        if !ok {
                fmt.println("Failed to read", path)
                os.exit(1)
        }
        // Remember data must be alloced, since we are working with pointers
        defer delete(data)
        json_data, err := json.parse(data)
        if err != .None {
                fmt.println("Failed to parse", path)
                os.exit(1)
        }
        array := json_data.(json.Array)
        for val in array {
                obj := val.(json.Object)
                file_ref := obj["file_ref"].(json.String)
                dialogue[file_ref] = make([dynamic][2]string)
                for option in obj["options"].(json.Array) {
                        options := option.(json.Object)
                        append(&dialogue[obj["file_ref"].(json.String)], 
                        [2]string{options["input"].(json.String), options["response"].(json.String)})
                        fmt.println(dialogue[obj["file_ref"].(json.String)],)
                }
        }

}

add_text :: proc(imp: ^Imp, text: string) {
        imp.chars_to_print = 0
        imp.text = text
        imp.time_to_speak = f64(len(text)) / chars_per_second + 5.0
}