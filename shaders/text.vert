

#version 330 core
layout (location = 0) in vec2 pos;
layout (location = 1) in vec2 tex_pos;
layout (location = 2) in vec3 col;
out vec2 TexCoords;
out vec3 FragColor;

uniform mat4 projection;

void main()
{
    gl_Position = projection * vec4(pos, 0.0, 1.0);
    TexCoords = tex_pos;
    FragColor = col;
}

