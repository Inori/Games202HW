#ifdef GL_ES
precision mediump float;
#endif

// Phong related variables
// uniform sampler2D uSampler;
// uniform vec3 uKd;
// uniform vec3 uKs;
// uniform vec3 uLightPos;
// uniform vec3 uCameraPos;
// uniform vec3 uLightRadiance;

varying highp vec3 vColor;
varying highp vec3 vNormal;


void main(void) {

  gl_FragColor = vec4(vColor, 1.0);
}
