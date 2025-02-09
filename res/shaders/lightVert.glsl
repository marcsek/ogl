#version 410 core

layout(location = 0) in vec4 position;
layout(location = 1) in vec3 normal;

out vec3 v_Normal;
out vec3 v_FragPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main() {
    gl_Position = projection * view * model * position;
    v_FragPos = vec3(view * model * position);
    v_Normal = mat3(transpose(inverse(view * model))) * normal;
};
