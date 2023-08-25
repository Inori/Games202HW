class PRTMaterial extends Material {

    lastEnvMapId = 0;

    constructor(vertexShader, fragmentShader) {

        let curPrecomputeL = precomputeL[guiParams.envmapId];
        let precomputeLMat = getMat3ValueFromRGB(curPrecomputeL);
        super({
            // 
            'uPrecomputeLR': { type: 'matrix3fv', value: precomputeLMat[0] },
            'uPrecomputeLG': { type: 'matrix3fv', value: precomputeLMat[1] },
            'uPrecomputeLB': { type: 'matrix3fv', value: precomputeLMat[2] },
        }, ['aPrecomputeLT'], vertexShader, fragmentShader, null);

        this.lastEnvMapId = guiParams.envmapId;
    }

    updateUniforms() {
        if (guiParams.envmapId == this.lastEnvMapId)
        {
            return;
        }

        this.lastEnvMapId = guiParams.envmapId;

        let curPrecomputeL = precomputeL[guiParams.envmapId];
        let precomputeLMat = getMat3ValueFromRGB(curPrecomputeL);
        this.setPrecomputeL(precomputeLMat);
    }

    setPrecomputeL(rgbMat3) {
        this.uniforms = {
            // 
            'uPrecomputeLR': { type: 'matrix3fv', value: rgbMat3[0] },
            'uPrecomputeLG': { type: 'matrix3fv', value: rgbMat3[1] },
            'uPrecomputeLB': { type: 'matrix3fv', value: rgbMat3[2] },
        };
    }
}



async function buildPRTMaterial(vertexPath, fragmentPath) {


    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new PRTMaterial(vertexShader, fragmentShader);

}