# VarioTiny
Universelle Schaltstufe für Tipp-Anlagen

Bei all der Beschäftigung mit der "guten Alten Zeit" und der Fernsteuerungstechnik aus den Jugendjahren kam der Wunsch auf, es noch einmal mit einer Tipp-Anlage zu versuchen. Die 27 MHz-Technik ist ja immer noch geduldet. Und die Konkurrenz im Äther (CB-Funk, Garagentoröffner, Spielzeuge, Babyphons) gibt es ja fast nicht mehr. Es sollte doch eigentlich nichts dagegen sprechen.

Nur, die historischen Servos hatte ich in schlechter Erinnerung. Groß, schwer, stromhungrig und unzuverlässig. Wenn mich meine Erinnerungen nicht täuschen. Wie wäre es, halbwegs moderne Servos an eine Tipp-Anlage anzuschließen?

Gesagt, getan. Nach einigen mehr oder weniger ernstgemeinten Gedanken und einigen bierförmigen Ideenbeschleunigern entstand meine VarioTiny-Schaltstufe.

Diese passt auf die weit verbreiteten Varioton-Empfänger. Ist aber prinzipiell auch mit jedem anderen Empfänger verwendbar. Und erlaubt den Anschluss von bis zu drei Servos oder auch anderen "Standard"-Komponenten. Wie z.B. einem Fahrregler.

Das Herz des ganzen ist ein ATTiny45-Mikrocontroller. Die Schaltung selbst ist recht simpel. Ein Spannungsregler sorgt für maximal 5V am Chip. Eine Transistorstufe passt die Empfängersignale an den Controller an. Der Rest geschieht durch Software.

Mit den beiden Jumpern kann ich einstellen, woher der Empfänger seinen Saft bekommt und ob Servos und Empfänger aus einem Akku gespeist werden sollen. Das Gehäuse ist 3D-gedruckt.

Die Feinabstimmung der Tonfrequenzen geschieht durch "Lernen". Hat nichts mit KI zu tun, sondern mit einem speziellen Stecker auf einem der Servoanschlüsse schaltet die Schaltstufe in den Programmiermodus, misst die empfangene NF und speichert die Frequenz im EEPROM. Damit kann auch die Servozuordnung und Steilrichtung einfach eingestellt werden. Auch lassen sich damit andere Tonfrequenzsender einfach zuordnen. Und das ganze kann beliebig oft wiederholt werden.

Für die Motordrossel ist ein "nichtneutralisierender" Kanal mit 8 Zwischenpositionen programmiert.

Den ATTiny45 hab ich in BASCOM programmiert, das Programm belegt 95% der 4kByte.
Die Servos verhalten sich von der Steilgeschwindigkeit fast wie die Bellamatk-Rudermaschinen.
Der Mikrocontroller generiert an den 3 Servoausgängen den üblichen Servoimpuls von 1.5ms. Und misst die Frequenz des hereinkommenden Tonsignals, wenn es zu einer (vorher gespeicherten) Frequenz passt, wird der Servoimpuls am entsprechenden Ausgang um 0.5ms vergrößert oder verkleinert. Das gilt für die Kanäle Seite und Höhe. Für die Motordrossel wird beim passenden Ton der Servoimpuls in insgesamt 8 Stufen vergrößert oder verkleinert.
Wenn nur 4 Tonfrequenzen gespeichert sind, kann man mit den Tönen 3 und 4 wahlweise ein (Höhen-)Ruder ("neutralisierend") oder die Motordrossel ("nichtneutralisierend") steuernd. Sind nur 3 Kanäle "gelernt" steuert der 3. Kanal das Servo wie ein Schaltstern. Ein mal tasten rückt das Servo in der Sequenz "Neutral - links - Neutral - rechts - neutral" weiter.
