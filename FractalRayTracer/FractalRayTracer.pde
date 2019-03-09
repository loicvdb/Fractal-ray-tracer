/////////////////// Instructions ///////////////////
/*
Thank you for downloading and trying my real time fractal ray tracer! here are the controls:
- moving : use [space] to go up, [C] to go down and [ZQSD] to move around (you can change it to [WASD] for qwerty keyboards)
- looking around : click and drag the mouse over the screen to change the direction of the camera
- zooming : scroll up to zoom in, and down to zoom out
- DoF : to open the aperture, press [A] (you can change it to [Q] for qwerty keyboards) and scroll up and down
- focus : to move the focus, press [F] and scroll up and down

To disable motion blur, set the "shutter" parameter to 0 (shader parameters -> camera parameters -> shutter)
To disable DoF, set the "apeture" parameter to 0 (shader parameters -> camera parameters -> apeture)
To change fractal, set the "fractalType" parameter to 0 or 1 (shader parameters -> scene parameters -> fractalType)
  there are currently 2 fractals: a tetrahedron (0) and mandelbulb (1), the mandelbulb is slower

/!\ FOR QWERTY KEYBOARDS, I'VE INCLUDED SOME COMMENTS WITH THE CORRECT QWERTY CODE IN mouseWheel(), keyPressed() AND keyReleased() TO CHANGE THE ZQSD in WASD
*/

/////////////////// SHADER PARAMETERS ///////////////////

//camera parameters
PVector pos = new PVector(2, 2, 2);                //position
PVector prevPos = pos.copy();                      //previous position, used for motion blur
PVector dir = new PVector(-1, -1, -1).normalize(); //direction
PVector prevDir = dir.copy();                      //previous direction, for motion blur
float focalLength = 1;                             //focal length (zoom)
float prevFocalLength = focalLength;               //previous focal length, for motion blur
float shutter = .5;                                //time of open shutter (amount of motion blur), keep it between 0 and 1 
float focalDistance = 1;                           //distance to the focal plane (focus)
float aperture = 0.01;                             //size of aperture, (amount of blur in the foreground and background)

//minimum and maximum for adaptive sampling (to concentrate the sampling in the noisy areas). I'd suggest leaving the minSPP to 1, but you can raise the maxSPP to get a slightly better DoF
int maxSPP = 1;
int minSPP = 1;

//scene parameters
PVector shapeColor = new PVector(1, 1, 1);            //color of the fractal (I don't have any coloration algorithm, I prefer it this way)
PVector backgroundColor = new PVector(.6, .8, 1);     //color of the background
boolean traceDirectLight = true;                      //disabling direct light doubles the fps
PVector dirLight = new PVector(-1, 1, -1).normalize();//direct light direction
PVector lightColor = new PVector(1, .75, .6);         //direct light color
float lightRadius = .05;                              //direct light radius (angle of the sun)
float AOFactor = .02;                                 //ambiant occlusion factor
float mistFactor = 0;                                 //mist factor
float adaptiveMinDistFactor = .05;                    //adaptive minimum distance factor
float detailFactor = 50;                              //detail factor
int fractalType = 0;                                  //specifies which fractal to render (0 -> tetrahedron, 1 -> mandelbulb)
boolean dynamicNoise = false;                         //a static noise helps with video compression


/////////////////// SKETCH PARAMETERS ///////////////////

float absSpeed = .0005;  //flying speed

PShader tracer;
int time;
boolean reset;
int bufferSPP;
PImage buffer;
PGraphics pg;
int curWidth, curHeight;
boolean z, q, s, d, up, down;
int SPPGoal;


void setup(){
  size(720, 480, P2D);
  noStroke();
  buffer = createImage(width, height, RGB);
  pg = createGraphics(width, height, P2D);
  tracer = loadShader("shaders/tracer_frag.glsl", "shaders/vertex.glsl");
  
  SPPGoal = 10*maxSPP*maxSPP; //weird lines appear in the DoF when rendering for too long with a low "maxSPP" so I have to put a limit, saves ressources too
  
  //initialize the shader
  tracer.set("maxSPP", maxSPP);
  tracer.set("minSPP", minSPP);
  tracer.set("shapeColor", shapeColor);
  tracer.set("lightColor", lightColor);
  tracer.set("lightRadius", lightRadius);
  tracer.set("backgroundColor", backgroundColor);
  tracer.set("traceDirectLight", traceDirectLight);
  tracer.set("detailFactor", detailFactor);
  tracer.set("shutter", shutter);
  tracer.set("dirLight", dirLight);
  tracer.set("fractalType", fractalType);
  tracer.set("AOFactor", AOFactor);
  tracer.set("mistFactor", mistFactor);
  tracer.set("adaptiveMinDistFactor", adaptiveMinDistFactor);
  
  /*THE FRAMERATE CAN'T GO OVER 30 FPS WHILE RENDERING
    I have no idea why, but there's no point in raising this value because, even with nothing in the shader,
    you can't go over 30 fps. I tried to see if the 30 fps limit was due to the sketch (the tint() and image()
    functions are quite slow sometimes) but I really can't find anything.
  */
  frameRate(30);
}

void draw(){
  
  if(curWidth != width || curHeight != height){
    reset = true;
    curWidth = width;
    curHeight = height;
  }
  
  String info = round(1000.0/(millis()-time)) + "FPS (average: " + round(frameRate) + ") - rendered " + bufferSPP*maxSPP + " SPP (aiming for " + SPPGoal + ")";
  println(info);
  
  move();
  time = millis();
  
  reset = reset || z || q || s || d || up || down;
  
  if(reset){
    buffer = createImage(width, height, RGB);
    pg = createGraphics(width, height, P3D);
    bufferSPP = 0;
    reset = false;
  }
  
  tint(255, 255);
  image(buffer, 0, 0);
  if(bufferSPP*maxSPP < SPPGoal) generateImage();
  
  //text(info, 20, 20);
  
  if(prevPos.copy().sub(pos).magSq() != 0){
    prevPos = pos.copy();
    reset = true;
  }
  if(prevDir.copy().sub(dir).magSq() != 0){
    prevDir = dir.copy();
    reset = true;
  }
  if(prevFocalLength != focalLength){
    prevFocalLength = focalLength;
    reset = true;
  }
}

void move(){
  
  float speed = absSpeed * (millis()-time);
  if(z) pos.add(dir.copy().setMag(speed));
  if(q) pos.sub(new PVector(dir.y, -dir.x, 0).setMag(speed));
  if(s) pos.sub(dir.copy().setMag(speed));
  if(d) pos.add(new PVector(dir.y, -dir.x, 0).setMag(speed));
  if(up) pos.add(new PVector(0, 0, 1).setMag(speed));
  if(down) pos.sub(new PVector(0, 0, 1).setMag(speed));
}

void generateImage(){
  
  if(dynamicNoise) tracer.set("noiseSeed", frameCount);
  else tracer.set("noiseSeed", bufferSPP);
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
  pg.beginDraw();
  pg.shader(tracer);
  pg.beginShape(QUADS);
  pg.vertex(0, 0);
  pg.vertex(width, 0);
  pg.vertex(width, height);
  pg.vertex(0, height);
  pg.endShape();
  pg.endDraw();
  tint(255, 255/(bufferSPP+1));
  image(pg, 0, 0);
  buffer = get();
  bufferSPP++;
}

void mouseDragged() {
  
  float sensibility = 1 / focalLength / max(width, height);
  PVector mouvX = new PVector(-dir.y, dir.x, 0);
  PVector mouvY = dir.copy().cross(mouvX);
  mouvX.setMag((pmouseX - mouseX) * sensibility);
  mouvY.setMag((pmouseY - mouseY) * sensibility);
  dir.add(mouvX).add(mouvY).normalize();
  reset = true;
}

void mouseWheel(MouseEvent e) {
  
  int count = e.getCount();
  if      (keyPressed && (key == 'f' || key == 'F')) focalDistance *= pow(.97, count);
  else if (keyPressed && (key == 'a' || key == 'A')) aperture *= pow(.95, count);        //QWERTY: else if (keyPressed && (key == 'q' || key == 'Q')) aperture *= pow(.95, count);
  else focalLength *= pow(.95, count);
  reset = true;
}

void keyPressed() {

  if (key == 'z' || key == 'Z') z = true;        //QWERTY: if (key == 'a' || key == 'A') z = true;
  else if (key == 's' || key == 'S') s = true;
  else if (key == 'q' || key == 'Q') q = true;   //QWERTY: else if (key == 'w' || key == 'W') q = true;
  else if (key == 'd' || key == 'D') d = true;
  else if (key == ' ') up = true;
  else if (key == 'c' || key == 'C') down = true;
}

void keyReleased() {

  if (key == 'z' || key == 'Z') z = false;        //QWERTY: if (key == 'a' || key == 'A') z = false;
  else if (key == 's' || key == 'S') s = false;
  else if (key == 'q' || key == 'Q') q = false;   //QWERTY: else if (key == 'w' || key == 'W') q = false;
  else if (key == 'd' || key == 'D') d = false;
  else if (key == ' ') up = false;
  else if (key == 'c' || key == 'C') down = false;
}