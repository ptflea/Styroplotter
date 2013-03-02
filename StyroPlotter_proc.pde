import processing.serial.*;
import geomerative.*; //http://www.ricardmarxer.com/geomerative/


Serial myPort;
PFont font;

// Shape definieren
RShape objShape;
RPoint[] points;


// Zähler
int i = 0;  //  für Punkte
int zy;     // für Schritte X
int zx;     // für Schritte Y

// Skalierungsfaktor
float faktor = 1.3;

// Koordinaten nächste Teilstrecke
int steps_x = 0;
int steps_y = 0;

int x = 0;
int y = 0;


int msgQueue[]; //the message queue

int wait = 0; //Variable um den Start der seriellen Kommunikation zu verzögern

boolean msgLock; //Plotqueue sperren, bis Antwort vom Arduino da ist



void setup(){
   
    msgQueue = new int[0];
    
    myPort = new Serial(this, Serial.list()[0], 9600);
    
    // Setze Serialbuffer-Größe auf 4 Bytes
    myPort.buffer(4);

    // Arbeitsfläche (Drawing Canvas) erstellen
    size(800, 800);

    background(255);

    // Linienfarbe auf Schwarz setzen
    stroke(0);

    // Create font object for drawing text
    font = createFont("Verdana", 14);
  
    // Load given svg file in sketch/data
    RG.init(this);
    objShape = RG.loadShape("Ghost.svg");

    // Break lines into smaller steps
    points = objShape.getPoints();

}

void draw() {

    // Warteschleife am Anfang weil sich sonst die serielle Kommunikation verschluckt 
    if (wait == 0){
        delay(2000);
        wait = 1; 
    }
 
    // Plotqueue abarbeiten 
    parseQueue();
  
    //solange noch Punkte im Array sind Linie von Punkt zu Punkt zeichnen
    if(i < points.length-1) {

        // Objekt auf der Arbeitsfläche zeichnen 
        line(points[i].x * faktor,points[i].y * faktor,points[i+1].x * faktor,points[i+1].y * faktor);
 
        // zwischenpunkte zischen den beiden koordinaten berechnen und dann in die Plotqueue schreiben
        move(round(points[i].x*faktor),round(points[i].y*faktor),round(points[i+1].x*faktor),round(points[i+1].y*faktor));  
    } else {

        //Motoren releasen nachdem geplottet wurde
        if (wait == 1){
            queueMessage(16);
            wait = 2; 
        }   
    }

    //nächster Punkt
    i++; 
}

void move(int x0, int y0, int x1, int y1) {     /// Bresenham's Line Algorithm

    int md1, md2, s_s1, s_s2, ox, oy;
    int dx = abs(x1-x0), sx = x0<x1 ? 1 : -1;
    int dy = abs(y1-y0), sy = y0<y1 ? 1 : -1;
    int err = (dx>dy ? dx : -dy)/2, e2; 
  
    // Zwischenpunkte berechnen und die Bewegung in die Plotqueue schreiben
    for(;;){

        ox = x0;
        oy = y0;

        if (x0 == x1 && y0 == y1){
            break;
        }

        e2 = err;
        if (e2 >-dx) { 
            err -= dy; 
            x0 += sx; 
        }

        if (e2 < dy) { 
            err += dx; 
            y0 += sy; 
        }

        /*
        * die Bewegung wird über bitcodierte Steuerbefehle an die serielle Schnittstelle geschickt.
        * 0001:     x0,     y+      (1)
        * 0010:     x0,     y-      (2)
        * 0100:     x+,     y0      (4)
        * 1000:     x-,     y0      (8)
        * 0101:     x+,     y+      (5)
        * 0110:     x+,     y-      (6)
        * 1010:     x-,     y-      (10)
        * 1001:     x-,     y+      (9)
        */
          
        int movement = 0; //Bewegungsvariable auf Null setzen
          
        // Bewegungsbits setzen
        if (y0 < oy) { // RUNTER
            movement = movement | 2; // AND 2
        }

        if (y0 > oy) { // RAUF
            movement = movement | 1;
        }

        if (x0 < ox) {  //LINKS
            movement = movement | 4;
        }

        if (x0 > ox) {  //RECHTS
            movement = movement | 8;
        }

        // Steuerbefehl in die Plotqueue schreiben         
        queueMessage(movement);
    }
}


// Plotqueue befüllen
public void queueMessage(int msg){
    msgQueue = append(msgQueue, msg);
}

// Ältester Eintrag aus der Queue entfernen und zurückgeben
public void dequeueMessage() {
    int msg = msgQueue[0];

    // Gesendete nachricht aus der queue entfernen
    msgQueue = subset(msqQueue, 1);
    return msg;
}


// Steuerbefehle per serial an den Arduino schicken
private void parseQueue() {

    // Solange noch was in der queue liegt, uns sie nicht gesperrt ist...
    if(msgQueue.length > 0 && !msgLock) {

        // Plotqueue sperren, damit keine Steuerbefehle verloren gehen 
        msgLock = true;  
        
        int msg = dequeueMessage();

        writeSerial(msg);
        println("writing message: " + msg);
    }
}

// auf Antwort vom Arduino warten und dann die Plotqueue wieder freigeben 
void serialEvent(Serial myPort){

    if(myPort.available() > 0) {

        String message = myPort.readString(); //read serial buffer

        println(msgQueue.length);

        // Rest vom Serial-Inputbuffer löschen, falls irgendwas "übrig" ist
        myPort.clear();

        //wenn Antwort vom Arduino da ist, Meldung ausgeben und Sperrung aufheben
        if(int(message) == 9999) {
            println("Anweisung durchgeführt");
            msgLock = false;
        }
    }
}



private void writeSerial(int msg){
    if(myPort.available() > 0) {
        myPort.clear(); //empty serial buffer before sending
    }
    myPort.write(msg);
}


