package terminal 

import "core:fmt"
import "core:os"
import "base:runtime"
import _t "../text"
import _vfs "../virtual_fs"
import _m "../menu"
// todo consolidate
import "../util"
// todo consolidate
import _l "lock"
import _sl "lock/saved_locks"
import _imp "../imp"
import gl "vendor:OpenGL"
import "vendor:glfw"
import lin "core:math/linalg/glsl"
import "core:strings"
import "core:container/queue"

MAX_LINES :: 200
RED :: [?]f32{1.0, 0.5, 0.5}
WHITE :: [?]f32{1.0,1.0,1.0}
GREY :: [?]f32{0.7,0.7,0.7}
BLUE :: [?]f32{0.5,0.5,1.0}
GREEN :: [?]f32{0.5,1.0,0.5}

Terminal :: struct {
        VAO, VBO: u32,
        vecs: [dynamic]f32,
        width, height: ^f32,
        cursor: int,
        chars: [128]_t.Character,
        lines: [MAX_LINES]Line,
        input: string,
        end, start, window: i32,
        active: bool,
        tex: u32,
        shader: u32,
        vis_shader: u32,
        node: ^_vfs.Node,
        game_stack: ^queue.Queue(util.Layer),
        imp: ^_imp.Imp,
}

Line :: struct {
        txt: string,
        col: [3]f32,
        side: Side
}

Side :: enum {
        SYS,
        USER,
}

init_terminal :: proc(_width: ^f32, _height: ^f32, _shader: u32, _vis_shader: u32, _game_stack: ^queue.Queue(util.Layer)) -> Terminal {
        
        term := Terminal{
               width = _width,
               height = _height,
               cursor = 0,
               end = 0,
               start = 1,
               window = 1,
               shader = _shader,
               vis_shader = _vis_shader,
               game_stack = _game_stack,
        }
        term.lines[1] = {"", WHITE, Side.USER}
        gl.GenVertexArrays(1, &term.VAO)
        gl.GenBuffers(1, &term.VBO)
        _t.create_bitmap("../resources/ModernDOS.ttf", &term.tex, &term.chars)
        term.node = _vfs.read_system("../resources/root.json")
        return term 
}

update :: proc(term: rawptr, window: glfw.WindowHandle, dt: f64) -> int {
        term := cast(^Terminal)term
        if !term.active {
                glfw.SetWindowUserPointer(window, term)
                glfw.SetCharCallback(window, char_callback)
                glfw.SetKeyCallback(window, key_callback)
                glfw.SetScrollCallback(window, nil)
                glfw.SetMouseButtonCallback(window, nil)
                term.active = true
        }
        gl.UseProgram(term.shader)
        gl.BindTexture(gl.TEXTURE_2D, term.tex)
        ortho: matrix[4,4]f32 = lin.mat4Ortho3d(0, term.width^, 0, term.height^, -1.0, 10.0);
        gl.UniformMatrix4fv(gl.GetUniformLocation(term.shader, "projection"), 1, gl.FALSE, &ortho[0, 0]);
        clear(&term.vecs)
        push_lines(term)
        _t.render(term.vecs, term.tex, term.VAO, term.VBO)
        _imp.update(term.imp, window, dt)
        return 0 
}

//todo add dynamic text scale
push_lines :: proc(term: ^Terminal) {
        // todo calculate line height here and pass it
        line_height: f32 = 25
        scale := _t.calc_char_scale(term.chars, line_height)
        printed_lines: int = 0
        for i: i32 = 0; printed_lines < int(term.height^ / line_height); i+=1 {
                if i == -1 {
                        i = MAX_LINES - 1
                }
                line := term.lines[term.window-i]
                to_display: string;
                defer delete(to_display)
                if (line.side == Side.USER) {
                        to_display = strings.concatenate({"> ", line.txt})
                } else {
                        to_display = strings.clone(line.txt)
                }
                if (term.window-i == term.start) {
                        if (len(to_display) < int(term.cursor+2)) {
                                to_display = strings.concatenate({to_display, "|"})
                        } else {
                                to_display = strings.concatenate(
                                                {to_display[0:term.cursor+2], 
                                                "|", 
                                                to_display[term.cursor+2:]
                                                })
                        }
                }
                wraps := _t.wrap_lines(to_display, term.chars, term.width^-30, scale)
                defer delete(wraps)
                printed_lines += len(wraps)
                // todo repace with line height 
                line_y: f32 = f32(printed_lines) * line_height
                _t.push_wrapped(to_display, &term.vecs, wraps, term.chars, 15, line_y, line_height, line.col)
                if term.window-i == term.end {
                        break
                }
        }
}

add_line :: proc(term: ^Terminal, line: Line) {
        // if end != start then buffer hasn't been filled.
        // todo lookback buffer
        if (term.end != term.start) {
                if (term.start == MAX_LINES - 1) {
                        term.start = 0
                        delete(term.lines[term.start].txt)
                        term.lines[term.start] = line
                } else {
                        term.start += 1
                        delete(term.lines[term.start].txt)
                        term.lines[term.start] = line
                }
        } else {
                term.start += 1
                delete(term.lines[term.start].txt)
                term.lines[term.start] = line
                term.end += 1
        }
        term.window = term.start
}

// Callback Functions
// TODO this whole thing feels crappy. I get that the performance impact is negligible, but it's an unecessary allocation'
// maybe just assign 1000 chars of capacity up front? Not sure how to do that with a backing array.
char_callback :: proc "c" (window: glfw.WindowHandle, code: rune) {
        term: ^Terminal = cast(^Terminal)glfw.GetWindowUserPointer(window)
        context = runtime.default_context()
        txt := term.lines[term.start].txt
        bldr := strings.Builder{}
        strings.write_string(&bldr, txt[:term.cursor])
        strings.write_rune(&bldr, code)
        strings.write_string(&bldr, txt[term.cursor:])
        // free the old string
        delete(term.lines[term.start].txt)
        // save the new string
        term.lines[term.start].txt = strings.to_string(bldr)
        term.window = term.start
        term.cursor += 1
}

key_callback :: proc "c" (window: glfw.WindowHandle, key: i32, scancode: i32, action: i32, mods: i32) {
        term: ^Terminal = cast(^Terminal)glfw.GetWindowUserPointer(window)
        context = runtime.default_context()
        if action != glfw.PRESS && action != glfw.REPEAT {
                return
        }
        switch key {
                case glfw.KEY_ESCAPE: {
                        pause_menu := _m.init_pause_menu(term.width, term.height, term.shader, term.vis_shader, term.chars, term.tex)
                        queue.push_back(term.game_stack, util.Layer{pause_menu, _m.update_pause_menu})
                }
                case glfw.KEY_ENTER: {
                        line_txt := term.lines[term.start].txt
                        if (len(line_txt) > 0) {
                                term.cursor = 0;
                                read_command(term, line_txt)
                                add_line(term, {"", WHITE, Side.USER});
                        }
                }
                case glfw.KEY_TAB: {
                        auto_complete(term)
                }
                case glfw.KEY_BACKSPACE: {
                        txt := term.lines[term.start].txt
                        if len(term.lines[term.start].txt) > 0 {
                                bldr := strings.Builder{}
                                strings.write_string(&bldr, txt[:term.cursor-1])
                                strings.write_string(&bldr, txt[term.cursor:])
                                delete(txt)
                                term.lines[term.start].txt = strings.to_string(bldr)
                                term.cursor -= 1
                        }
                }
                case glfw.KEY_LEFT: {
                        if term.cursor > 0 {
                                term.cursor -= 1
                        }
                }
                case glfw.KEY_RIGHT: {
                        if term.cursor < len(term.lines[term.start].txt) {
                                term.cursor += 1
                        }
                }
        }
}

auto_complete :: proc(term: ^Terminal) {
        i := int(term.cursor) - 1
        // Step back until we find the start of the word
        for i>=0 && term.lines[term.start].txt[i] != ' ' {
                i -= 1
        }
        to_complete: string = term.lines[term.start].txt[i+1:term.cursor]
        // Step back until we find the section that defines a path
        i = len(to_complete) - 1
        for i>=0 && to_complete[i] != '/' {
                i-=1
        }
        pos: ^_vfs.Node = _vfs.follow_path(term.node, to_complete[:i+1])
        if pos == nil {
                return
        }
        to_search: string = to_complete[i+1:]
        valid_names := make([dynamic]string)
        defer delete(valid_names)
        for child in pos.children {
                if strings.has_prefix(child.name, to_search) {
                        append(&valid_names, child.name)
                }
        }
        if len(valid_names) == 0 {
                return
        }
        completion := strings.Builder{}
        strings.write_string(&completion, term.lines[term.start].txt[0:term.cursor]) 
        if len(valid_names) == 1 {
                strings.write_string(&completion, valid_names[0][len(to_search):])
                strings.write_string(&completion, term.lines[term.start].txt[term.cursor:])
                delete(term.lines[term.start].txt)
                term.lines[term.start].txt = strings.to_string(completion)
                term.cursor = len(term.lines[term.start].txt)
                return
        }
        outer:
        for i in len(to_search)..<len(valid_names[0]) {
                for name in valid_names {
                        if name[i] != valid_names[0][i] {
                                break outer
                        }
                }
                strings.write_rune(&completion, rune(valid_names[0][i]))
        }
        strings.write_string(&completion, term.lines[term.start].txt[term.cursor:])
        delete(term.lines[term.start].txt)
        term.lines[term.start].txt = strings.to_string(completion)
        return
}

read_command :: proc(term: ^Terminal, command: string) {
        file_ref := term.node.file_ref
        dialogue := term.imp.dialogue
        if dialogue[file_ref] != nil {
                for option in dialogue[file_ref] {
                        if command == option[0] {
                                _imp.add_text(term.imp, option[1])
                        }
                }
        }
        args := strings.split(command, " ");
        defer delete(args)
        // TODO dialogue
        if len(args) == 0 {
                return
        }
        switch args[0] {
                case "ls": {
                        if len(args) == 1 {
                                ls(term, "")
                                return
                        }
                        ls(term, args[1])
                }
                case "cd": {
                        if len(args) == 1 {
                                add_line(term, {strings.clone("Invalid file target"), RED, Side.SYS})
                                return
                        } 
                        cd(term, args[1])
                }
                case "cat": {
                        if len(args) == 1 {
                                add_line(term, {strings.clone("Specify a file."), RED, Side.SYS})
                                return
                        }
                        cat(term, args[1])
                }
        }
        return
}

ls :: proc(term: ^Terminal, path: string) {
        node: ^_vfs.Node = _vfs.follow_path(term.node, path)
        if node == nil {
                // note to self: strings.clone ensures heap allocation. Otherwise it can be overwritten and deleting causes issues
                add_line(term, {strings.clone("Invalid path."), RED, Side.SYS})
                return
        }
        if node.name != term.node.name && strings.contains(node.name, ".lock") {
                msg: string = strings.concatenate({"must unlock", node.name})
                add_line(term, {msg, RED, Side.SYS}, )
        }
        response_bldr: strings.Builder = strings.Builder{}
        for child in node.children {
                strings.write_string(&response_bldr, child.name)
                strings.write_string(&response_bldr, "  ")
        }
        add_line(term, {strings.to_string(response_bldr), BLUE, Side.SYS})
}

cd :: proc(term: ^Terminal, path: string) {
        node: ^_vfs.Node = _vfs.follow_path(term.node, path)
        if node == nil {
                add_line(term, {strings.clone("Invalid path."), RED, Side.SYS})
                return
        }
        if strings.contains(node.name, ".lock") {
                info := _sl.locks[node.file_ref]
                config := _l.Lock_Config{
                        hint = info.hint,
                        answer = info.answer,
                        shader = term.shader,
                        tex = term.tex,
                        chars = term.chars,
                        width = term.width,
                        height = term.height,
                }
                lock := _l.init_lock(config, node)
                queue.push_back(term.game_stack, util.Layer{lock, _l.update}) 
                term.active = false
        }
        if term.imp.dialogue[node.file_ref] != nil {
                to_say := term.imp.dialogue[node.file_ref][0][1]
                if to_say != "" {
                        _imp.add_text(term.imp, to_say)
                }
        }
        term.node = node
}

cat :: proc(term: ^Terminal, path: string) {
        pos: ^_vfs.Node = _vfs.follow_path(term.node, path)
        if pos == nil {
                add_line(term, {strings.clone("Invalid path."), RED, Side.SYS})
                return
        }
        if pos.type != _vfs.File_Type.FILE {
                add_line(term, {strings.clone("Not a file."), RED, Side.SYS})
                return
        }
        file_path := strings.concatenate({"files/", pos.file_ref})
        defer delete(file_path)
        file_contents, ok := os.read_entire_file_from_filename(file_path)
        builder := strings.Builder{}
        strings.write_bytes(&builder, file_contents)
        if !ok {
                add_line(term, {strings.clone("Unable to open file."), RED, Side.SYS})
                return
        }
        add_line(term, {strings.to_string(builder), GREY, Side.SYS})
}