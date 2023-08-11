#include <iostream>
#include <vector>
#include <algorithm>
#define _USE_MATH_DEFINES
#include <cmath>
#include <sstream>
#include <fstream>
#include <random>
#include "vec.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION

#include "stb_image_write.h"

const int resolution = 128;

Vec2f Hammersley(uint32_t i, uint32_t N) { // 0-1
    uint32_t bits = (i << 16u) | (i >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    float rdi = float(bits) * 2.3283064365386963e-10;
    return {float(i) / float(N), rdi};
}

Vec3f ImportanceSampleGGX(Vec2f Xi, Vec3f N, float roughness) {
    float a = roughness * roughness;
    float x = Xi.x;
    float y = Xi.y;

    //TODO: in spherical space - Bonus 1
    // 
    // uniform circle
    float phi = 2.0 * M_PI * x;
    // the less the roughness, the more cosTheta close to 1, and theta to 0
    // so as roughness decrease, the point is more close to the sphere top
    float cosTheta = std::sqrt((1.0 - y) / (1.0 + (a*a - 1.0) * y));
    float sinTheta = std::sqrt(1.0 - cosTheta * cosTheta);

    //TODO: from spherical space to cartesian space - Bonus 1
    // 
    // half vector
    Vec3f H = {};
    const float r = 1.0;
    H.x = r * sinTheta * std::cos(phi);
    H.y = r * sinTheta * std::sin(phi);
    H.z = r * cosTheta;

    //TODO: tangent coordinates - Bonus 1
    // 
    // we need to generate a vector perpendicular to N as the tangent
    // so first choose a *random* vector which is not N itself
    Vec3f M = Vec3f(0.0, 1.0, 0.0);
    N = normalize(N);
    Vec3f T = normalize(cross(M, N));
    Vec3f B = normalize(cross(T, N));

    //TODO: transform H to tangent space - Bonus 1
    // 
    // This should be transform H to world space
    Vec3f worldH = T * H.x + B * H.y + N * H.z;
    return normalize(worldH);
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    // TODO: To calculate Schlick G1 here - Bonus 1
    // 
    // Do not use k formula from homework document!
    //float k = std::powf(roughness + 1.0, 2) / 8.0;
    // use this:
    float k = std::powf(roughness, 2) / 2.0;
    float g = NdotV / (NdotV * (1.0 - k) + k);
    return g;
}

float GeometrySmith(float roughness, float NoV, float NoL) {
    NoV = std::max(NoV, 0.0f);
    NoL = std::max(NoL, 0.0f);

    float ggx2 = GeometrySchlickGGX(NoV, roughness);
    float ggx1 = GeometrySchlickGGX(NoL, roughness);

    return ggx1 * ggx2;
}

Vec3f IntegrateBRDF(Vec3f V, float roughness) {

    const int sample_count = 1024;
    Vec3f N = Vec3f(0.0, 0.0, 1.0);

    float A = 0.0;
    float B = 0.0;

    for (int i = 0; i < sample_count; i++) {
        Vec2f Xi = Hammersley(i, sample_count);
        Vec3f H = ImportanceSampleGGX(Xi, N, roughness);
        Vec3f L = normalize(H * 2.0f * dot(V, H) - V);

        float NoL = std::max(L.z, 0.0f);
        float NoH = std::max(H.z, 0.0f);
        float VoH = std::max(dot(V, H), 0.0f);
        float NoV = std::max(dot(N, V), 0.0f);
        
        // TODO: To calculate (fr * ni) / p_o here - Bonus 1


        // Split Sum - Bonus 2
        if (NoL > 0.0)
        {
            float K = std::powf(1.0 - VoH, 5.0);
            float G = GeometrySmith(roughness, NoV, NoL);
            float G_weighted = (VoH * G) / (NoV * NoH);

            A += G_weighted * (1.0 - K);
            B += G_weighted * K;
        }
        
    }

    A = A / float(sample_count);
    B = B / float(sample_count);


    // This is split sum LUT
    // return Vec3f(A, B, 0.0);
    
    // suppose Fresnel = 1.0, we'll consider Fresnel term in render program
    float F = A + B;

    // 1 - E(u)
    //F = 1.0 - F;
    return Vec3f(F, F, F);
}

int main() {
    uint8_t data[resolution * resolution * 3];
    float step = 1.0 / resolution;
    for (int i = 0; i < resolution; i++) {
        for (int j = 0; j < resolution; j++) {
            float roughness = step * (static_cast<float>(i) + 0.5f);
            float NdotV = step * (static_cast<float>(j) + 0.5f);
            Vec3f V = Vec3f(std::sqrt(1.f - NdotV * NdotV), 0.f, NdotV);

            Vec3f irr = IntegrateBRDF(V, roughness);

            data[(i * resolution + j) * 3 + 0] = uint8_t(irr.x * 255.0);
            data[(i * resolution + j) * 3 + 1] = uint8_t(irr.y * 255.0);
            data[(i * resolution + j) * 3 + 2] = uint8_t(irr.z * 255.0);
        }
    }
    stbi_flip_vertically_on_write(true);
    stbi_write_png("GGX_E_LUT.png", resolution, resolution, 3, data, resolution * 3);
    
    std::cout << "Finished precomputed!" << std::endl;
    return 0;
}