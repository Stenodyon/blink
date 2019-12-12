#version 330 core

in vec2 uv;

uniform float transparency;
uniform sampler2D atlas;

void main() {
    vec4 color = texture(atlas, uv);
    color.a *= 1.0 - transparency;
    gl_FragColor = color;
}
 
