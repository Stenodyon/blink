#version 330 core

in vec2 texture_uv;

//uniform sampler2D atlas;

out vec4 outColor;

void main() {
    //outColor = texture(atlas, texture_uv);
    outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
 
