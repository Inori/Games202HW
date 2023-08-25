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

  float r = dot(uPrecomputeLR[0], aPrecomputeLT[0]) + dot(uPrecomputeLR[1], aPrecomputeLT[1]) + dot(uPrecomputeLR[2], aPrecomputeLT[2]);
  float g = dot(uPrecomputeLG[0], aPrecomputeLT[0]) + dot(uPrecomputeLG[1], aPrecomputeLT[1]) + dot(uPrecomputeLG[2], aPrecomputeLT[2]);
  float b = dot(uPrecomputeLB[0], aPrecomputeLT[0]) + dot(uPrecomputeLB[1], aPrecomputeLT[1]) + dot(uPrecomputeLB[2], aPrecomputeLT[2]);
  vColor = vec3(r, g, b);
  vNormal = (uModelMatrix * vec4(aNormalPosition, 0.0)).xyz;

  gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix *
                vec4(aVertexPosition, 1.0);
}