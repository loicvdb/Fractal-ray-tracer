#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

//minimum and maximum for adaptive sampling (to concentrate the sampling in the noisy areas)
const int MAX_SPP = 1;
const int MIN_SPP = 1;

const vec3 GLASS_TINT = vec3(1.0, 1.0, 1.0);
const float IOR = 1.5;
const float DIFFUSION_FACTOR = 1.5;
const vec3 MIST_TINT = vec3(.7, .3, .5);
const float MIST_FACTOR = .13;
const vec3 GLOW_TINT = vec3(1, 1, 1);
const float GLOW_FACTOR = .007;
const float AMD_FACTOR = .1;
const float DETAIL_FACTOR = 3.0;
const int MAX_STEPS = 500;
const float MAX_DIST = 100;
const float STEP_FACTOR = .5;

const float EPSILON = .00000005;
const float PI = 3.14159265359;



uniform int width;
uniform int height;
uniform int noiseSeed;
uniform sampler2D hdri;
uniform float alpha;

//camera settings
uniform vec3 posCam;
uniform vec3 prevPosCam;
uniform vec3 dirCam;
uniform vec3 prevDirCam;
uniform float focalLength;
uniform float prevFocalLength;
uniform float shutter;
uniform float focalDistance;
uniform float aperture;

int relativeSPP;
vec2 seed;

//noise function
float rand(vec2 n) {
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

//random float generator
float randomFloat(){
  seed += vec2(1.0, -1.0);
  return rand(seed);
}

//returns the size of the focus at a point, used to keep the detail where the focus is
float focusSize(vec3 pos){
	return aperture / focalDistance * abs((focalDistance - length(pos - posCam)));
}

//adaptive minimum distance at a given position, stops a ray as soon as it is closer than this distance
float adaptiveMinDist(vec3 pos){
	float pixelSize = length(pos - posCam)/focalLength / max(width, height);
	return pixelSize/DETAIL_FACTOR + focusSize(pos)*AMD_FACTOR + EPSILON;
}

//returns the distance to the mandelbulb fractal
float getDistanceMandelbulb(vec3 pos) {
	float bailout = 5;
	float power = 8;
	int iterations = 50;
	if(length(pos) > 1.3) return length(pos) - 1.2; //optimisation for when the ray is out of a sphere containing the mandelbulb
	vec3 z = pos;
	float dr = 1.0;
	float r = 0.0;
	float zr;
	for(int i = 0; i < iterations ; i++) {
		r = length(z);
		if(r>bailout) break;
		float theta = acos(z.z/r);
		float phi = atan(z.y,z.x);
		dr = pow(r, power-1.0)*power*dr + 1.0;
		zr = pow(r,power);
		theta = theta*power;
		phi = phi*power;
		z = zr*vec3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
		z+=pos;
	}
	return 0.5*log(r)*r/dr;
}

float getDistancePseudoKleinian(vec3 p){
		vec4 param_min = vec4(-0.8323, -0.694, -0.5045, 0.8067);
		vec4 param_max = vec4(0.8579, 1.0883, 0.8937, 0.9411);
		int foldingNumber = 12;
    float k1, k2, rp2, rq2;
    float scale = 1.0;
    vec3 q = p;
    for (int i = 0; i < foldingNumber; i++){
	    p = 2.0 * clamp(p, param_min.xyz, param_max.xyz) - p;
	    q = 2.0 * fract(0.5 * q + 0.5) - 1.0;
	    rp2 = dot(p, p);
	    rq2 = dot(q, q);
	    k1 = max(param_min.w / rp2, 1.0);
	    k2 = max(param_min.w / rq2, 1.0);
	    p *= k1;
	    q *= k2;
	    scale *= k1;
    }
    float lxy = length(p.xy);
    return 0.5 * max(param_max.w - lxy, lxy * p.z / length(p)) / scale;
}

//returns the distance to the fractal
float getDistance(vec3 pos){
	return getDistancePseudoKleinian(pos);
}


//fresnel refractance calculation
float fresnel(vec3 dir, vec3 normal, float ior) {
  float kr;
  float cosi = dot(dir, normal);
  float etai = 1;
  float etat = ior;
  if (cosi > 0) {
    float tmp = etai;
    etai = etat;
    etat = tmp;
  }
  // Compute sini using Snell's law
  float sint = etai / etat * sqrt(max(0, 1 - cosi * cosi));
  // Total internal reflection
  if (sint >= 1) {
    kr = 1;
  } else {
    float cost = sqrt(max(0.f, 1 - sint * sint));
    cosi = abs(cosi);
    float sqrtRs = ((etat * cosi) - (etai * cost)) / ((etat * cosi) + (etai * cost));
    float sqrtRp = ((etai * cosi) - (etat * cost)) / ((etai * cosi) + (etat * cost));
    kr = (sqrtRs * sqrtRs + sqrtRp * sqrtRp) / 2;
  }
  return kr;
}

//returns the background color for a given direction
vec3 getBackground(vec3 dir){
  float x = atan(dir.x, dir.y) / (2*PI) + .5;
  float y = -dir.z / 2 + .5;
  return texture(hdri, vec2(x, y)).rgb;
}

//returns the glass color for the glass material
vec3 getGlassColor(vec3 dir, vec3 normal, float ior){
	float fres = fresnel(dir, normal, ior);
	vec3 reflectDir = reflect(dir, normal);
	vec3 refractDir = refract(dir, normal, 1/ior);
	return fres * getBackground(reflectDir) + (1-fres) * getBackground(refractDir) * GLASS_TINT;
}

//returns the normal to the fractal at a point
vec3 getNormal(vec3 pos, float p){
float normalSmooth = 1;
  vec3 xDir = vec3(p, 0, 0) * normalSmooth;
  vec3 yDir = vec3(0, p, 0) * normalSmooth;
  vec3 zDir = vec3(0, 0, p) * normalSmooth;

  float normalX = getDistance(pos + xDir)
                - getDistance(pos - xDir);
  float normalY = getDistance(pos + yDir)
                - getDistance(pos - yDir);
  float normalZ = getDistance(pos + zDir)
                - getDistance(pos - zDir);

  return normalize(vec3(normalX, normalY, normalZ));
}

//traces a ray
bool trace(in vec3 pos, in vec3 dir, out int nbSteps, out float minAngle, out vec3 hitPos, out vec3 hitNormal){
	vec3 posBefore = pos;
	minAngle = PI;
	dir = normalize(dir);
  int steps = 0;
	float amd;
  while(steps < MAX_STEPS){
		if(length(pos) >= MAX_DIST) return false;
    float distance = getDistance(pos);
		amd = adaptiveMinDist(pos);
    if(abs(distance) <= amd) break;
		float currentAngle = atan(distance - amd, length(pos - posBefore));
		if(currentAngle < minAngle) minAngle = currentAngle;
    pos += dir * (STEP_FACTOR * distance);
    steps++;
  }
	nbSteps = steps;
	hitPos = pos;
	hitNormal = getNormal(pos, amd);
	return true;
}

//returns the color of the given ray
vec3 getColorOfRay(vec3 pos, vec3 dir){
  vec3 hitPos;
	vec3 hitNormal;
	int nbSteps;
	float minAngle;
	if(trace(pos, dir, nbSteps, minAngle, hitPos, hitNormal)){
		float r = getGlassColor(dir, hitNormal, IOR).r;
		float g = getGlassColor(dir, hitNormal, IOR*DIFFUSION_FACTOR).g;
		float b = getGlassColor(dir, hitNormal, IOR*DIFFUSION_FACTOR*DIFFUSION_FACTOR).b;
		vec3 glassColor = vec3(r, g, b);
		vec3 glowColor = GLOW_TINT * nbSteps * GLOW_FACTOR;
		float mistInter = pow(1-MIST_FACTOR, length(pos - hitPos));
		return (glassColor + glowColor) * mistInter + MIST_TINT * (1-mistInter);
	} else {
		if(minAngle > atan(aperture, focalDistance)) relativeSPP = MIN_SPP;
		vec3 glowColor = GLOW_TINT * nbSteps * GLOW_FACTOR;
		float mistInter = pow(1-MIST_FACTOR, MAX_DIST);
		return (getBackground(dir) + glowColor) * mistInter + MIST_TINT * (1-mistInter);
	}
}

//samples a ray using the camera settings
vec3 getSample(){

	//linear interpolation for motion blur
	float interpolationFactor = randomFloat() * shutter;
	vec3 pos = interpolationFactor * prevPosCam + (1-interpolationFactor) * posCam;
	vec3 dir = interpolationFactor * prevDirCam + (1-interpolationFactor) * dirCam;
	float interpolatedFocalLength = interpolationFactor * prevFocalLength + (1-interpolationFactor) * focalLength;

	//coodinates on the screen
	vec2 coords = (gl_FragCoord.xy - vec2(width+randomFloat(), height+randomFloat())/2) / max(width, height);

	vec3 camX = vec3(-dir.y, dir.x, 0);
	vec3 camY = cross(camX, dir);
	vec3 sensorX = camX * (coords.x/length(camX));
	vec3 sensorY = camY * (coords.y/length(camY));
	vec3 centerSensor = pos - dir * interpolatedFocalLength;
	vec3 posOnSensor = centerSensor + sensorX + sensorY;

	vec3 posInFocus = pos + (pos - posOnSensor) * (focalDistance / length(pos - posOnSensor));

	float angle = randomFloat() * 2*PI - PI;
	float radius = aperture*sqrt(randomFloat());

	float xAperture = radius * cos(angle);
	float yAperture = radius * sin(angle);

	vec3 vecAperture = camX * (xAperture / length(camX)) + camY * (yAperture / length(camY));
	vec3 eyePlusAperture = pos + vecAperture;
	vec3 newDir = normalize(posInFocus - eyePlusAperture);

	return getColorOfRay(eyePlusAperture, newDir);
}


//main of the shader
void main() {

	seed = gl_FragCoord.xy / vec2(width, height) * noiseSeed;

	vec3 sumColor = vec3(0, 0, 0);
	relativeSPP = MAX_SPP;
	int SPP = 0;
	while(SPP < relativeSPP){
		sumColor += getSample();
		SPP++;
	}

	gl_FragColor = vec4(sumColor / SPP, alpha);
}
