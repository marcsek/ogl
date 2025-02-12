#version 410 core

layout(location = 0) out vec4 color;

in vec3 v_Normal;
in vec3 v_FragPos;
in vec2 v_TexCoords;

struct Material {
    sampler2D diffuse;
    sampler2D specular;
    sampler2D emission;
    float shininess;
}; 

struct Light {
    vec3 position;
  
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    float constant;
    float linear;
    float quadratic;
};

uniform Light light;
uniform Material material;
uniform vec3 viewPos;

void main() {
    vec3 ambient = light.ambient * vec3(texture(material.diffuse, v_TexCoords));

    vec3 norm = normalize(v_Normal);
    vec3 lightDir = normalize(light.position - v_FragPos);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = light.diffuse * diff * vec3(texture(material.diffuse, v_TexCoords));

    vec3 viewDir = normalize(-v_FragPos);
    vec3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    vec3 specular = light.specular * spec * vec3(texture(material.specular, v_TexCoords));

    vec3 emission = vec3(texture(material.emission, v_TexCoords)) * spec;
    if(vec3(texture(material.specular, v_TexCoords)).r != 0.0) {
        emission = vec3(0.0);
    }

    float distance = length(light.position - v_FragPos);
    float attenuation = 1.0 / (light.constant + light.linear + light.quadratic * pow(distance, 2));

    color = vec4((attenuation * (ambient + diffuse + specular) + emission), 1.0);
};

