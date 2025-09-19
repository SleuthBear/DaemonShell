#version 330 core
in vec3 frag_color;
in vec2 tex_coords;
out vec4 color;

uniform sampler2D tex;

void main()
{
        // -1 means no texture
        if (tex_coords.x < 0) {
                color = vec4(frag_color, 1.0);
        } else {
                color = vec4(frag_color, 1.0) * texture(tex, tex_coords).rgba;
        }

}
