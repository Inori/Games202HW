
//const { vec4, mat4 } = require("../../lib/gl-matrix");

class DirectionalLight {

    constructor(lightIntensity, lightColor, lightPos, focalPoint, lightUp, hasShadowMap, gl) {
        this.mesh = Mesh.cube(setTransform(0, 0, 0, 0.2, 0.2, 0.2, 0));
        this.mat = new EmissiveMaterial(lightIntensity, lightColor);
        this.lightPos = lightPos;
        this.focalPoint = focalPoint;
        this.lightUp = lightUp

        this.hasShadowMap = hasShadowMap;
        this.fbo = new FBO(gl);
        if (!this.fbo) {
            console.log("无法设置帧缓冲区对象");
            return;
        }
    }

    CalcLightMVP(translate, scale) {
        let lightMVP = mat4.create();
        let modelMatrix = mat4.create();
        let viewMatrix = mat4.create();
        let projectionMatrix = mat4.create();
        
        // Model transform
        //mat4.fromRotationTranslationScale(modelMatrix, quat.create(), this.lightPos, mat4.create());
        mat4.fromTranslation(modelMatrix, this.lightPos);
        // View transform
        mat4.lookAt(viewMatrix, this.lightPos, this.focalPoint, this.lightUp);
        // Projection transform
        const edge = 80.0;
        mat4.ortho(projectionMatrix, -edge, edge, -edge, edge, 0.10, 200.0);
        //const canvas = document.querySelector('#glcanvas');
        //const gl = canvas.getContext('webgl');
        //mat4.perspective(projectionMatrix, Math.PI/2.0, gl.canvas.clientWidth / gl.canvas.clientHeight, 0.01, 1000);

        mat4.multiply(lightMVP, projectionMatrix, viewMatrix);
        mat4.multiply(lightMVP, lightMVP, modelMatrix);

        return lightMVP;
    }
}
