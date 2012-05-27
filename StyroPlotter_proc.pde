import processing.serial.*;
import geomerative.*;

Serial myPort;
PFont font;

// Shape definieren
RShape s;
RPoint[] points;

// Zähler
int i=0; //  für Punkte
int zy; // für Schritte X
int zx;  // für Schritte Y
//Skalierungsfaktor
float faktor=1.3;


int movement = 0;
//Koordinaten nächste Teilstrecke
int steps_x = 0;
int steps_y = 0;
int x = 0;
int y = 0;

int msgQueue[]; //the message queue
boolean msgLock; //message lock, active until last message is confirmed
int lstMsg; //last message sent

int warten = 0;

void setup(){
   
  msgQueue = new int[0];
    
  println(Serial.list());
  myPort = new Serial(this, Serial.list()[0], 9600); //the highest connected COM port is always my Arduino
  myPort.buffer(4); //buffer 4 bytes of data before calling serialEvent()

// Bild laden und Punkte in Array schreiben
  size(800 , 800); //Arbeitsfläche
  background(255); //Weiss
  stroke(0); //Schwarzer Strich
  font = createFont("Verdana", 14);
  
  // SVG laden
  RG.init(this);
  s = RG.loadShape("luefterhaus.svg");
  // in Punkte zerlegen
  points = s.getPoints();

}

void draw(){
  // Warteschleife abarbeiten
 if (warten == 0){
   delay(2000);
  warten = 1; 
 }
 
  parseQueue();
  
  //solange noch Punke im Array sind Linie von Punkt zu Punkt zeichnen
  if (i<points.length-1){
    line(points[i].x*faktor,points[i].y*faktor,points[i+1].x*faktor,points[i+1].y*faktor);
    //println(i + " " + points.length); 
    move(round(points[i].x*faktor),round(points[i].y*faktor),round(points[i+1].x*faktor),round(points[i+1].y*faktor));  
      }
   else {
     //Motoren releasen
      if (warten == 1){
           queueMessage(16);
        warten = 2; 
         }   
   }   
//nächster Punkt
i++; 
}

void keyPressed(){
  if(int(key) == 50){// Taste 2 DOWN
    queueMessage(1); // x+
  }
  if(int(key) == 52){ //Taste 4 LEFT
    queueMessage(4); // x-
  }
  if(int(key) == 54){// Taste 6 RIGHT
    queueMessage(8); // y+
  }
  if(int(key) == 56){// Taste 8 UP
    queueMessage(2); // y-
  }
}


void move(int x0, int y0, int x1, int y1) {     /// Bresenham's Line Algorithm
  int md1, md2, s_s1, s_s2, ox, oy;
  int dx = abs(x1-x0), sx = x0<x1 ? 1 : -1;
  int dy = abs(y1-y0), sy = y0<y1 ? 1 : -1;
  int err = (dx>dy ? dx : -dy)/2, e2; 
  for(;;){    
    ox=x0;
    oy=y0;
    if (x0==x1 && y0==y1) break;
    e2 = err;
    if (e2 >-dx) { 
      err -= dy; 
      x0 += sx; 
    }    
    if (e2 < dy) { 
      err += dx; 
      y0 += sy; 
    }
    
movement = 0; //Bewegung auf Null setzen
    if (y0 < oy) { // Move DOWN
        //println ("Down");
        movement = movement | 2;
    };
    if (y0 > oy) { // UP
        //println ("Up");
        movement = movement | 1;
    };
    if (x0 < ox) {  //LEFT
        //println ("Left");
        movement = movement | 4;
    };
    if (x0 > ox) {  //RIGHT
        //println ("Right");
        movement = movement | 8;
    };
    
//println (movement);
 queueMessage(movement);   // Plotten
  }
}







/* serialEvent(Serial myPort)
 * called when the amount of bytes specified in myPort.buffer()
 * have been transmitted, converts serial message to integer,
 * then sets this value in the chair object
 */
void serialEvent(Serial myPort){
  if(myPort.available() > 0){
    
    String message = myPort.readString(); //read serial buffer
    int msg = int(message); //convert message to integer
    println(msgQueue.length);
    myPort.clear(); //clear whatever might be left in the serial buffer
    
    if(msg == 9999){
      println("Anweisung durchgeführt");
      msgLock = false;
    }
  }
}

private void writeSerial(int msg){
  if(myPort.available() > 0) myPort.clear(); //empty serial buffer before sending
  myPort.write(msg);
}

public void queueMessage(int msg){
  msgQueue = append(msgQueue, msg);
}

private void parseQueue(){
  
    if(msgQueue.length > 0 && !msgLock) {
      msgLock = true; //lock queue, preventing new messages from being sent
      lstMsg = msgQueue[0]; //queue the first message on the stack
      writeSerial(lstMsg);
      println("writing message: " + lstMsg);
      msgQueue = subset(msgQueue, 1);
    }

}

