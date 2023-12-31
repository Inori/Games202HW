#include "denoiser.h"
#include <cmath>


Denoiser::Denoiser() : m_useTemportal(false) {}

void Denoiser::Reprojection(const FrameInfo &frameInfo) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    Matrix4x4 preWorldToScreen =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 1];
    Matrix4x4 preWorldToCamera =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 2];
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Reproject

            auto curObjId = frameInfo.m_id(x, y);
            if (curObjId < 0.0)
            {
                // no object, use current background
                m_valid(x, y) = false;
                //m_misc(x, y) = frameInfo.m_beauty(x, y);
                continue;
            }

            auto curPosition = frameInfo.m_position(x, y);
            int objId = static_cast<int>(curObjId);
            auto curObjectToWorld = frameInfo.m_matrix[objId];
            auto preObjectToWorld = m_preFrameInfo.m_matrix[objId];
            auto M = preWorldToScreen * preObjectToWorld * Inverse(curObjectToWorld);
            auto preScreenPosition = M(curPosition, Float3::Point);

            bool outOfScreen = preScreenPosition.x < 0.0 || preScreenPosition.y < 0.0 ||
                               preScreenPosition.x >= width ||
                               preScreenPosition.y >= height;
            if (outOfScreen) 
            {
                m_valid(x, y) = false;
                //m_misc(x, y) = frameInfo.m_beauty(x, y);
                continue;
            }

            auto preObjId = m_preFrameInfo.m_id(preScreenPosition.x, preScreenPosition.y);
            bool diffObjId = !EqualFloat(preObjId, curObjId);
            if (diffObjId) 
            {
                m_valid(x, y) = false;
                //m_misc(x, y) = frameInfo.m_beauty(x, y);
                continue;
            }

            m_valid(x, y) = true;
            m_misc(x, y) =
                m_preFrameInfo.m_beauty(preScreenPosition.x, preScreenPosition.y);
        }
    }
    std::swap(m_misc, m_accColor);
}

void Denoiser::TemporalAccumulation(const Buffer2D<Float3> &curFilteredColor) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    int kernelRadius = 3;
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Temporal clamp

            Float3 sum = 0.0;
            Float3 sqrSum = 0.0;
            float count = 0.0;
            for (int dy = -kernelRadius; dy <= kernelRadius; ++dy) 
            {
                for (int dx = -kernelRadius; dx <= kernelRadius; ++dx) 
                {
                    int x_j = x + dx;
                    int y_j = y + dy;
                    if (x_j < 0 || y_j < 0 || x_j >= width || y_j >= height) 
                    {
                        continue;
                    }

                    sum += curFilteredColor(x_j, y_j);
                    sqrSum += Sqr(curFilteredColor(x_j, y_j));
                    count += 1.0;
                }
            }
            
            Float3 mean = sum / count;
            Float3 variance = sqrSum / count - Sqr(mean);

            Float3 color = m_accColor(x, y);
            Float3 preColor = Clamp(color, mean - variance * m_colorBoxK, mean + variance * m_colorBoxK);

            // TODO: Exponential moving average
            float alpha = m_valid(x, y) ? m_alpha : 1.0;
            m_misc(x, y) = Lerp(preColor, curFilteredColor(x, y), alpha);
        }
    }
    std::swap(m_misc, m_accColor);
}

Buffer2D<Float3> Denoiser::Filter(const FrameInfo &frameInfo) {
    int height = frameInfo.m_beauty.m_height;
    int width = frameInfo.m_beauty.m_width;
    Buffer2D<Float3> filteredImage = CreateBuffer2D<Float3>(width, height);
    int kernelRadius = 16;

#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Joint bilateral filter

            Float3 sum_of_weighted_sample = 0.0;
            float sum_of_weight = 0.0;

            auto pi = frameInfo.m_position(x, y);
            auto ni = frameInfo.m_normal(x, y);
            auto ci = frameInfo.m_beauty(x, y);
            
            for (int dy = -kernelRadius; dy <= kernelRadius; ++dy)
            {
                for (int dx = -kernelRadius; dx <= kernelRadius; ++dx)
                {
                    int x_j = x + dx;
                    int y_j = y + dy;
                    if (x_j < 0 || y_j < 0 || x_j >= width || y_j >= height)
                    {
                        continue;
                    }

                    auto pj = frameInfo.m_position(x_j, y_j);
                    auto cj = frameInfo.m_beauty(x_j, y_j);
                    auto nj = frameInfo.m_normal(x_j, y_j);

                    float weight = 0.0;
                    float distance = Distance(pi, pj);
                    if (distance < std::numeric_limits<float>::epsilon())
                    {
                        // if two points are so close to each other such that we
                        // think they are the same point, the weight should be 1.0
                        weight = 1.0;
                    } 
                    else 
                    {
                        auto coord = -SqrDistance(pi, pj) / (2.0 * std::powf(m_sigmaCoord, 2.0));
                        auto color = -SqrDistance(ci, cj) / (2.0 * std::powf(m_sigmaColor, 2.0));
                        auto normal = -std::powf(SafeAcos(Dot(ni, nj)), 2.0) / (2.0 * std::powf(m_sigmaNormal, 2.0));

                        auto ei = Normalize(pj - pi);
                        auto plane = -std::powf(Dot(ni, ei), 2.0) / (2.0 * std::powf(m_sigmaPlane, 2.0));

                        weight = std::expf(coord + color + normal + plane);
                    }

                    sum_of_weighted_sample += (cj * weight);
                    sum_of_weight += weight;
                }
            }


            //filteredImage(x, y) = frameInfo.m_beauty(x, y);
            //filteredImage(x, y) = frameInfo.m_position(x, y);
            filteredImage(x, y) = sum_of_weighted_sample / sum_of_weight;
        }
    }
    return filteredImage;
}


void Denoiser::Init(const FrameInfo &frameInfo, const Buffer2D<Float3> &filteredColor) {
    m_accColor.Copy(filteredColor);
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    m_misc = CreateBuffer2D<Float3>(width, height);
    m_valid = CreateBuffer2D<bool>(width, height);
}

void Denoiser::Maintain(const FrameInfo &frameInfo) { m_preFrameInfo = frameInfo; }

Buffer2D<Float3> Denoiser::ProcessFrame(const FrameInfo &frameInfo) {
    // Filter current frame
    Buffer2D<Float3> filteredColor;
    filteredColor = Filter(frameInfo);

    // Reproject previous frame color to current
    if (m_useTemportal) {
        Reprojection(frameInfo);
        TemporalAccumulation(filteredColor);
    } else {
        Init(frameInfo, filteredColor);
    }

    // Maintain
    Maintain(frameInfo);
    if (!m_useTemportal) {
        m_useTemportal = true;
    }
    return m_accColor;
}
