package daemonshell

import "vendor:glfw"
import gl "vendor:OpenGL"
import "vendor:stb/image"
import "core:strings"
import "core:fmt"
import "core:os"

// TODO add cleanup
Layer :: struct {
        state: rawptr,
        update: proc(rawptr, glfw.WindowHandle, f64) -> int,
}

load_texture :: proc(path: string) -> u32 {
        path, error := strings.clone_to_cstring(path)
        defer delete(path)
        tex_width, tex_height, components: i32
        tex_data := image.load(path, &tex_width, &tex_height, &components, 0)
        defer image.image_free(tex_data)
        if tex_data != nil {
                format: u32
                if components == 1 {
                    format = gl.RED;
                } else if components == 3 {
                    format = gl.RGB;
                } else if components == 4 {
                    format = gl.RGBA;
                }

                tex_id: u32
                gl.GenTextures(1, &tex_id)
                gl.BindTexture(gl.TEXTURE_2D, tex_id);
                gl.TexImage2D(gl.TEXTURE_2D, 0, i32(format), tex_width, tex_height, 0, format, gl.UNSIGNED_BYTE, tex_data);
                gl.GenerateMipmap(gl.TEXTURE_2D);

                gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
                gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
                gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
                gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
                return tex_id
        }
        fmt.println("Failed to load texture", path)
        return 0
}