attribute vec3 aVertexPosition;
attribute vec3 aNormalPosition;
//attribute vec2 aTextureCoord;
attribute mat3 aPrecomputeLT;

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;
uniform mat3 uPrecomputeLR;
uniform mat3 uPrecomputeLG;
uniform mat3 uPrecomputeLB;

varying highp vec3 vColor;
varying highp vec3 vNormal;

void main(void) {

  vColor = vec3(uPrecomputeLG[0][0], uPrecomputeLG[0][1], uPrecomputeLG[0][2]);
  vNormal = (uModelMatrix * vec4(aNormalPosition, 0.0)).xyz;

  gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix *
                vec4(aVertexPosition, 1.0);
}