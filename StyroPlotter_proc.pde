import processing.serial.*;
import geomerative.*; //http://www.ricardmarxer.com/geomerative/


Serial myPort;
PFont font;

// Shape definieren
RShape objShape;
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
int lstMsg; //last message sent

int warten = 0; //Variable um den Start der seriellen Kommunikation zu verzögern

boolean msgLock; //Plotqueue sperren, bis Antwort vom Arduino da ist



void setup(){
   
  msgQueue = new int[0];
    
  println(Serial.list());
  
  // Create Serial object on the first serial device with 9600 Baud
  myPort = new Serial(this, Serial.list()[0], 9600);
    
  myPort.buffer(4); //buffer 4 bytes of data before calling serialEvent()

  // Arbeitsfläche anlegen
  size(800 , 800); //Arbeitsfläche
  background(255); //Weiss
  stroke(0); //Schwarzer Strich
  font = createFont("Verdana", 14);
  
  // SVG laden, muss im sketch/data Ordner liegen
  RG.init(this);
  objShape = RG.loadShape("Ghost.svg");
  // in Punkte zerlegen und ins array schreiben
  points = objShape.getPoints();

}

void draw(){
    // Warteschleife am Anfang weil sich sonst die serielle Kommunikation verschluckt 
   if (warten == 0){
     delay(2000);
    warten = 1; 
   }
 
  // Plotqueue abarbeiten 
  parseQueue();
  
  //solange noch Punkte im Array sind Linie von Punkt zu Punkt zeichnen
  if (i<points.length-1){
     // Objekt auf der Arbeitsfläche zeichnen 
     line(points[i].x*faktor,points[i].y*faktor,points[i+1].x*faktor,points[i+1].y*faktor);
 
     // zwischenpunkte zischen den beiden koordinaten berechnen und dann in die Plotqueue schreiben
     move(round(points[i].x*faktor),round(points[i].y*faktor),round(points[i+1].x*faktor),round(points[i+1].y*faktor));  
      }
   else {
     //Motoren releasen nachdem geplottet wurde
      if (warten == 1){
           queueMessage(16);
        warten = 2; 
         }   
   }   
  //nächster Punkt
  i++; 
}

void keyPressed(){
  if(int(key) == 50){// Taste 2 RUNTER
    queueMessage(2); // y-
  }
  if(int(key) == 52){ //Taste 4 LINKS
    queueMessage(4); // x-
  }
  if(int(key) == 54){// Taste 6 RECHTS
    queueMessage(8); // x+
  }
  if(int(key) == 56){// Taste 8 RAUF
    queueMessage(1); // y+
  }
}


void move(int x0, int y0, int x1, int y1) {     /// Bresenham's Line Algorithm
  int md1, md2, s_s1, s_s2, ox, oy;
  int dx = abs(x1-x0), sx = x0<x1 ? 1 : -1;
  int dy = abs(y1-y0), sy = y0<y1 ? 1 : -1;
  int err = (dx>dy ? dx : -dy)/2, e2; 
  
  // Zwischenpunkte berechnen und die Bewegung in die Plotqueue schreiben
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
             
          //die Bewegung wird über bitcodierte Steuerbefehle an die serielle Schnittstelle geschickt.
          //0001: 	x0, 	y+ 		(1)
          //0010: 	x0, 	y- 		(2)
          //0100: 	x+, 	y0 		(4)
          //1000: 	x-, 	y0 		(8)
          //0101: 	x+, 	y+ 		(5)
          //0110: 	x+, 	y- 		(6)
          //1010: 	x-, 	y- 		(10)
          //1001: 	x-, 	y+ 		(9) 
          
          movement = 0; //Bewegungsvariable auf Null setzen
          
          // Bewegungsbits setzen
          if (y0 < oy) { // RUNTER
              movement = movement | 2; // AND 2
          };
          if (y0 > oy) { // RAUF
              movement = movement | 1;
          };
          if (x0 < ox) {  //LINKS
              movement = movement | 4;
          };
          if (x0 > ox) {  //RECHTS
              movement = movement | 8;
          };
          
          // Steuerbefehl in die Plotqueue schreiben         
          queueMessage(movement);   // Plotten
        }
  }



//Plotqueue befüllen
public void queueMessage(int msg){
  msgQueue = append(msgQueue, msg);
}


// Steuerbefehle per serial an den Arduino schicken
private void parseQueue(){
      if(msgQueue.length > 0 && !msgLock) {
      msgLock = true;  //Plotqueue sperren, damit keine Steuerbefehle verloren gehen 
      lstMsg = msgQueue[0]; //queue the first message on the stack
      writeSerial(lstMsg);
      println("writing message: " + lstMsg);
      msgQueue = subset(msgQueue, 1);
    }
}

// auf Antwort vom Arduino warten und dann die Plotqueue wieder freigeben 
void serialEvent(Serial myPort){
  if(myPort.available() > 0){
    
    String message = myPort.readString(); //read serial buffer
    int msg = int(message); //convert message to integer
    println(msgQueue.length);
    myPort.clear(); //clear whatever might be left in the serial buffer
    
    //wenn Antwort vom Arduino da ist, Meldung ausgeben und Sperrung aufheben
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



