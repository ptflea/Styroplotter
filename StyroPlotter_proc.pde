import processing.serial.*;
import geomerative.*; // http://www.ricardmarxer.com/geomerative/

Serial serialPort;
PFont font;

RPoint[] points;

int i = 0;
float scaleFactor = 1.3;
int msgQueue[];
int wait = 0; // Variable um den Start der seriellen Kommunikation zu verzögern
boolean msgLock; // Plotqueue sperren, bis Antwort vom Arduino da ist

void setup() {

    msgQueue = new int[0];

    serialPort = new Serial(this, Serial.list()[0], 9600);

    // Setze Serialbuffer-Größe auf 4 Bytes
    serialPort.buffer(4);

    // Arbeitsfläche (Drawing Canvas) erstellen
    size(800, 800);

    background(255);

    // Linienfarbe auf Schwarz setzen
    stroke(0);

    // Create font object for drawing text
    font = createFont("Verdana", 14);

    // Load given svg file in sketch/data
    RG.init(this);

    RShape objShape = RG.loadShape("Ghost.svg");

    // Break lines into smaller steps
    points = objShape.getPoints();

}

void draw() {

    // Warteschleife am Anfang weil sich sonst die serielle Kommunikation verschluckt
    if (wait == 0) {
        delay(2000);
        wait = 1;
    }

    // Plotqueue abarbeiten
    parseQueue();

    // Solange noch Punkte im Array sind Linie von Punkt zu Punkt zeichnen
    if (i < points.length - 1) {

        // Objekt auf der Arbeitsfläche zeichnen
        line(points[i].x * scaleFactor, points[i].y * scaleFactor,
             points[i + 1].x * scaleFactor, points[i + 1].y * scaleFactor);

        // Zwischenpunkte zischen den beiden koordinaten berechnen und dann in
        // die Plotqueue schreiben
        move(round(points[i].x * scaleFactor), round(points[i].y * scaleFactor),
             round(points[i + 1].x * scaleFactor), round(points[i + 1].y * scaleFactor));

    } else {

        // Motoren releasen nachdem geplottet wurde
        if (wait == 1) {
            queueMessage(16);
            wait = 2;
        }
    }

    // Nächster Punkt
    i++;
}

// Bresenham Linienalgorithmus
void move(int x0, int y0, int x1, int y1) {

    int md1, md2, s_s1, s_s2, ox, oy;

    int dx = abs(x1-x0)
        ,sx = (x0 < x1)? 1 : -1;

    int dy = abs(y1-y0)
        ,sy = (y0 < y1)? 1 : -1;

    int err = ((dx > dy)? dx : -dy)/2, e2;

    // Zwischenpunkte berechnen und die Bewegung in die Plotqueue schreiben
    for (;;) {

        ox = x0;
        oy = y0;

        if (x0 == x1 && y0 == y1) {
            break;
        }

        e2 = err;
        if (e2 > -dx) {
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
        if (y0 < oy) { // runter
            movement |= 2;
        }

        if (y0 > oy) { // rauf
            movement |= 1;
        }

        if (x0 < ox) { // links
            movement |= 4;
        }

        if (x0 > ox) { // rechts
            movement |= 8;
        }

        // Steuerbefehl in die Plotqueue schreiben
        queueMessage(movement);
    }
}


// Plotqueue befüllen
public void queueMessage(int msg) {
    msgQueue = append(msgQueue, msg);
}

// Ältester Eintrag aus der Queue entfernen und zurückgeben
public void dequeueMessage() {

    int msg = msgQueue[0];

    // Gesendete nachricht aus der Queue entfernen
    msgQueue = subset(msqQueue, 1);
    return msg;

}

// Steuerbefehle per serial an den Arduino schicken
private void parseQueue() {

    // Solange noch was in der queue liegt, und sie nicht gesperrt ist...
    if (msgQueue.length > 0 && !msgLock) {

        // Plotqueue sperren, damit keine Steuerbefehle verloren gehen
        msgLock = true;

        int msg = dequeueMessage();

        writeSerial(msg);
        println("writing message: " + msg);
    }

}

// auf Antwort vom Arduino warten und dann die Plotqueue wieder freigeben
void serialEvent(Serial serialPort) {

    if (serialPort.available() > 0) {

        String message = serialPort.readString(); // read serial buffer

        println(msgQueue.length);

        // Rest vom Serial-Inputbuffer löschen, falls irgendwas "übrig" ist
        serialPort.clear();

        // wenn Antwort vom Arduino da ist, Meldung ausgeben und Sperrung aufheben
        if (int(message) == 9999) {
            println("Anweisung durchgeführt");
            msgLock = false;
        }
    }

}

private void writeSerial(int msg) {

    if (serialPort.available() > 0) {
        serialPort.clear(); // Serial Port vor dem Senden leeren
    }
    serialPort.write(msg);

}
