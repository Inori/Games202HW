class PRTMaterial extends Material {

    constructor(vertexShader, fragmentShader) {

        let curPrecomputeL = precomputeL[guiParams.envmapId];
        let precomputeLMat = getMat3ValueFromRGB(curPrecomputeL);
        super({
            // 
            'uPrecomputeLR': { type: 'matrix3fv', value: precomputeLMat[0] },
            'uPrecomputeLG': { type: 'matrix3fv', value: precomputeLMat[1] },
            'uPrecomputeLB': { type: 'matrix3fv', value: precomputeLMat[2] },
        }, ['aPrecomputeLT'], vertexShader, fragmentShader, null);
    }
}

async function buildPRTMaterial(vertexPath, fragmentPath) {


    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new PRTMaterial(vertexShader, fragmentShader);

}