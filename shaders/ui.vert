#version 330 core
layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 col;
layout (location = 2) in vec2 tex_pos;
out vec3 frag_color;
out vec2 tex_coords;
uniform mat4 projection;

void main()
{
        gl_Position = projection * vec4(pos, 1.0);
        tex_coords = tex_pos;
        frag_color = col;
}

