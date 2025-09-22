package daemonshell

import "../ui"
import tr "../text_render"
import "core:strings"
import "core:os"
import "core:fmt"
import "core:slice"
import "vendor:glfw"
import "vendor:stb/image"

Main_Menu :: struct {
        term: ^Terminal,
        ui: ^ui.UI
}
init_main_menu :: proc(_width: ^f32, _height: ^f32, _text_shader: u32, _shader: u32, _chars: [128]tr.Character, _atlas: u32, term: ^Terminal) -> ^Main_Menu {
        layout := ui.Layout{
                row = 4,
                col = 1
        }
        ui_config := ui.UI_Config{
                width = _width,
                height = _height,
                layout = layout,
                text_shader = _text_shader,
                shader = _shader,
                use_text_shader = true,
                use_shader = true,
                chars = _chars,
                atlas = _atlas,
                tex = load_texture("resources/main_menu.png"),
        }
        menu := new(Main_Menu)
        menu.ui = ui.init_ui(ui_config)
        menu.term = term
        return menu
}

menu_button_config :: ui.Button_Config{
        width = 200,
        height = 75,
        color = {0.0, 0.0, 0.0},
        border_color = {0.9, 0.3, 0.3},
        text_color = {0.9,0.3,0.3},
        border_width = 5,
        bias = ui.Bias.Center,
}

title_image_config :: ui.Image_Config{
        width = 600,
        height = 200,
        color = {1.0, 1.0, 1.0},
        uv_top_left = {0, 0},
        uv_bottom_right = {0.318, 0.240},
}

update_main_menu :: proc(menu: rawptr, window: glfw.WindowHandle, dt: f64) -> int {
        menu := cast(^Main_Menu)menu
        if !menu.ui.active {
                glfw.SetWindowUserPointer(window, menu)
                glfw.SetCharCallback(window, nil)
                glfw.SetKeyCallback(window, nil)
                glfw.SetScrollCallback(window, nil)
                glfw.SetMouseButtonCallback(window, nil)
                menu.ui.active = true
        }
        ui.update_layout(menu.ui)
        ui.image(menu.ui, menu.ui.width^ / 2.0 - 300, menu.ui.height^-20, title_image_config)
        if ui.button(window, menu.ui, "NEW GAME", 1, 0, menu_button_config) {
                return 1
        }
        if ui.button(window, menu.ui, "LOAD GAME", 1, 0, menu_button_config) {
                load_game(menu.term)
                return 1
        }
        if ui.button(window, menu.ui, "EXIT", 1, 0, menu_button_config) {
                glfw.SetWindowShouldClose(window, true)
        }
        ui.render(menu.ui)
        return 0 
}

cleanup_main_menu :: proc(menu: rawptr) {
        menu := cast(^Main_Menu)menu
        ui.cleanup(menu.ui)
        free(menu)
}

Pause_Menu :: struct {
        node: ^Node,
        ui: ^ui.UI
}

init_pause_menu :: proc(_width: ^f32, _height: ^f32, _text_shader: u32, _shader: u32, _chars: [128]tr.Character, _atlas: u32, node: ^Node) -> ^Pause_Menu {
        layout := ui.Layout{
                row = 4,
                col = 1
        }
        ui_config := ui.UI_Config{
                width = _width,
                height = _height,
                layout = layout,
                text_shader = _text_shader,
                shader = _shader,
                use_text_shader = true,
                use_shader = true,
                chars = _chars,
                atlas = _atlas,
        }
        menu := new(Pause_Menu)
        menu.node = node
        menu.ui = ui.init_ui(ui_config)
        return menu
}

update_pause_menu :: proc(menu: rawptr, window: glfw.WindowHandle, dt: f64) -> int {
        menu := cast(^Pause_Menu)menu
        if !menu.ui.active {
                glfw.SetWindowUserPointer(window, menu)
                glfw.SetCharCallback(window, nil)
                glfw.SetKeyCallback(window, nil)
                glfw.SetScrollCallback(window, nil)
                glfw.SetMouseButtonCallback(window, nil)
                menu.ui.active = true
        }
        ui.update_layout(menu.ui)
        if ui.button(window, menu.ui, "CONTINUE", 2, 0, menu_button_config) {
                return 1
        }
        if ui.button(window, menu.ui, "SAVE", 2, 0, menu_button_config) {
                save_game(menu.node)
                return 1
        }
        if ui.button(window, menu.ui, "EXIT", 2, 0, menu_button_config) {
                glfw.SetWindowShouldClose(window, true)
                return 1
        }
        ui.render(menu.ui)
        return 0 
}

cleanup_pause_menu :: proc(menu: rawptr) {
        menu := cast(^Pause_Menu)menu
        ui.cleanup(menu.ui)
        free(menu)
}

save_game :: proc(node: ^Node) {
        pos := node
        names := make([dynamic]string)
        defer delete(names)
        for pos != nil {
                append(&names, pos.name)
                pos = pos.parent
        } 
        if len(names) <= 1 {
                return
        }
        slice.reverse(names[:])
        path := strings.join(names[1:], "/")
        defer delete(path)
        if !os.write_entire_file("resources/save/path.txt", transmute([]u8)path) {
                fmt.println("Failed to save path")
        }
}

load_game ::proc(term: ^Terminal) {
        path, ok := os.read_entire_file_from_filename("resources/save/path.txt")
        term.node = follow_path(term.node, string(path))
}