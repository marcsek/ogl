#version 410 core

layout(location = 0) out vec4 color;

in vec2 v_TexCoord;

struct Material {
    sampler2D diffuse;
    sampler2D specular;
    sampler2D emission;
    float shininess;
}; 

uniform Material material;

void main() {
    vec4 texColor = texture(material.diffuse, v_TexCoord);
    color = texColor;
};
