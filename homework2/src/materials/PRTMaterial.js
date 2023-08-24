class PRTMaterial extends Material {

    constructor(precomputeL, precomputeLT, vertexShader, fragmentShader) {

        super({
            // 
            // 'uSampler': { type: 'texture', value: color },
            // 'uKs': { type: '3fv', value: specular },
            // 'uLightRadiance': { type: '3fv', value: lightIntensity },

        }, [], vertexShader, fragmentShader, null);
    }
}

async function buildPRTMaterial(precomputeL, precomputeLT, vertexPath, fragmentPath) {


    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new PRTMaterial(precomputeL, precomputeLT, vertexShader, fragmentShader);

}