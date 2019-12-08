#version 330 core

in vec2 uv;

uniform float transparency;
uniform sampler2D atlas;

out vec4 outColor;

void main() {
    vec4 color = texture(atlas, uv);
    color.a *= 1.0 - transparency;
    outColor = color;
}
 
