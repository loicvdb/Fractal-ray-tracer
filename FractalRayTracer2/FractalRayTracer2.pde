///////////////////////////// PARAMETERS /////////////////////////////
//camera settings
PVector pos = new PVector(1.6655083, -0.13961393, 0.60328376);
PVector dir = new PVector(-0.80678993, -0.39260453, 0.4415335);
float focalLength = 0.9500005;
float focalDistance = 2.0824172;
float aperture = 0.03;
float shutter = 0;
//flying settings
float flySpeed = .005;
//sampling
int maxSPP = 100;
//noise (for animations)
boolean dynamicNoise = false;

////////////////////////// GLOBAL VARIABLES //////////////////////////
//motion blur
PVector prevPos = pos.copy();
PVector prevDir = dir.copy();
float prevFocalLength = focalLength;
//shader
PShader tracer;
//controls
boolean left, right, forward, backward, up, down;
//sampling
int SPP;

void setup(){
  size(1280, 720, P2D);
  tracer = loadShader("shaders/fragment.glsl", "shaders/vertex.glsl");
  tracer.set("hdri", loadImage("hdri.jpg"));
  frameRate(1000);
}

void draw(){
  move();
  if(SPP < maxSPP) generateImage();
  println(frameRate);
}

void reset(){
  SPP = 0;
  prevFocalLength = focalLength;
  prevDir = dir.copy();
  prevPos = pos.copy();
}

void move(){
  
  if(forward)  pos.add(dir.copy().setMag(flySpeed));
  if(backward) pos.sub(dir.copy().setMag(flySpeed));
  if(left)     pos.sub(new PVector(dir.y, -dir.x, 0).setMag(flySpeed));
  if(right)    pos.add(new PVector(dir.y, -dir.x, 0).setMag(flySpeed));
  if(up)       pos.add(new PVector(0, 0, 1).setMag(flySpeed));
  if(down)     pos.sub(new PVector(0, 0, 1).setMag(flySpeed));
  
  if(forward || backward || left || right || up || down) reset();
}

void generateImage(){
  
  SPP++;
  
  if(dynamicNoise) tracer.set("noiseSeed", frameCount);
  else tracer.set("noiseSeed", SPP);
  tracer.set("width", width);
  tracer.set("height", height);
  tracer.set("posCam", pos);
  tracer.set("prevPosCam", prevPos);
  tracer.set("dirCam", dir);
  tracer.set("prevDirCam", prevDir);
  tracer.set("focalLength", focalLength);
  tracer.set("prevFocalLength", prevFocalLength);
  tracer.set("focalDistance", focalDistance);
  tracer.set("aperture", aperture);
  tracer.set("alpha", 1.0/SPP);
  
  shader(tracer);
  beginShape(QUADS);
  vertex(-1, -1);
  vertex(width+1, -1);
  vertex(width+1, height+1);
  vertex(-1, height+1);
  endShape();
}


void mouseDragged() {
  
  float sensitivity = 1.0 / focalLength / max(width, height);
  PVector mouvX = new PVector(-dir.y, dir.x, 0);
  PVector mouvY = dir.copy().cross(mouvX);
  mouvX.setMag((pmouseX - mouseX) * sensitivity);
  mouvY.setMag((pmouseY - mouseY) * sensitivity);
  dir.add(mouvX).add(mouvY).normalize();
  reset ();
}

void mouseWheel(MouseEvent e) {
  
  int count = e.getCount();
  if      (keyPressed && (key == 'f' || key == 'F')) focalDistance *= pow(.97, count);
  else if (keyPressed && (key == 'a' || key == 'A')) aperture *= pow(.95, count);
  else focalLength *= pow(.95, count);
  reset();
}

void keyPressed() {

  if      (key == 'z' || key == 'Z') forward = true;
  else if (key == 's' || key == 'S') backward = true;
  else if (key == 'q' || key == 'Q') left = true;
  else if (key == 'd' || key == 'D') right = true;
  else if (key == ' ')               up = true;
  else if (key == 'c' || key == 'C') down = true;
}

void keyReleased() {

  if      (key == 'z' || key == 'Z') forward = false;
  else if (key == 's' || key == 'S') backward = false;
  else if (key == 'q' || key == 'Q') left = false;
  else if (key == 'd' || key == 'D') right = false;
  else if (key == ' ')               up = false;
  else if (key == 'c' || key == 'C') down = false;
}