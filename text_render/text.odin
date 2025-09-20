package text_render

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:mem"
import "core:strings"
import gl "vendor:OpenGL"
import ft "../include/freetype"
import stb "vendor:stb/image"

Character :: struct {
        size: [2]f32,
        bearing: [2]f32,
        advance: i64,
        uv: [4]f32,
}

//TODO serialize the output to load later
create_bitmap :: proc(font_path: string, atlasTex: ^u32, chars: ^[128]Character) -> (u32) {
        c_path := strings.clone_to_cstring(font_path)
        lib: ft.Library
        if err := ft.init_free_type(&lib); err != nil {
                fmt.println("Failed to initialise freetype", err)
                os.exit(1)
        }       
        face: ft.Face
        if err := ft.new_face(lib, c_path, 0, &face); err != nil {
                fmt.println("Failed to create FT Face", err)
                os.exit(1)
        }  
        ft.set_pixel_sizes(face, 0, 48)
        gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
        if ft.load_char(face, 'W', {ft.Load_Flags.Render}) != nil {
                fmt.println("Failed to load glyph W")
                os.exit(1)
        }
        maxWidth: u32 = face.glyph.bitmap.width*2;
        maxHeight: u32 = face.glyph.bitmap.rows*2;
        atlas := make([]u8, 128*maxWidth*maxHeight*4)
        defer delete(atlas)
        atlasRow := maxWidth*128;
        count: u32 = 0;
        for c in 0..=127 {
                if ft.load_char(face, cast(u64)c, {ft.Load_Flags.Render}) != nil{
                        fmt.println("Failed to load glyph", rune(c))
                }
                ch: Character = {
                        {f32(face.glyph.bitmap.width), f32(face.glyph.bitmap.rows)},
                        {f32(face.glyph.bitmap_left), f32(face.glyph.bitmap_top)},
                        i64(face.glyph.advance.x),
                        {0,0,0,0}
                }
                pitch: u32 = u32(face.glyph.bitmap.pitch)
                for i: u32 = 0; i < u32(ch.size[1]); i+=1 {
                        for j: u32 = 0; j < u32(ch.size[0]); j+=1 {
                                // Monochrome, store in the red channel
                                atlas[(i*atlasRow+count*maxWidth+j)*4] = face.glyph.bitmap.buffer[(i*pitch)+j]
                                atlas[(i*atlasRow+count*maxWidth+j)*4+1] = 0
                                atlas[(i*atlasRow+count*maxWidth+j)*4+2] = 0
                                atlas[(i*atlasRow+count*maxWidth+j)*4+3] = 255
                        }
                }
                c_pos: f32 = f32(count) / 128.0
                ch.uv[0] = c_pos
                ch.uv[1] = c_pos + ch.size[0] / f32(atlasRow)
                ch.uv[2] = 0
                ch.uv[3] = ch.size[1] / f32(maxHeight)
                chars[c] =  ch
                count += 1
        }
        stb.write_jpg("bitmap.jpg", i32(atlasRow), i32(maxHeight), 4, rawptr(&atlas[0]), 100)
        ft.done_face(face)
        ft.done_free_type(lib)
        gl.GenTextures(1, atlasTex)
        gl.BindTexture(gl.TEXTURE_2D, atlasTex^);
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(atlasRow), i32(maxHeight),
             0, gl.RGBA, gl.UNSIGNED_BYTE, rawptr(&atlas[0]));
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.Flush();
        return 0
}

// TODO use indexes, not just a VBO
push_line :: proc(text: string, vecs: ^[dynamic]f32, chars: [128]Character, x: f32, y: f32, scale: f32, col: [3]f32) {
        x := x
        y := y - chars['X'].bearing[1] * scale
        for c in text {
                ch: Character
                if (c == '\n') {
                        ch = chars[' ']
                } else {
                        ch = chars[c]
                }
                x_pos: f32 = x + ch.bearing[0] * scale
                y_pos: f32 = y - (ch.size[1]-ch.bearing[1])*scale
                w: f32 = ch.size[0] * scale
                h: f32 = ch.size[1] * scale
                append(vecs,
                        x_pos,     y_pos + h,   ch.uv[0], ch.uv[2],  col[0], col[1], col[2],
                        x_pos,     y_pos,       ch.uv[0], ch.uv[3],  col[0], col[1], col[2],
                        x_pos + w, y_pos,       ch.uv[1], ch.uv[3],  col[0], col[1], col[2],

                        x_pos,     y_pos + h,   ch.uv[0], ch.uv[2],  col[0], col[1], col[2],
                        x_pos + w, y_pos,       ch.uv[1], ch.uv[3],  col[0], col[1], col[2],
                        x_pos + w, y_pos + h,   ch.uv[1], ch.uv[2],  col[0], col[1], col[2],
                )
                x += f32(ch.advance >> 6) * scale
        }
}

// Takes input text and wraps it vertically in the given width
// todo line height
wrap_and_push :: proc(text: string, vecs: ^[dynamic]f32, chars: [128]Character, x: f32, y: f32, width: f32, line_height: f32, col: [3]f32) {
        // Define the scale such that 1.2 * the height of '0' is a line
        scale := calc_char_scale(chars, line_height)
        wraps := wrap_lines(text, chars, width, scale)
        defer delete(wraps)
        idx: u32 = 0
        y_pos := y
        for line in wraps {
                push_line(text[idx:idx+line], vecs, chars, x, y_pos, scale, col)
                idx += line
                y_pos -= line_height
        }
}

push_wrapped :: proc(text: string, vecs: ^[dynamic]f32, wraps: [dynamic]u32, chars: [128]Character, x: f32, y: f32, line_height: f32,  col: [3]f32) {
        scale := calc_char_scale(chars, line_height)
        idx: u32 = 0
        y_pos := y
        for line in wraps {
                push_line(text[idx:idx+line], vecs, chars, x, y_pos, scale, col)
                idx += line
                y_pos -= line_height
        }
}

wrap_lines :: proc(text: string, chars: [128]Character, width: f32, scale: f32) -> [dynamic]u32 {
        line_end: u32 = 0
        line_start: u32 = 0
        x: f32 = 0
        wraps: [dynamic]u32
        word_width: f32 = 0
        i: u32 = 0
        for c in text {
                ch: Character
                if (c > 127) {
                        ch = chars[32]
                } else {
                        ch = chars[c]
                }
                if (c == ' ' || c == '\n') && i > 2 {
                        line_end = i
                        word_width = 0
                } else {
                        word_width += f32(ch.advance >> 6) * scale
                }
                x_pos: f32 = x + ch.bearing[0] * scale
                if x_pos >= width || (c == '\n' && int(i) != len(text)-1) {
                        if line_end == 0 {
                                append(&wraps, i-line_start)
                                line_start = i
                                x = 0     
                        } else {
                                append(&wraps, line_end-line_start+1)
                                line_start = line_end+1
                                x = word_width
                        }
                        line_end = 0
                }
                x += f32(ch.advance >> 6) * scale
                i += 1
        }
        append(&wraps, i - line_start)
        return wraps
}
// wraps the lines, returning the number of characters in each line, as well as the width of each line
wrap_lines_with_widths :: proc(text: string, chars: [128]Character, width: f32, scale: f32) -> ([dynamic]u32, [dynamic]f32) {
        line_end: u32 = 0
        line_start: u32 = 0
        x: f32 = 0
        wraps: [dynamic]u32
        widths: [dynamic]f32
        word_width: f32 = 0
        i: u32 = 0
        for c in text {
                ch: Character
                if (c > 127) {
                        ch = chars[32]
                } else {
                        ch = chars[c]
                }
                if (c == ' ' || c == '\n') && i > 2 {
                        line_end = i
                        word_width = 0
                } else {
                        word_width += f32(ch.advance >> 6) * scale
                }
                x_pos: f32 = x + ch.bearing[0] * scale
                if x_pos >= width || (c == '\n' && int(i) != len(text)-1) {
                        if line_end == 0 {
                                append(&wraps, i-line_start)
                                append(&widths, x)
                                line_start = i
                                x = 0     
                        } else {
                                append(&wraps, line_end-line_start+1)
                                append(&widths, x-word_width)
                                line_start = line_end+1
                                x = word_width
                        }
                        line_end = 0
                }
                x += f32(ch.advance >> 6) * scale
                i += 1
        }
        append(&wraps, i - line_start)
        append(&widths, x)
        return wraps, widths
}

calc_char_scale :: proc(chars: [128]Character, line_height: f32) -> f32 {
        char_height := chars['X'].size[1] // want char_height * scale = 0.8*line_height
        return line_height*0.5 / char_height
}

render :: proc(vecs: [dynamic]f32, atlas: u32, VAO: u32, VBO: u32) {
        if len(vecs) == 0 {
                return
        }
        gl.BindVertexArray(VAO)
        gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
        gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 7*size_of(f32), uintptr(0))
        gl.EnableVertexAttribArray(0)
        gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 7*size_of(f32), uintptr(2*size_of(f32)))
        gl.EnableVertexAttribArray(1)
        gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 7*size_of(f32), uintptr(4*size_of(f32)))
        gl.EnableVertexAttribArray(2)
        gl.BindTexture(gl.TEXTURE_2D, atlas)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(f32)*len(vecs), rawptr(&vecs[0]), gl.STATIC_DRAW)
        gl.DrawArrays(gl.TRIANGLES, 0, i32(len(vecs) / 7))
}

// Scales the text to fit inside a box with appropriate wrapping
wrap_center_and_push :: proc(text: string, vecs: ^[dynamic]f32, chars: [128]Character, x: f32, y: f32, width: f32, height: f32, col: [3]f32) {
        line_height := get_line_height(width, height, text, chars)
        scale := calc_char_scale(chars, line_height)
        wraps, widths := wrap_lines_with_widths(text, chars, width, scale)
        defer delete(wraps)
        defer delete(widths)
        idx: u32 = 0
        y_pos := y - (height - line_height*f32(len(wraps))) / 2
        i: u32 = 0
        for line in wraps {
                text_left := x + (width-widths[i])/2
                push_line(text[idx:idx+line], vecs, chars, text_left, y_pos, scale, col)
                idx += line
                y_pos -= line_height
                i += 1
        }
}

// TODO figure out a proper algorithm for this, without iterating line wraps, as that is slow
get_line_height :: proc(width: f32, height: f32, text: string, chars: [128]Character) -> f32 {
        w := f32(chars['X'].size.x)
        h := f32(chars['X'].size.y)
        scale: f32 = 1
        lh := h*scale/0.8
        n_lines := 1
        chars_per_line := len(text)
        for f32(n_lines) * lh > height || w * scale * f32(chars_per_line) > width {
                if w*scale*f32(chars_per_line) > width {
                        n_lines += 1
                        chars_per_line = len(text)/n_lines
                }     
                if lh*f32(n_lines) > height {
                        n_lines -= 1
                        scale -= 0.05
                }
                lh = h*scale/0.8
        }
        return lh*0.9
}