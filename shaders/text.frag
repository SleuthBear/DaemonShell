

#version 330 core
in vec2 TexCoords;
in vec3 FragColor;
out vec4 color;

uniform sampler2D atlas;

void main()
{
    vec4 sampled = vec4(1.0, 1.0, 1.0, texture(atlas, TexCoords).r);
    color = vec4(FragColor, 1.0) * sampled;
}
