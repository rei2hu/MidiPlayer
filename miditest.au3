#cs ----------------------------------------------------------------------------
 AutoIt Version: 3.3.12.0
 Author:         reimu
 Version:        2
 Script Function:
	some midi stuff hex
	can be used for ONLY Format 0 or Format 1 midi files (I think)
    Format 0 MIDI files consist of a header-chunk and a single track-chunk.
    The single track chunk will contain all the note and tempo information.
    Format 1 MIDI files consist of a header-chunk and one or more track-chunks,
	with all tracks being played simultaneously.
    The first track of a Format 1 file is special, and is also kn>own as the 'Tempo Map'.
	It should contain all meta-events of the types Time Signature, and Set Tempo.
	The meta-events Sequence/Track Name, Sequence Number, Marker, and SMTPE Offset.
	should also be on the first track of a Format 1 file.
	Format information credits: https://www.csie.ntu.edu.tw/~r92092/ref/midi/
	Note: Only "last" track is played so tempo information is basically ignored
#ce ----------------------------------------------------------------------------

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <FileConstants.au3>
#include <MsgBoxConstants.au3>
#include <WinAPIFiles.au3>
#include <File.au3>
#include <String.au3>
#include <format0parse.au3>
#include <format1parse.au3>
#include <format2parse.au3>
#include <vlvprocessing.au3>
#include <playnotes.au3>
#include <signedHex.au3>

Opt("SendKeyDownDelay", 1)
Opt("SendKeyDelay", 1)

#cs ----------------------------------------------------------------------------
drag and drop onto exe
#ce ----------------------------------------------------------------------------

If $CmdLine[0] <> 0 Then
   $file = $CmdLine[1]
Else
   MsgBox(0, "Error", "did not drag file onto exe" & @CRLF & "will play default (Esoragoto.mid) if exists or crash")
   ;$file = "Esoragoto.mid"
   ;$file = "sl.mid"
   $file = "s.mid"
EndIf

#cs ----------------------------------------------------------------------------
gui and hotkey initializations, gui only for basic info
#ce ----------------------------------------------------------------------------

HotKeySet("{RIGHT}", "addSpeed")
HotKeySet("{LEFT}", "subSpeed")
HotKeySet("{SPACE}", "_Continue")
HotKeySet("{F10}", "Closebutton")

Opt("GUIOnEventMode", 1)
Local $hMainGUI = GUICreate("pianer", 200, 130,"","",0x00800000,$WS_EX_TOPMOST)
GUICtrlCreateLabel("Note:", 10, 10, 100, 20)
GUICtrlCreateLabel("Delay:", 10, 30, 100, 20)
GUICtrlCreateLabel("Mult:", 10, 50, 100, 20)
Global $noteD = GUICtrlCreateLabel("$note", 100, 10, 200, 20)
Global $delayD = GUICtrlCreateLabel("$delay", 100, 30, 200, 20)
Global $speedMultiplier = GUICtrlCreateLabel("5", 100, 50, 200, 20)
Global $state = GUICtrlCreateLabel("PAUSED", 20, 70, 200, 20)
GUISetState(@SW_SHOW, $hMainGUI)

#cs ----------------------------------------------------------------------------
functions and stuff
#ce ----------------------------------------------------------------------------

Func addSpeed()
   GUICtrlSetData($speedMultiplier, GUICtrlRead($speedMultiplier)+1)
EndFunc

Func subSpeed()
   GUICtrlSetData($speedMultiplier, GUICtrlRead($speedMultiplier)-1)
EndFunc

Func _Continue()
    $binFlag = Not $binFlag
 EndFunc

Func Closebutton()
   MsgBox("","Closing","Closing")
   Exit
EndFunc

#cs ----------------------------------------------------------------------------
processing midi
#ce ----------------------------------------------------------------------------

Local $note = ""
Local $notes = ""
Local $onAndOffNotes = ""
Local $actualNotes = ""
Local $newString = ""
Local $newNotes = ""
Local $delay = ""
Local $tempoInfo = ""
Local $timeInfo = ""
Local $noteInfo = ""
Local $delayTotal = 0
Local $tempoType = ""
Local $tempo2
Local $noteDisplay = ""
Dim $binFlag = False

Local $hFileOpen = FileOpen($file, 16)
Local $sFileRead = FileRead($hFileOpen)
FileClose($hFileOpen)

; MIDI FORMAT (HEX)

; trim 2 off left because it starts with 0x

; HEADER CHUNK SHOULD ALWAYS BE 14 BYTES LONG?
; 4 BYTES ; ######## should be 4D546864 which is MThd, the header chunk
; 4 BYTES ; ######## should be 00000006 which is the header length, (usually 6 but there can be outliers)
; 2 BYTES ; ####     should be how many tracks there are 0000 = 1 track, 0001 = multi track, 0002 = multi song
; 2 BYTES ; ####     should be number of track chunks that follow 000# = # of tracks
; 2 BYTES ; ####     "units per beat" or tempo
; So a header chunk should be formatted like 4D546864 00000006 #### (format) #### (tracks) #### (default delta time)

; trim 0x (2), MThd (8), header length (8) 8+8+2=18
$sFileRead = StringTrimLeft($sFileRead, 18)

$format = Dec(StringMid($sFileRead, 1, 4))
$tracks = Dec(StringMid($sFileRead, 5, 4))
$tempo = StringMid($sFileRead, 9, 4)

; DELTA TIME INFO
; MSB determines how it is structured
; BIT = 00 ; FOLLOWING BIT = 0-14 ; determines the number of delta-time units in each quater-note
; BIT = 01 ; FOLLOWING BIT = 0-7  ; determines the number of delta-time units per SMTPE frame
; BIT = 01 ; FOLLOWING BIT = 8-14 ; make it a negative number, represents the number of SMTPE frames per second (i dont get it)

Call("signMe", $tempo)

$sFileRead = StringTrimLeft($sFileRead, 12)
MsgBox(0, "", "Format: " & $format & @CRLF & "Tracks: " & $tracks & @CRLF & $tempoType & ": " & $tempo2)

; split into different tracks
$split = StringSplit($sFileRead, "4D54726B", 1)

Switch($format)
   Case "0"
	  Call("format0parse")
   Case "1"
	  Call("format1parse", $split)
   Case "2"
	  Call("format2parse")
   Case Else
	  MsgBox(0, "Error", "Format was not 0, 1, or 2")
EndSwitch

; PLAYING THE NOTES ================================================

Local $totalDelay
Local $m = 1

$notesAndDelay = StringSplit($noteInfo, @CRLF)
$tempoAndDelay = StringSplit ($tempoInfo, @CRLF)


For $k = 1 to $tempoAndDelay[0] Step +1
   If StringLen($tempoAndDelay[$k]) > 1 Then
	  $tempo = StringRegExpReplace($tempoAndDelay[$k], "\([0-9]+\)", "") + 0
	  $delay = StringRegExp($tempoAndDelay[$k], "\([0-9]+\)", 2)
	  $delay2 = StringTrimRight(StringTrimLeft($delay[0], 1),1)
	  ConsoleWrite($tempo & $delay & @CRLF)
	  ExitLoop
   EndIf
Next


For $j = 1 to $notesAndDelay[0] Step +1
   If StringLen($notesAndDelay[$j]) > 4 Then
	  $note = StringLeft($notesAndDelay[$j], 1)
	  $delay = StringTrimLeft(StringTrimRight($notesAndDelay[$j], 1), 3)
	  $totalDelay += $delay
	  ;ConsoleWrite($notesAndDelay[$j] & @CRLF)
	  ;ConsoleWrite($note & " (" & $delay & ")" & @CRLF)
	  ;ConsoleWrite("(" & $tempo & ") " & $totalDelay & ">=" & $delay2 & @CRLF)
	  If $totalDelay >= $delay2 Then
		 For $k = $m to $tempoAndDelay[0] Step +1
			If StringLen($tempoAndDelay[$k]) > 1 Then
			   $tempo = StringRegExpReplace($tempoAndDelay[$k], "\([0-9]+\)", "") + 0
			   $delay3 = StringRegExp($tempoAndDelay[$k], "\([0-9]+\)", 2)
			   $delay2 = StringTrimRight(StringTrimLeft($delay3[0], 1),1)
			   $m = $m + 1
			   $totalDelay = 0
			   ExitLoop
			EndIf
		 Next
	  EndIf
	  ControlSend("", "", "[CLASS:Chrome_RenderWidgetHostHWND; INSTANCE:1]", $note, 1)
	  ;sleep($delay * ($tempo/1000) * GUICtrlRead($speedMultiplier)/1000)
	  sleep(($tempo/1000) * $delay * GUICtrlRead($speedMultiplier)/10000)
	  Do
		 if not $binFlag then
			GUICtrlSetData($state, "PAUSED")
		 endif
		 Sleep(1)
	  Until $binFlag
	  GUICtrlSetData($state, "PLAYING")
	  If $delay = 0 Then
		 if not StringIsSpace($note) then
			$noteDisplay &= $note
		 EndIf
	  Else
		 GUICtrlSetData($delayD, $delay)
		 $noteDisplay = $note
	  EndIf
	  GUICtrlSetData($noteD, $noteDisplay)
   EndIf
Next

   #cs
   If ($delay <> 0) Then
	  Sleep(10*GUICtrlRead($speedMultiplier))
	  Sleep((($delay)*GUICtrlRead($speedMultiplier)/1000)-(10*GUICtrlRead($speedMultiplier)))
   EndIf
   MouseMove( MouseGetPos(0), (Dec($vel) - 30 )* (@DeskTopHeight / 97), 0)
   WinActivate("[CLASS:Chrome_RenderWidgetHostHWND; INSTANCE:1]", "")
   GUICtrlSetData($state, "PLAYING")
   ControlSend("", "", "[CLASS:Chrome_RenderWidgetHostHWND; INSTANCE:1]", $note, 1)
   #ce


































#cs


; TRACK CHUNK
; 4 BYTES ; ######## should be 4D54726B which is MTrk, the track chunk
; 4 BYTES ; ######## should be 0000000# which is the track length
; ? BYTES ; a sequenced track event

; trim length because StringSplit removes MTrk
$sFileRead = StringTrimLeft($sFileRead, 8)

; track 2 because track 1 = header track 2 = tempo map track 3 = actual notes
For $i = 1 To $split[0] Step +1

   $newNotes = ""
   $2split = StringRegExp($split[$i], "..", 3)
   For $k = 0 To UBound($2split)-1 Step +1
	  $newNotes &= $2split[$k] & " "
   Next
   ;ConsoleWrite($newNotes & @CRLF)

   $split[$i] = $newNotes
   ;$split[$i] = StringRegExpReplace($split[$i], "(91|92|93|94|95|96|97|98|99|9A|9B|9C|9D|9E|9F)", "90")
   ;$split[$i] = StringRegExpReplace($split[$i], "(81|82|83|84|85|86|87|80|89|8A|8B|8C|8D|8E|8F)", "80")
   ;$split[$i] = StringRegExpReplace($split[$i], " ", "")
   ;ConsoleWrite($split[$i] & @CRLF)

   $chunkLength = Dec(StringMid($split[$i], 1, 8)) & " (" & StringLen(StringTrimLeft($split[$i], 8)) & ")"
   ConsoleWrite("Chunk " & $i & ": " & @CRLF & "Length: " & $chunkLength & @CRLF)

   ; trim track length
   $myChunk = StringTrimLeft($split[$i], 8)
   ;ConsoleWrite($myChunk & @CRLF & @CRLF)
   $actualNotes = StringSplit($myChunk, "FF", 1)

   For $p = 1 to $actualNotes[0] Step +1
	  $metaEventIdentifier = StringRight(StringLeft($actualNotes[$p], 3), 2)
	  ConsoleWrite("(" & $metaEventIdentifier & ") " & @CRLF)
	  $stuff = StringReplace(StringTrimLeft($actualNotes[$p], 7), " ", "")
	  Switch($metaEventIdentifier)
		 Case "00"
			$trackInfo &= "Sequence Number: " & StringTrimRight(_HexToString($stuff), 1) & @CRLF
		 Case "01"
			$trackInfo &= "Text Event: " & StringTrimRight(_HexToString($stuff), 1) & @CRLF
		 Case "02"
			$trackInfo &= "Copyright Notice: " & StringTrimRight(_HexToString($stuff), 1) & @CRLF
		 Case "03"
			$trackInfo &= "Sequence: " & StringTrimRight(_HexToString($stuff), 1) & @CRLF
		 Case "04"
			$trackInfo &= "Instrument Name: " & StringTrimRight(_HexToString($stuff), 1) & @CRLF
;		 Case "58"
;			$trackInfo &= "Time Signature: " & Dec(StringLeft($stuff, 2)) & "/" & (2^Dec(StringRight(StringLeft($stuff, 4), 2))) & @CRLF
		 Case "59"
			$sharpFlatNumber = Dec(StringLeft($stuff, 2))
			$trackInfo &= "Flats(-)/Sharps(+): " & $sharpFlatNumber & @CRLF
		 Case Else
			;$trackInfo &= "Unknown Meta-Event. Prefix and info is " & StringTrimLeft($metaEvents[$i], 3)
	  EndSwitch
	  ConsoleWrite($trackInfo)
   Next

   If ($i == 3) Then
	  MsgBox(0, "MIDI Format", "This is a Format " & $trackAmount & " file with " & $chunkAmount & " tracks." & @CRLF & "-------------------------------------" & @CRLF & $trackInfo)
   EndIf


   ; if -1 then you get FF 2F 00 or just 2F 00, the end of the chunk
   ; if -2 then you get last meta event and rest of chunk
   $metaAndNotes = $actualNotes[UBound($actualNotes)-2]
   $lastMetaLength = Dec(StringLeft(StringTrimLeft($metaAndNotes, 4), 2))
   $actualData =StringTrimLeft($metaAndNotes, $lastMetaLength * 3 + 7)
   ;ConsoleWrite($actualData & @CRLF)
   ;$onAndOffNotes = StringRegExp($actualData, "90..", 3)
   $onAndOffNotes = StringSplit($actualData, " ", 1)

   For $j = 1 To $onAndOffNotes[0] Step +1
	  $notes = $onAndOffNotes[$j]
	  ;ConsoleWrite($notes & @CRLF)
	  If ($notes == 90) then
		 $not = $onAndOffNotes[$j+1]
		 $vel = $onAndOffNotes[$j+2]
		 $j = $j + 2
		 Switch Dec($not)
			Case "36"
			   $note = "1"
			Case "37"
			   $note = "!"
			Case "38"
			   $note = "2"
			Case "39"
			   $note = "@"
			Case "40"
			   $note = "3"
			Case "41"
			   $note = "4"
			Case "42"
			   $note = "$"
			Case "43"
			   $note = "5"
			Case "44"
			   $note = "%"
			Case "45"
			   $note = "6"
			Case "46"
			   $note = "^"
			Case "47"
			   $note = "7"
			Case "48"
			   $note = "8"
			Case "49"
			   $note = "*"
			Case "50"
			   $note = "9"
			Case "51"
			   $note = "("
			Case "52"
			   $note = "0"
			Case "53"
			   $note = "q"
			Case "54"
			   $note = "Q"
			Case "55"
			   $note = "w"
			Case "56"
			   $note = "W"
			Case "57"
			   $note = "e"
			Case "58"
			   $note = "E"
			Case "59"
			   $note = "r"
			Case "60"
			   $note = "t"
			Case "61"
			   $note = "T"
			Case "62"
			   $note = "y"
			Case "63"
			   $note = "Y"
			Case "64"
			   $note = "u"
			Case "65"
			   $note = "i"
			Case "66"
			   $note = "I"
			Case "67"
			   $note = "o"
			Case "68"
			   $note = "O"
			Case "69"
			   $note = "p"
			Case "70"
			   $note = "P"
			Case "71"
			   $note = "a"
			Case "72"
			   $note = "s"
			Case "73"
			   $note = "S"
			Case "74"
			   $note = "d"
			Case "75"
			   $note = "D"
			Case "76"
			   $note = "f"
			Case "77"
			   $note = "g"
			Case "78"
			   $note = "G"
			Case "79"
			   $note = "h"
			Case "80"
			   $note = "H"
			Case "81"
			   $note = "j"
			Case "82"
			   $note = "J"
			Case "83"
			   $note = "k"
			Case "84"
			   $note = "l"
			Case "85"
			   $note = "L"
			Case "86"
			   $note = "z"
			Case "87"
			   $note = "Z"
			Case "88"
			   $note = "x"
			Case "89"
			   $note = "c"
			Case "90"
			   $note = "C"
			Case "91"
			   $note = "v"
			Case "92"
			   $note = "V"
			Case "93"
			   $note = "b"
			Case "94"
			   $note = "B"
			Case "95"
			   $note = "n"
			Case "96"
			   $note = "m"
			Case Else
			   $note = "?"
			EndSwitch
			;FileWrite("notes.txt", $note)
			ConsoleWrite("(" & $delay & ") " & Dec($delay) & @CRLF)
			ConsoleWrite("(" & $not & " @" & $vel & ") " & $note & @CRLF)
			GUICtrlSetData($delayD, "(" & $delay & ") " & Dec($delay))
			GUICtrlSetData($noteD, "(" & $not & " @" & $vel & ") " & $note)
			$delay = Dec($delay)
			If ($delay <> 0) Then
			   Sleep(10*GUICtrlRead($speedMultiplier))
			   Sleep((($delay)*GUICtrlRead($speedMultiplier)/1000)-(10*GUICtrlRead($speedMultiplier)))
			EndIf
			MouseMove( MouseGetPos(0), (Dec($vel) - 30 )* (@DeskTopHeight / 97), 0)
			WinActivate("[CLASS:Chrome_RenderWidgetHostHWND; INSTANCE:1]", "")
			Do
			   if not $binFlag then
				  GUICtrlSetData($state, "PAUSED")
			   endif
			   Sleep(1)
			Until $binFlag
			GUICtrlSetData($state, "PLAYING")
			ControlSend("", "", "[CLASS:Chrome_RenderWidgetHostHWND; INSTANCE:1]", $note, 1)
			;Sleep(50)
			;FileWrite("notes.txt", $note & " || WAIT: " & $delay &@CRLF)
			$delay = ""
		 ElseIf ($notes == 80) then
			;FileWrite("notes.txt", " (" & $delay & ") ")
			ConsoleWrite("(" & $delay & ")" & Dec($delay) & @CRLF)
			$not = $onAndOffNotes[$j+1]
			$vel = Dec($onAndOffNotes[$j+2])
			$j = $j + 2
			GUICtrlSetData($delayD, "(" & $delay & ") " & Dec($delay))
			$delay = Dec($delay)
			If ($delay <> 0) Then
			   Sleep(10*GUICtrlRead($speedMultiplier))
			   Sleep((($delay)*GUICtrlRead($speedMultiplier)/1000)-(10*GUICtrlRead($speedMultiplier)))
			EndIf
			;FileWrite("notes.txt", "WAIT: " & $delay & $note & @CRLF)
			$delay = ""
		 Else
			$delay &= $notes
		 EndIf
   Next
Next
#ce
