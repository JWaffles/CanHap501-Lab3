/**
 **********************************************************************************************************************
 * @file       canhap501_lab3_Jeremy.pde
 * @author     Jérémy
 * @version    V1.0.0
 * @date       4-February-2022
 * @brief      
 **********************************************************************************************************************
 * @attention!!!
 * The base of this code was taken from:
 * @file       Maze.pde
 * @author     Elie Hymowitz, Steve Ding, Colin Gallacher
 * @version    V4.0.0
 * @date       08-January-2021
 * @brief      Maze game example using 2-D physics engine
 *
 **********************************************************************************************************************
 */

/* library imports *****************************************************************************************************/ 
import processing.serial.*;
import static java.util.concurrent.TimeUnit.*;
import java.util.concurrent.*;
/* end library imports *************************************************************************************************/  

/* scheduler definition ************************************************************************************************/ 
private final ScheduledExecutorService scheduler      = Executors.newScheduledThreadPool(1);
/* end scheduler definition ********************************************************************************************/ 

/* device block definitions ********************************************************************************************/
Board             haplyBoard;
Device            widgetOne;
Mechanisms        pantograph;

byte              widgetOneID                         = 5;
int               CW                                  = 0;
int               CCW                                 = 1;
boolean           renderingForce                     = false;
/* end device block definition *****************************************************************************************/

/* framerate definition ************************************************************************************************/
long              baseFrameRate                       = 120;
/* end framerate definition ********************************************************************************************/ 

/* elements definition *************************************************************************************************/

/* Screen and world setup parameters */
float             pixelsPerCentimeter                 = 40.0;

/* generic data for a 2DOF device */
/* joint space */
PVector           angles                              = new PVector(0, 0);
PVector           torques                             = new PVector(0, 0);

/* task space */
PVector           posEE                               = new PVector(0, 0);
PVector           fEE                                 = new PVector(0, 0); 

/* World boundaries */
FWorld            world;
float             worldWidth                          = 32.5;  
float             worldHeight                         = 20.0; 

float             edgeTopLeftX                        = 0.0; 
float             edgeTopLeftY                        = 0.0; 
float             edgeBottomRightX                    = worldWidth; 
float             edgeBottomRightY                    = worldHeight;

float             gravityAcceleration                 = 980; //cm/s2

/* Initialization of virtual tool */
HVirtualCoupling  s;


// GameZones
FBox zone1, zone2, zone3;
int currentZone = 0;

// Zone1 Stuff
FCircle[] bumps;

// Zone2 Stuff
FBox breakingBox;

// Zone3 Stuff
FCircle magnet;


FBox vicsousArea1;
boolean v1Showing = false;
FBox vicsousArea2;
boolean v2Showing = false;

/* text font */
PFont f;

int clock = 0;
/* end elements definition *********************************************************************************************/  

void setupGameObjects(){
  // Zone 1
  if(true){
    zone1 = new FBox(worldWidth/3, worldHeight);
    zone1.setPosition(worldWidth/6, worldHeight/2);
    zone1.setStatic(true);
    zone1.setSensor(true);
    zone1.setGrabbable(false);
    world.add(zone1);

    // Zone 1 stuff
    bumps = new FCircle[50];
    for(FCircle bump : bumps){
      bump = new FCircle(random(0.1, 1.0));
      bump.setPosition(random(bump.getSize(), worldWidth/3 - bump.getSize()), random(bump.getSize(), worldHeight - bump.getSize()));
      bump.setStatic(true);
      bump.setFriction(5);
      // bump.setFill(0);
      bump.setNoStroke();
      world.add(bump);
    }
  }

  // Zone 2
  if(true){
    zone2 = new FBox(worldWidth/3, worldHeight);
    zone2.setPosition(worldWidth/6*3, worldHeight/2);
    zone2.setStatic(true);
    zone2.setSensor(true);
    zone2.setGrabbable(false);
    zone2.setName("zone2");
    world.add(zone2);

    breakingBox = new FBox(worldWidth/9, worldHeight/3);
    breakingBox.setPosition(worldWidth/6*3, worldHeight/2);
    breakingBox.setStaticBody(true);
    breakingBox.setNoStroke();
    breakingBox.setFriction(100);
    breakingBox.setName("bbox");
    world.add(breakingBox);
  }

  // Zone 3
  if(true){
    zone3 = new FBox(worldWidth/3, worldHeight);
    zone3.setPosition(worldWidth/6*5, worldHeight/2);
    zone3.setStaticBody(true);
    zone3.setSensor(true);
    zone3.setName("zone3");
    zone3.setGrabbable(false);
    world.add(zone3);

    magnet = new FCircle(random(.5,2));
    magnet.setPosition(random(worldWidth/6*5 + magnet.getSize(), worldWidth - magnet.getSize()), random(magnet.getSize(), worldHeight - magnet.getSize()));
    magnet.setStatic(true);
    magnet.setNoStroke();
    // magnet.setFill(0,255,255);
    world.add(magnet);
  }
}

/* setup section *******************************************************************************************************/
void setup(){
  /* put setup code here, run once: */
  size(1300, 800);
  f = createFont("Arial", 16, true);

  /* device setup */
  haplyBoard          = new Board(this, "Com7", 0);
  widgetOne           = new Device(widgetOneID, haplyBoard);
  pantograph          = new Pantograph();
  
  widgetOne.set_mechanism(pantograph);
  widgetOne.add_actuator(1, CCW, 2);
  widgetOne.add_actuator(2, CW, 1);
  widgetOne.add_encoder(1, CCW, 241, 10752, 2);
  widgetOne.add_encoder(2, CW, -61, 10752, 1);
  widgetOne.device_set_parameters();
  
  /* 2D physics scaling and world creation */
  hAPI_Fisica.init(this); 
  hAPI_Fisica.setScale(pixelsPerCentimeter); 
  world               = new FWorld();

  setupGameObjects();
  
  /* Setup the Virtual Coupling Contact Rendering Technique */
  s = new HVirtualCoupling((0.75)); 
  s.h_avatar.setDensity(4); 
  // s.h_avatar.setFill(255,0,0); 
  s.h_avatar.setStroke(0);
  s.h_avatar.setSensor(true);
  s.h_avatar.setName("EE");

  s.init(world, edgeTopLeftX+worldWidth/2, edgeTopLeftY+2); 
  
  /* World conditions setup */
  // world.setGravity((0.0), gravityAcceleration); //1000 cm/(s^2)
  world.setEdges((edgeTopLeftX), (edgeTopLeftY), (edgeBottomRightX), (edgeBottomRightY)); 
  world.setEdgesRestitution(.4);
  world.setEdgesFriction(0.5);
  
  world.draw();
  
  /* setup framerate speed */
  frameRate(baseFrameRate);
  
  /* setup simulation thread to run at 1kHz */
  SimulationThread st = new SimulationThread();
  scheduler.scheduleAtFixedRate(st, 1, 1, MILLISECONDS);
}
/* end setup section ***************************************************************************************************/

/* draw section ********************************************************************************************************/
void draw(){
  /* put graphical code here, runs repeatedly at defined framerate in setup, else default at 60fps: */
  if(renderingForce == false){
    background(255);
    textFont(f, 22);
    world.draw();

    switch (currentZone) {
      case 0:
        fill(0, 0, 0);
        textAlign(CENTER);
        text("Enter a zone to being", width/2, 60);
        break;
      case 1:
        fill(0, 0, 0);
        textAlign(CENTER);
        text("How does it feel?", width/2, 60);
        break;
      case 2:
        fill(0, 0, 0);
        textAlign(CENTER);
        text("What is happening?", width/2, 60);
        break;
      case 3:
        fill(0, 0, 0);
        textAlign(CENTER);
        text("What is it?", width/2, 60);
        break;
      
    }
  }
}
/* end draw section ****************************************************************************************************/

// void contactResult(FContactResult result){

//   if(result.getBody1().getName() == "bbox" && result.getBody2().getName() == "EE"){
//     println("EE and BBox touching");
//   }

//   if(result.getBody1().getName() == "zone3" && result.getBody2().getName() == "EE"){
//     println("EE and BBox touching");
//   }
// }

void contactPersisted(FContact contact){
  if(contact.contains("EE", "zone3")){
    // println("Contact between ", contact.getBody1().getName(), " and ", contact.getBody2().getName());
    contact.getBody2().setDamping(200);
    float f = magnet.getSize() * 100;
    float dx = magnet.getX() - contact.getBody2().getX();
    float dy = magnet.getY() - contact.getBody2().getY();

    float dist = sqrt(abs(dy*dy - dx*dx));
    float force = f/(dist * dist);
    float angleR = atan(abs(dy)/abs(dx));

    float forcex = force * cos(angleR);
    float forcey = force * sin(angleR);
    
    contact.getBody2().addImpulse(forcex,forcey);
  }

  
  if(contact.contains("bbox", "EE")){
    clock++;
    // println("clock ",clock);
    if(clock >= 3){
      breakingBox.setSensor(true);
    } 
    breakingBox.setRestitution(5);
  }
}

void contactEnded(FContact contact){
  if(contact.contains("zone3", "EE")){
    contact.getBody2().setDamping(0);
  }
  if(contact.contains("zone2", "EE")){
    breakingBox.setSensor(false);
    clock = 0;
  }
}

/* simulation section **************************************************************************************************/
class SimulationThread implements Runnable{

  public void run(){
    /* put haptic simulation code here, runs repeatedly at 1kHz as defined in setup */
    renderingForce = true;
    
    if(haplyBoard.data_available()){
      /* GET END-EFFECTOR STATE (TASK SPACE) */
      widgetOne.device_read_data();
    
      angles.set(widgetOne.get_device_angles()); 
      posEE.set(widgetOne.get_device_position(angles.array()));
      posEE.set(posEE.copy().mult(200));  
    }
    
    s.setToolPosition(edgeTopLeftX+worldWidth/2-(posEE).x, edgeTopLeftY+(posEE).y-7); 
    s.updateCouplingForce();
 
    fEE.set(-s.getVirtualCouplingForceX(), s.getVirtualCouplingForceY());
    fEE.div(100000); //dynes to newtons
    
    torques.set(widgetOne.set_device_torques(fEE.array()));
    widgetOne.device_write_torques();
    
    s.h_avatar.setSensor(false);
    
    checkCurrentZone();
    world.step(1.0f/1000.0f);
  
    renderingForce = false;
  }
}
/* end simulation section **********************************************************************************************/

void checkCurrentZone(){
    if(s.h_avatar.isTouchingBody(zone1)) currentZone = 1;
    if(s.h_avatar.isTouchingBody(zone2)) currentZone = 2;
    if(s.h_avatar.isTouchingBody(zone3)) currentZone = 3;
}