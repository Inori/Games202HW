#ifdef GL_ES
precision mediump float;
#endif

//#define ENABLE_LIGHT2

// Phong related variables
uniform sampler2D uSampler;
uniform vec3 uKd;
uniform vec3 uKs;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightIntensity;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

// Shadow map related variables
#define NUM_SAMPLES 100
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10

#define EPS 1e-3
#define PI 3.141592653589793
#define PI2 6.283185307179586

uniform sampler2D uShadowMap;
varying vec4 vPositionFromLight;

highp float rand_1to1(highp float x ) { 
  // -1 -1
  return fract(sin(x)*10000.0);
}

highp float rand_2to1(vec2 uv ) { 
  // 0 - 1
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract(sin(sn) * c);
}

float unpack(vec4 rgbaDepth) {
    const vec4 bitShift = vec4(1.0, 1.0/256.0, 1.0/(256.0*256.0), 1.0/(256.0*256.0*256.0));
    return dot(rgbaDepth, bitShift);
}

vec2 poissonDisk[NUM_SAMPLES];

void poissonDiskSamples( const in vec2 randomSeed ) {

  float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
  float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );

  float angle = rand_2to1( randomSeed ) * PI2;
  float radius = INV_NUM_SAMPLES;
  float radiusStep = radius;

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
    radius += radiusStep;
    angle += ANGLE_STEP;
  }
}

float PCFA(sampler2D shadowMap, vec4 coords) {

  vec2 uv = coords.xy;

  const float pixelRadius = 10.0;
  const float resolution = 2048.0;

  float inShadowSum = 0.0;
  for (int i = 0; i != PCF_NUM_SAMPLES; i += 1)
  {
    // random uv
    vec2 randomUV = uv + (pixelRadius / resolution) * poissonDisk[i];
    // blocker to light
    float depth = unpack(texture2D(shadowMap, randomUV));
    // viewport to ndc
    //float distanceBlocker = depth * 2.0 - 1.0;
    float distanceBlocker = depth;

    // shading point to light 
    float distanceShPoint = coords.z;;
    // depth bias
    float bias = 0.01;
    // count in shadow
    float inShadow = distanceShPoint + EPS > distanceBlocker + bias? 1.0 : 0.0;
    inShadowSum += inShadow;
  }

  float visibility = 1.0 - inShadowSum / float(PCF_NUM_SAMPLES);
  return visibility;
}


vec3 blinnPhong() {
  vec3 color = texture2D(uSampler, vTextureCoord).rgb;
  color = pow(color, vec3(2.2));

  vec3 ambient = 0.05 * color;

  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  float diff = max(dot(lightDir, normal), 0.0);
  vec3 light_atten_coff =
      uLightIntensity / pow(length(uLightPos - vFragPos), 2.0);
  vec3 diffuse = diff * light_atten_coff * color;

  vec3 viewDir = normalize(uCameraPos - vFragPos);
  vec3 halfDir = normalize((lightDir + viewDir));
  float spec = pow(max(dot(halfDir, normal), 0.0), 32.0);
  vec3 specular = uKs * light_atten_coff * spec;

  vec3 radiance = (ambient + diffuse + specular);
  vec3 phongColor = pow(radiance, vec3(1.0 / 2.2));
  return phongColor;
}

void main(void) {
  poissonDiskSamples(vTextureCoord);

  float visibility = 1.0;
  vec3 shadowCoordNDC = (vPositionFromLight.xyz / vPositionFromLight.w + 1.0) / 2.0;
  
  visibility = PCFA(uShadowMap, vec4(shadowCoordNDC, 1.0));

  vec3 phongColor = blinnPhong();
  gl_FragColor = vec4(phongColor * visibility, 1.0);
}