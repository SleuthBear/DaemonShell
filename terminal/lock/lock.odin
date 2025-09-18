package lock

import _t "../../text"
import _vfs "../../virtual_fs"
import "core:thread"
import "core:time"
import "core:strings"
import "base:runtime"
import "core:fmt"
import lin "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "vendor:glfw"

GREY :: [?]f32{0.7,0.7,0.7}
GREEN :: [?]f32{0.5,1.0,0.5}
RED :: [?]f32{1.0,0.5,0.5}

Lock_Config :: struct {
        hint, answer: string,
        shader, tex: u32,
        chars: [128]_t.Character,
        width, height: ^f32
}

Lock :: struct {
        node: ^_vfs.Node,
        shader, VAO, VBO, tex: u32,
        width, height: ^f32,
        hint, answer, input: string,
        active, should_close: bool,
        cursor: int,
        chars: [128]_t.Character,
        input_color: [3]f32,
        vecs: [dynamic]f32,
}

Lock_Info :: struct {
        hint, answer: string,
}

init_lock :: proc(config: Lock_Config, node: ^_vfs.Node) -> ^Lock {
        lock := new(Lock)
        lock.node = node
        lock.answer = config.answer
        lock.hint = config.hint
        lock.width = config.width
        lock.height = config.height
        lock.answer = config.answer
        lock.shader = config.shader
        lock.chars = config.chars
        lock.tex = config.tex
        lock.should_close = false
        lock.input_color = GREY
        gl.GenVertexArrays(1, &lock.VAO)
        gl.GenBuffers(1, &lock.VBO)
        lock.vecs = make([dynamic]f32)
        return lock
}

update :: proc(lock: rawptr, window: glfw.WindowHandle) -> int {
        lock := cast(^Lock)lock
        if !lock.active {
                glfw.SetWindowUserPointer(window, lock);
                glfw.SetCharCallback(window, char_callback);
                glfw.SetKeyCallback(window, key_callback)
                glfw.SetScrollCallback(window, nil);
                lock.active = true;
        }
        gl.UseProgram(lock.shader)
        gl.BindTexture(gl.TEXTURE_2D, lock.tex)
        ortho: matrix[4,4]f32 = lin.mat4Ortho3d(0, lock.width^, 0, lock.height^, -1.0, 10.0);
        gl.UniformMatrix4fv(gl.GetUniformLocation(lock.shader, "projection"), 1, gl.FALSE, &ortho[0, 0]);
        clear(&lock.vecs)
        _t.wrap_and_push(lock.hint, &lock.vecs, lock.chars, lock.width^*0.2, lock.height^*0.7, lock.width^*0.6, 30, GREY)
        _t.wrap_and_push(lock.input, &lock.vecs, lock.chars, lock.width^*0.2, lock.height^*0.3, lock.width^*0.6, 30, lock.input_color)
        _t.render(lock.vecs, lock.tex, lock.VAO, lock.VBO)
        if lock.should_close {
                return 1
        }
        return 0
}

// TODO center the text
render :: proc(lock: ^Lock) {
        gl.UseProgram(lock.shader)
        gl.BindTexture(gl.TEXTURE_2D, lock.tex)
        ortho: matrix[4,4]f32 = lin.mat4Ortho3d(0, lock.width^, 0, lock.height^, -1.0, 10.0);
        gl.UniformMatrix4fv(gl.GetUniformLocation(lock.shader, "projection"), 1, gl.FALSE, &ortho[0, 0]);
        clear(&lock.vecs)
        _t.wrap_and_push(lock.answer, &lock.vecs, lock.chars, lock.width^*0.2, lock.height^*0.7, lock.width^*0.6, 30, GREY)
        _t.wrap_and_push(lock.answer, &lock.vecs, lock.chars, lock.width^*0.2, lock.height^*0.3, lock.width^*0.6, 30, lock.input_color)
        _t.render(lock.vecs, lock.tex, lock.VAO, lock.VBO)
}

char_callback :: proc "c" (window: glfw.WindowHandle, code: rune) {
        lock: ^Lock = cast(^Lock)glfw.GetWindowUserPointer(window)
        context = runtime.default_context()
        bldr := strings.Builder{}
        strings.write_string(&bldr, lock.input[:lock.cursor])
        strings.write_rune(&bldr, code)
        strings.write_string(&bldr, lock.input[lock.cursor:])
        // free the old string
        delete(lock.input)
        // save the new string
        lock.input = strings.to_string(bldr)
        lock.cursor += 1
}

key_callback :: proc "c" (window: glfw.WindowHandle, key: i32, scancode: i32, action: i32, mods: i32) {
        lock: ^Lock = cast(^Lock)glfw.GetWindowUserPointer(window)
        context = runtime.default_context()
        if action != glfw.PRESS && action != glfw.REPEAT {
                return
        }
        switch key {
                case glfw.KEY_ENTER: {
                        // TODO locks opened saved
                        if (lock.input == lock.answer) {
                                lock.input_color = GREEN
                                delay_close(lock, 1000000000);
                        } else {
                                lock.input_color = RED
                                delay_color_change(lock, GREY, 1000000000);
                        }
                }
                case glfw.KEY_BACKSPACE: {
                        if len(lock.input) > 0 {
                                bldr := strings.Builder{}
                                strings.write_string(&bldr, lock.input[:lock.cursor-1])
                                strings.write_string(&bldr, lock.input[lock.cursor:])
                                delete(lock.input)
                                lock.input = strings.to_string(bldr)
                                lock.cursor -= 1
                        }
                }
                case glfw.KEY_LEFT: {
                        if lock.cursor > 0 {
                                lock.cursor -= 1
                        }
                }
                case glfw.KEY_RIGHT: {
                        if lock.cursor < len(lock.input) {
                                lock.cursor += 1
                        }
                }
        }
}

// TODO ask about this
delay_close :: proc(lock: ^Lock, ms: int) {
        Data :: struct {
                lock: ^Lock,
                ms: int,
        }
        data := new(Data)
        data.lock = lock
        data.ms = ms
        t1 := thread.create(proc(t: ^thread.Thread) {
                data := cast(^Data)t.data
                time.sleep(time.Duration(data.ms))
                data.lock.should_close = true
                free(t.data)
                thread.destroy(t)
        })
        t1.data = data
        thread.start(t1)
}

delay_color_change :: proc(lock: ^Lock, color: [3]f32, ms: int) {
        Data :: struct {
                lock: ^Lock,
                ms: int,
                color: [3]f32,
        }
        data := new(Data)
        data.lock = lock
        data.ms = ms
        data.color = color
        t1 := thread.create(proc(t: ^thread.Thread) {
                data := cast(^Data)t.data
                time.sleep(time.Duration(data.ms))
                data.lock.input_color = data.color 
                free(t.data)
                thread.destroy(t)
        })
        t1.data = data
        thread.start(t1)
}