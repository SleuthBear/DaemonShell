package menu

import "../../ui"
import _t "../../text"
import "core:strings"
import "vendor:glfw"
import "vendor:stb/image"
import "../../util"

init_main_menu :: proc(_width: ^f32, _height: ^f32, _text_shader: u32, _chars: [128]_t.Character, _atlas: u32) -> ^ui.UI {
        layout := ui.Layout{
                row = 4,
                col = 1
        }
        ui_config := ui.UI_Config{
                width = _width,
                height = _height,
                layout = layout,
                text_shader = _text_shader,
                use_text_shader = true,
                chars = _chars,
                atlas = _atlas,
                tex = util.load_texture("../resources/main_menu.png"),
                
        }
        return ui.init_ui(ui_config)
}

menu_button_config :: ui.Button_Config{
        width = 200,
        height = 100,
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

update_main_menu :: proc(menu: rawptr, window: glfw.WindowHandle) -> int {
        menu := cast(^ui.UI)menu
        if !menu.active {
                glfw.SetWindowUserPointer(window, menu)
                glfw.SetCharCallback(window, nil)
                glfw.SetKeyCallback(window, nil)
                glfw.SetScrollCallback(window, nil)
                glfw.SetMouseButtonCallback(window, nil)
                menu.active = true
        }
        ui.image(menu, menu.width^ / 2 - 300, menu.height^-20, title_image_config)
        if ui.button(window, menu, "NEW GAME", 1, 0, menu_button_config) {
                return 1
        }
        if ui.button(window, menu, "EXIT", 1, 0, menu_button_config) {
                glfw.SetWindowShouldClose(window, true)
        }
        // need a way to render a sprite. I can use a sprite shader, which I will probably need for the imp
        // so probably worth making one. 
        ui.render(menu)
        return 0 
}