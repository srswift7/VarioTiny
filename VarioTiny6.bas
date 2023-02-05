' ##########################################################
' #
' # VARIOTINY 6
' #
' #                          (c) gruen-design.de 2015-2022
' #
' ##########################################################

' Eine universelle Tipp-Schaltstufe für Prop-Servos

' Am Eingang PB1 eines Attiny45 liegt eine NF zwischen 500Hz und 10kHz an.
' Am Besten natürlich schon in Rechteckform

' Der Komparator mach daraus Flanken, der Zeitabstand zwischen 2 0-1 - Flanken wird gemessen
' Die Daraus bestimmte Frequenz wird mit einer im EEPROM gespeicherten Vergleichsliste
' verglichen, bei übereinstimmung wird der Kanalimpuls von bis zu 3 angeschlossenen
' Servos (PB2, PB3, PB4) zwischen links / Mitte / rechts modifiziert

' Die Zuordnung der Servos zu den Tonfrequenzen kann in einem Lernmodus zugeordnet werden.
' Dazu ist vor dem Einschalten der PB2 mit 5+ zu verbinden. Bei jeder erkannten stabilen Tonfrequenz
' Wird das Servo an PB3 ein kurzer Ausschlag erzeugt.

' Wenn beim Einschalten der PB2 frei ist, oder mit einem Servo verbunden, wird nach der Initialisierung
' Die Anzahl der zugeordneten Tonfrequenzen als Servobewegungen an PB3 ausgegeben.

' PB4 ist als Motordrossel geschaltet, jeder Impuls auf K3 / K5 erhöht die Motordrehzahl (8 Stufen bis Vollgas)
' jeder Impuls auf K4 / K6 verringert die Drehzahl

' Im Falle des Dreikanalbetriebes ist der Servoanschluss an PB4 als Schaltstern
' programmiert mit der Impulsfolge  => links, Mitte, Rechts, Mitte, Links

'---------------------------------------------------------


$prog &HFF , &HE2 , &HDF , &HFF                  ' Take care that the chip supports all fuse bytes.

$regfile = "ATtiny45.DAT"                        ' ATTiny / ATmega8-Deklarationen
' $crystal = 3686400                             ' Quarz: 3,6864 MHz
$crystal = 8000000                               ' Kein Quarz, 8MHz


Const TOLERANZ = 3


Declare Sub Flanke()                             ' Callback fuer Frequenzmessung (Timer0, ACI)
Declare Sub Ms20_loop()                          ' Callback fuer 20ms Loop, (Timer 1, ueberlauf)
Declare Sub Beep()                               ' Kurz mit einem Servo wedeln
Declare Sub Lernen()
Declare Sub Analyze_sr()
Declare Sub Sr_in(byval Zeit As Byte)
Declare Sub Kanalimpulse()

Declare Function ober_limit(byval Zahl As Byte) As Byte
Declare Function unter_limit(byval Zahl As Byte) As Byte
Declare Function match(byval Zahl As Byte) As Byte

Dim Zahl As Byte
Dim Zu As Byte
Dim Zo As Byte

Dim Sregister(10) As Byte  ' Hier laufen die gemessenen Tonfrequenzen ein (Zeit zwischen 2 Flanken
Dim Kregister(10) As Byte  ' Hier sind die "gematchten" letzten 10 Kanäle

Dim Decision(6) As Byte

' Dim Kanal As Byte

Dim Semaph As Bit
Dim Neutral As Bit
Dim Ncount As Byte
Dim Direction As Bit
Dim Motor As Byte

Dim Uu As Integer

Dim Lernmod As Bit

Dim Ii As Integer

' Die Permanenten Kanalspeicher
Dim Ekan As Eram Byte
Dim Ee_k(6) As Eram Byte

Dim Lkan As Byte
Dim Iii As Byte

' Die Grenzwerte
Dim U_k(6) As Byte
Dim O_k(6) As Byte

Dim Copyright As String * 26

' Das ist einfach nur, damit man diese schöne Zeichenkette im Flash sehen kann
Copyright = "c( )rgeu-nedisngd. e0232"

Dim Uhr_an As Bit
' Dim Count As Byte

Ddrb = &B00011100                                ' Pin PB2-4 als Ausgang konfigurieren
Portb = &B00000000                               ' Ausgaenge auf 0, kein pullup

' Und dann noch der Komparator, (D7)
Acsr = &B01001011                                ' Interne Referenz

' Nein, wir zählen nicht, wir stoppen die Zeit von Flanke zu Flanke. Dazu nehmen wir den Timer0

' Timer zum stoppen der Zeit zwischen 2 Flanken
On Aci Flanke
Config Timer0 = Timer , Prescale = 64            ' Timer-Takt ist Quarz/64,
                                                 ' bei 8MHz Takt hat der Timer dann 125 kHz
                                                 ' Das bedeutet 12.5 ticks bei 10 kHz Tonfrequenz

Timer0 = 0
Uhr_an = 0

Semaph = 0
' Fuer die 20ms nehmen wir einen 2. Timer

Config Timer1 = Timer , Prescale = 1024          ' Timer-Takt ist Quarz/1024
On Timer1 Ms20_loop

Enable Timer1                                    ' Timer0-Overflow-Interrupt ein
' Takt/1024 = 3600 Hz
'         72 Zähltakte (3.6 MHz)
' 20 ms = 125 Zähltakte  (6.4MHz)
'          156 Zähltakte (8MHz)
Timer1 = 100                                     ' 256 - x

Disable Interrupts                               ' Interrupts erst einmal global verhindern

Waitms 1000

Lernmod = 0                                      ' Den Lernmodus erkennen wir (nachher) an einer Drahtbrücke
Zahl = 0
' Kanal = 0

' Am Anfang prüfen wir mit Pin B2, ob wir im Programmiermodus sind
' Dazu programmieren wir den Pin auf Eingang ohne Pull-Up. Wir ziehn den Pin extern mit 20k auf Masse.
' Zum Programmieren legen wir ihn auf 5V

Ddrb.2 = 0                                        ' Eingang
Portb.2 = 0                                       ' Kein Pull UP für B2

' Abfrage Pin B2 - sind wir im Programmiermodus?

Lernmod = Pinb.2

If Lernmod = 1 Then
   Ekan = 0

   Wait 5
   Call Beep
Else
   ' Wir programmieren jetzt nicht, also B2 ist ein Ausgang wie alle anderen auch.
   Ddrb.2 = 1                                     ' Ausgang
   Portb.2 = 0                                    ' Low B2

   ' Basisvoreinstellung, der Chip ist noch nicht belernt
   ' Geteste wurde mit folgenden Sendern:

   If Ekan < 1 Or Ekan > 6 Then                   ' Es wurde noch nicht gelernt, Voreinstellung in den EEPROM
     ' Pilot-4
     Ee_k(1) = 68       ' Pilot-4 K1
     Ee_k(2) = 47       ' Pilot-4 K2
     Ee_k(3) = 95       ' Pilot-4 K3
     Ee_k(4) = 32       ' Pilot-4 K4
     Ekan = 4

     ' Varioton S (4-Kanal)
     ' Ee_k(1) = 155   ' Varioton K1
     ' Ee_k(2) = 115   ' Varioton K2
     ' Ee_k(3) = 75    ' Varioton K3
     ' Ee_k(4) = 55    ' Varioton K4
     ' Ekan = 4

     ' Mecatron - 3
     ' Ee_k(1) = 56   ' Mecatron K1
     ' Ee_k(2) = 46   ' Mecatron K2
     ' Ee_k(3) = 38   ' Mecatron K3
     ' Ekan = 3

     ' Junior-5
     ' Ee_k(1) = 34   ' Junior-5 K1
     ' Ee_k(2) = 42   ' Junior-5 K2
     ' Ee_k(3) = 51   ' Junior-5 K3
     ' Ee_k(4) = 63   ' Junior-5 K4
     ' Ee_k(5) = 82   ' Junior-5 K5
     ' Ekan = 5
   End If
   
   ' Initialisierung, lesen wir die Kanalwerte aus dem EEPROM und berechnen die Grenzen
   ' Wir berechnen die Toleranzbereiche der Tonfrequenzen aus dem gelernten Mittelwert +-TOLERANZ
   Lkan = Ekan
   For Ii = 1 To Lkan
     U_k(Ii) = unter_limit(Ee_k(Ii))
     O_k(Ii) = ober_limit(Ee_k(Ii))
   Next Ii

   ' Ausgabe : Wieviel Kanäle haben wir denn ?
   Lkan = Ekan
   For Iii = 1 To Lkan
     Call Beep
     Waitms 100
   Next

End If


'---------------------------------------------------------

Enable Interrupts                                           'Interrupts global zulassen
' doppelt?
Sreg.7 = 1                                                  'Interrupts global einschalten

Direction = 1

Do                                                          'Hauptschleife
Loop

'---------------------------------------------------------

END

' Eintragen gemessenen Zeit ins Schieberegister
Sub Sr_in(byval Zeit As Byte)
   Local Li As Byte
   Local I1 As Byte
   Local I2 As Byte

   I1 = 10
   For Li = 1 to 9
       I2 = I1 - 1
       Sregister(I1) = Sregister (I2)
       I1 = I2
   next Li
   Sregister(1) = Zeit
End Sub Sr_in


' Lernen der Kanalfrequenzen, Basis ist das Schieberegister
' machen wir erst mal ganz einfach, die 10 Werte des Sr muessen im +-1 er raster liegen
' Ekan ist Global und enthaelt die Nummer des zuletzt gelernten Kanals
Sub Lernen()
  Local Count As Byte
  Zahl = Sregister(1)
  Zu = unter_limit(Zahl)
  Zo = ober_limit(Zahl)

  ' Alle Messwerte muessen innerhalb der Toleranz liegen
  For Count = 2 To 10
     If Sregister(count) < Zu Or Sregister(count) > Zo Then Zahl = 0
  Next

  ' Mehr als 6 Frequenzen nehmen wir erst mal nicht
  If Ekan > 5 then Zahl = 0    ' Wenn wir schon 6 haben, brauchen wir nicht mehr lernen

  If Zahl > 5 And Zahl < 181 Then
     ' Der Messwert koennte eine Frequenz sein. Wir pruefen ob diese schon registriert ist
     Lkan = Ekan+1 ' naechste freie Frequenz

     if lkan > 0 then
        For Count = 1 to lkan
           If Zahl > U_k(Count) And Zahl < O_k(Count) Then Zahl = 0
        next count
        If Zahl > 0 then ' Eine gueltige Frequenz
           U_k(lkan) = Zu
           O_k(lkan) = Zo
           Ee_k(lkan) = Zahl
           Ekan = Lkan
           ' Disable Interrupts
           Call Beep
           ' Print "Erfolgreich gelernt, Zahl = " ; Zahl ; " Ekan = " ; Lkan
           ' Enable Interrupts
        End If
     End If
  End If
End Sub Lernen


' Prueft, ob ein Messwert zu einem der Kanaele Passt
Function match(byval Zahl As Byte) As Byte
  Local Li As Byte
  match = 0

  For Li = 1 To Ekan
     If Zahl > U_k(Li) And Zahl < O_k(Li) Then match = Li
  Next
End Function match


' Prueft die Messwerte, aus dem Schieberegister und matcht gegen die Kanalfrequenzen und ruft die Kanalimpulse
Sub Analyze_sr()
  Local Count As Byte
  Local Li As Byte
  Local Xkanal As Byte
  Local Lneutral As Byte

  ' Welche Kanaele hatten wir bei den letzten 10 Versuchen gefunden?
  ' Kregister(count) = 0
  ' Die Messdaten sind im Schieberegister, wir matchen sie gegen die Kanalfrequenzen
  ' in das Kregister
  ' vorher koennte erst noch eine Kurvenglaettung erfolgen
  For Li = 1 To 10
     Kregister(Li) = match(Sregister(Li))
  Next

  ' Entprellen, Motorfunktion nur, nachdem zwischendurch Pause war
  Lneutral = 0

  For Xkanal = 1 To 6  ' Schleife über die möglichen Kanalfrequenzen

     Count = 0
     For Li = 1 to 10
        If Kregister(Li) = Xkanal then
           incr Count
        End if
     Next Li
     If Count > 3 then ' Wenn innerhalb der letzten 200ms wenigstens 4 mal die gleiche Frequenz gemessen wurde, gilt der Tonkanal als aktiv
       Decision(Xkanal) = 1
       Lneutral = 1
     Else
       Decision(Xkanal) = 0
     End If
  Next

  Call Kanalimpulse ()

  ' Neutral wird auf 1 gesetzt falls ein Kanal erkannt wurde, sonst 0
  ' Neutral = Lneutral

  If Lneutral = 0 then
     incr ncount
  else
      ncount = 0
  end if

  If ncount > 4 then
     Neutral = 0
     ncount = 5
  end if

End Sub Analyze_sr


' so und hier müssen wir jetzt noch die Kanalimpulse stricken
' Xkanal enthaelt eine Zahl zwischen 0 und 6, genau, den Tonfrequenzkanal
' Lval sagt, ob der Kanal Aktiv ist, oder nicht
'
' Die Motordrossel als nichtneutralisierender Kanal in 8 Stufen oder als Schaltkanal
'
Sub Kanalimpulse ()
   Dim gerade as byte

   ' Die Steuerung der Motordrossel / des Schaltsterns
   If Neutral = 0 Then
         ' Das ist erst mal der 6-Kanalmodus
         If Ekan = 6 Then
            If Decision(5) = 1 And Motor < 8 Then Incr Motor
            If Decision(6) = 1 And Motor > 0 Then Decr Motor
         End if

         ' Das ist der 5-Kanalmodus
         If Ekan = 5 Then
            If Decision(5) = 1 And Motor < 2 And Direction = 1 Then Incr Motor
            If Decision(5) = 1 And Motor > 0 And Direction = 0 Then Decr Motor
            If Motor = 2 Then Direction = 0
            If Motor = 0 Then Direction = 1
         End If

         ' Das ist der 4-Kanalmodus
         If Ekan = 4 Then
            If Decision(3) = 1 And Motor < 8 Then Incr Motor
            If Decision(4) = 1 And Motor > 0 Then Decr Motor
         End if

         ' Das ist der 3-Kanalmodus
         If Ekan = 3 Then
            If Decision(3) = 1 And Motor < 2 And Direction = 1 Then Incr Motor
            If Decision(3) = 1 And Motor > 0 And Direction = 0 Then Decr Motor
            If Motor = 2 Then Direction = 0
            If Motor = 0 Then Direction = 1
         End If

         ' Das ist der 2-Kanalmodus
         If Ekan = 2 Then
            If Decision(1) = 1 And Motor < 8 Then Incr Motor
            If Decision(2) = 1 And Motor > 0 Then Decr Motor
         End if

         ' Das ist der 1-Kanalmodus
         If Ekan = 1 Then
            If Decision(1) = 1 And Motor < 2 And Direction = 1 Then Incr Motor
            If Decision(1) = 1 And Motor > 0 And Direction = 0 Then Decr Motor
            If Motor = 2 Then Direction = 0
            If Motor = 0 Then Direction = 1
         End If
         Neutral = 1
   End If

   ' Jetzt bauen wir die Kanalimpulse
   ' Seite B2
   ' Hoehe B3
   ' Motor B4

   Uu = 0
   For Ii = 1 to 6  ' Wir erzeugen 3 Kanalimpulse, auch wenn wir weniger Kanäle haben
      Gerade = Ii AND 1
      If Decision(Ii) = 1 then
         If Gerade = 1 then
            Uu = 1000
         Else
            Uu = 2000
         End If
      End If

      ' Ein Kanalimpuls für Seite wird erzeugt
      If Ii  = 2 then
         If Uu = 0 then
            Uu = 1500
         End if
         Portb.2 = 1
         Waitus Uu
         Portb.2 = 0
         Uu = 0
      End If

      ' Ein Kanalimpuls für Höhe wird erzeugt
      If Ii= 4 then
         If Uu = 0 then
            Uu = 1500
         end if
         Portb.3 = 1
         Waitus Uu
         Portb.3 = 0
         Uu = 0
      End If

      ' Die Motordrossel hat eine eigene Logik
      ' Be Gerader Kanalanzahl 8 Stufen. sonst Schaltstern

      If Ii = 6 then ' B4 ist immer die Motordrossel
         Gerade = Ekan AND 1

         If Gerade = 0 Then
            Uu = Motor * 125
         Else
            Uu = Motor * 500
         End If

         Uu = Uu + 1000

         Portb.4 = 1
         Waitus Uu
         Portb.4 = 0
      End If
   Next Ii

End Sub Kanalimpulse


' Interruptroutine fuer die 20ms-schleife
' Die aktuellen Messwerte liegen im Schieberegister
Sub Ms20_loop ()

  Semaph = 1
  Disable Interrupts                              ' Waehrend der Kanalimpulse messen wir auch keine Frequenzen
  If Lernmod = 1 Then Call Lernen
  If Lernmod = 0 Then Call Analyze_sr

  Timer1 = 100                                    ' 256 - x
  Timer0 = 0
  Uhr_an = 0
  Enable Interrupts                               ' Waehrend der Kanalimpulse messen wir auch keine Frequenzen
  Semaph = 0

End Sub Ms20_loop


' Interruptroutine fuer Datenkanal
Sub Flanke()
   If Semaph = 0 then ' Die Kanalimpulse haben prio
     ' Local Zeit as Byte
     If Uhr_an = 1 Then
        ' Flanke = Uhr aus
        Uhr_an = 0
        Zahl = Timer0                               ' Zahl ist globel
        Call Sr_in (Zahl)
     Else
        Uhr_an = 1
        Timer0 = 0
     End If
   Else ' Ein Interrupt zur Unzeit, Ruecksetezen
     Timer0 = 0
     Uhr_an = 0
   End if
End Sub Flanke


Function ober_limit(byval Zahl As Byte) As Byte
  ober_limit = Zahl + TOLERANZ
End Function ober_limit

Function unter_limit(byval Zahl As Byte) As Byte
  unter_limit = Zahl - TOLERANZ
End Function unter_limit


' Eine kleine Rückmeldung, wir lassen das Servo an K2 und K3 kurz wirbeln
Sub Beep()

  Local Li As Byte

  ' Disable Interrupts                            'Interrupts global verhindern
  For Li = 1 To 20
     Portb.3 = 1
     ' Portb.4 = 1
     Waitus 1000
     Portb.3 = 0
     ' Portb.4 = 0
     Waitus 19000
  Next

  For Li = 1 To 20
     Portb.3 = 1
     ' Portb.4 = 1
     Waitus 1500
     Portb.3 = 0
     ' Portb.4 = 0
     Waitus 18500
  Next
  ' Enable Interrupts                             'Interrupts global zulassen
End Sub Beep


END