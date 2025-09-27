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
        cleanup: proc(rawptr),
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

bm_search :: proc(pattern: string, text: string) -> [dynamic]int {
        //bad_table := make([dynamic][128]int, len(pattern))
        bad_table := make([dynamic]map[rune]int, len(pattern))
        defer delete(bad_table)
        char_idx := make(map[rune]int)
        for char, idx in pattern {
                char_idx[char] = idx
                // get all possible chars we could jump to and get the most recent version
                for cha2 in pattern {
                        bad_table[idx][cha2] = idx - char_idx[cha2]
                }
        }

        good_table := make([dynamic]int, len(pattern))
        defer delete(good_table)
        //#reverse for char, idx in pattern[len(pattern)/2:len(pattern)-1] {
        // idx is the index for the first mismatch
        for idx in 0..<len(pattern)-1 {
                suffix := pattern[idx+1:len(pattern)]
                // idx2 is the index we are saying we could shift to
                for idx2 := idx-1; idx2 >= 0; idx2-=1 {
                        if pattern[idx] != pattern[idx2] && string_cmp(pattern[idx2+1:idx2+1+len(suffix)], suffix) {
                                good_table[idx] = idx-idx2
                                break
                        }
                }
        }
        // search the actual text
        results := make([dynamic]int)
        i := len(pattern)-1
        for i < len(text) {
                j := 0
                should_skip := false
                for text[i-j] == pattern[len(pattern)-1-j] {
                        if j == len(pattern)-1 {
                                append(&results, i - len(pattern) + 1)
                                should_skip = true
                                break
                        }
                        j += 1
                } 
                if should_skip {
                        should_skip = false
                        i += 1
                        continue
                }
                bad_result := bad_table[len(pattern)-1-j][rune(text[i-j])]
                if bad_result == 0 {
                        bad_result = len(pattern)-j
                }
                i += max(good_table[len(pattern)-1-j], bad_result)
        }
        return results
}

string_cmp :: proc(a, b: string) -> bool {
        if len(a) != len(b) {
                return false
        }
        for i := 0; i < len(a); i+=1 {
                if a[i] != b[i] {
                        return false
                }
        }
        return true
}
