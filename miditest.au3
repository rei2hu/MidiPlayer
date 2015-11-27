#cs ----------------------------------------------------------------------------
 AutoIt Version: 3.3.12.0
 Author:         reimu
 Version:        129831923819???
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


#include <GuiScrollBars.au3>
#include <ColorConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <FileConstants.au3>
#include <MsgBoxConstants.au3>
#include <WinAPIFiles.au3>
#include <File.au3>
#include <String.au3>
#include <Array.au3>
#include "format0parse.au3"
#include "format1parse.au3"
#include "format2parse.au3"
#include "vlvprocessing.au3"
#include "playnotes.au3"
#include "signedHex.au3"
;#include "GUIScrollbars_Ex.au3"

Opt("SendKeyDownDelay", 0)
Opt("SendKeyDelay", 0)

#cs ----------------------------------------------------------------------------
drag and drop onto exe
#ce ----------------------------------------------------------------------------

If $CmdLine[0] <> 0 Then
   $file = $CmdLine[1]
Else
   MsgBox(0, "Error", "did not drag file onto exe" & @CRLF & "will play default (Esoragoto.mid) if exists or crash")
   $file = "Esoragoto.mid"
   ;$file = "u.mid"
   ;$file = "sl.mid"
   ;$file = "b.mid"
   ;$file = "s.mid"
EndIf

#cs ----------------------------------------------------------------------------
gui and hotkey initializations, gui only for basic info
#ce ----------------------------------------------------------------------------

HotKeySet("{RIGHT}", "addSpeed")
HotKeySet("{LEFT}", "subSpeed")
HotKeySet("{SPACE}", "_Continue")
HotKeySet("{F10}", "Closebutton")

Local $GUIWidth = 300
Opt("GUIOnEventMode", 1)
Local $hMainGUI = GUICreate("pianer", 130, 120,"","",0x00800000,$WS_EX_TOPMOST)
GUICtrlCreateLabel("Note:", 10, 10, 50, 20)
GUICtrlCreateLabel("Delay:", 10, 30, 50, 20)
GUICtrlCreateLabel("Mult:", 10, 70, 50, 20)
GUICtrlCreateLabel("Tempo:", 10, 50, 50, 20)
Global $noteD = GUICtrlCreateLabel("$note", 50, 10, 200, 20)
Global $delayD = GUICtrlCreateLabel("$delay", 50, 30, 200, 20)
Global $tempoD = GUICtrlCreateLabel("$tempo", 50, 50, 200, 20)
Global $speedMultiplier = GUICtrlCreateLabel("5", 50, 70, 200, 20)
Global $state = GUICtrlCreateLabel("PAUSED", 100, 20, 200, 20)
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
;MsgBox(0, "", "Format: " & $format & @CRLF & "Tracks: " & $tracks & @CRLF & $tempoType & ": " & $tempo2)

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

; FIXING UP THE NOTES ================================================

Local $totalDelay
Local $m = 2

$notesAndDelay = StringSplit($noteInfo, @CRLF)
$tempoAndDelay = StringSplit ($tempoInfo, @CRLF)


For $k = 1 to $tempoAndDelay[0] Step +1
   If StringLen($tempoAndDelay[$k]) > 1 Then
	  $tempo = StringRegExpReplace($tempoAndDelay[$k], "\([0-9]+\)", "") + 0
	  $delay = StringRegExp($tempoAndDelay[$k], "\([0-9]+\)", 2)
	  $delay2 = StringTrimRight(StringTrimLeft($delay[0], 1),1)
	  GUICtrlSetData($tempoD, $tempo/1000)
	  ExitLoop
   EndIf
Next

;ConsoleWrite($noteInfo & @CRLF)
;ConsoleWrite($tempoInfo & @CRLF)

Local $ctrlleft = 0
Local $ctrltop = 0
Local $printwidth = 20
Local $currentpage = 1
Local $lastdeleted = 0
Local $lastadded
Local $cmplt
Local $tempdelay = 0
Local $hMainGUI2 = GUICreate("notes", $GUIWidth, 510, "", 151,0x00800000)
GUISetFont(12, 700)
Local $ctrlpos

Global $LEASTDELAY = 2048


; MAKING THE "VISUALIZER" LOL ========================================
; how it works
; loads 3000 notes at start
; once notes go offscreen, they are deleted from previously deleted note to most recent played
; then load notes from most recently loaded to amount of deleted notes (recent played - deleted
Local $visualize = MsgBox(4, "visualizer", "Would you like the visualizer?" & @CRLF & "there are " & $notesAndDelay[0] & " notes")
if $visualize=6 then
   if $notesAndDelay[0] < 2000 Then
	  $lastadded = $notesAndDelay[0]
   Else
	  $lastadded = 2000
   endif
   ;_AddNotesToGUI(0, $lastadded, true)
   ;_GUIScrollbars_Generate($hMainGUI2, $ctrlleft, $ctrltop+10)
   ;_GUIScrollBars_ShowScrollBar($hMainGUI2, $SB_BOTH, false)
   GUISetBkColor($COLOR_BLACK)
   GUISetState(@SW_SHOW, $hMainGUI2)
   ToolTip("")
else
   MsgBox(0, "", "Ready to play")
endif


; PLAYING THE NOTES ======================================================
; check if pause is on
; parse info into notes and delay (vlv time)
; sleep for the delay length
;
For $j = 1 to $notesAndDelay[0] Step +1

   ;If StringLen($notesAndDelay[$j]) > 4 Then
	  ;pause function
	  if not $binflag then
		 GUICtrlSetData($state, "PAUSED")
		 Do
			Sleep(1)
		 Until $binFlag
		 GUICtrlSetData($state, "PLAYING")
	  endif

	  ;parse
	  $note = StringLeft($notesAndDelay[$j], 1)
	  $delay = StringTrimLeft(StringTrimRight($notesAndDelay[$j], 1), 3)
	  $totalDelay += $delay

	  ;check tempo
	  If $totalDelay+1 >= $delay2 Then
		 For $k = $m to $tempoAndDelay[0] Step +1
			If StringLen($tempoAndDelay[$k]) > 1 Then
			   $tempo = StringRegExpReplace($tempoAndDelay[$k], "\([0-9]+\)", "") + 0
			   $delay3 = StringRegExp($tempoAndDelay[$k], "\([0-9]+\)", 2)
			   $totalDelay = $totalDelay - $delay2
			   ;$totalDelay = 0
			   $delay2 = StringTrimRight(StringTrimLeft($delay3[0], 1),1)
			   $m = $m + 1
			   GUICtrlSetData($tempoD, $tempo/1000)
			   ;ConsoleWrite("Playing at " & $tempo & " for " & $delay3 & " " & $delay2 & @CRLF)
			   ExitLoop
			EndIf
		 Next
	  EndIf

	  ;update notedisplay variable to include next note
	  if StringRegExp($note, "[0-9a-zA-Z!-)@^*]+")==1 then
		 $noteDisplay &= $note
	  EndIf

	  ;at the end of a chord display the note (if delay is 0 then notes will be displayed together)
	  If $delay <> 0 Then
		 if StringRegExp($noteDisplay, "[0-9a-zA-Z!-)@^*]+")==1 then
			GUICtrlSetData($noteD, $noteDisplay)
		 EndIf
		 GUICtrlSetData($delayD, $delay)
		 $noteDisplay = ""
	  EndIf

	  ;sleep before playing note
	  sleep(($tempo/1000) * $delay * GUICtrlRead($speedMultiplier)/10000)

	  if $delay <> 0 then
		 $tempdelay = $delay
	  endif
	  if $delay = 0 Then
		 $delay = $tempdelay
	  endif

	  _AddNotesToGUI2($note)
	  if StringRegExp($note, "?")==0 and StringRegExp($note, " ")==0 then
		 ControlSend("", "", "[CLASS:Chrome_RenderWidgetHostHWND; INSTANCE:1]", $note, 1)
		 GUICtrlSetColor(Eval("blu" & $j), _AlterBrightness($delay))
	  EndIf

	  ;get position of note thats was already played on gui and scroll if its too much
	  ;$ctrlpos = ControlGetPos("notes", "", Eval("blu" & $j))
	  if $ctrltop >= 480 then
		 ;$currentpage+=1
		 ;delete the notes that have been scrolled by
		 ;for $k=$lastdeleted to $j Step +1
			;GUICtrlDelete(Eval("blu" & $k))
		 ;Next
		 ;add $j-$whatever notes to the gui starting from $lastadded
		 ;example - added 1000 deleted 0-500, add starting from 1000, 500 notes
		 ;example2 - deleted 500 750, add starting from 1500, 250 notes
		 ;if $lastadded < $notesAndDelay[0] then
			;_AddNotesToGUI($lastadded, $j-$lastdeleted, false)
		 ;endif
		 ;_GUIScrollbars_Scroll_Page( $hMainGUI2,0, $currentpage)
		 ;Local $change = $j-$lastdeleted
		 ;$lastadded += $change
		 ;$lastdeleted = $j
		 $ctrltop=0
	  EndIf
   ;EndIf
Next



; FUNCTIONS ===========================================================
Func _AddNotesToGUI2($note)
   if $delay = 0 Then
	  $ctrlleft +=$printwidth/2
	  $blegh = 1
   elseif $delay <= 64 then
	  $ctrlleft +=$printwidth
	  $blegh = 2
   Elseif $delay <= 128 then
	  $ctrlleft +=$printwidth*2
	  $blegh = 4
   Elseif $delay <= 256 then
	  $ctrlleft +=$printwidth*4
	  $blegh = 8
   Elseif $delay <= 512 then
	  $ctrlleft +=$printwidth*8
	  $blegh = 16
   Elseif $delay <= 1024 then
	  $ctrlleft +=$printwidth*16
	  $blegh = 32
   Elseif $delay <= 2048 then
	  $ctrlleft +=$printwidth*32
	  $blegh =64
   Else
	  $ctrlleft +=$printwidth*64
	  $blegh = 128
   endif
   if $ctrlleft+18>$GUIWidth then
	  $ctrltop+=20
	  $ctrlleft=15 + ($ctrlleft - $GUIWidth)
   endif
   ;for $q=0 to $blegh step +1
	;  GUICtrlCreateLabel("", $ctrlleft, $ctrltop, 30, 20)
   ;Next
   if StringRegExp($note, "?")==0 and StringRegExp($note, " ")==0 then
	  Assign("blu" & $j, GUICtrlCreateLabel($note, $ctrlleft, $ctrltop, 30+$ctrlleft, 20), 2)
	  ;Assign("blu" & $j, GUICtrlCreateLabel("â–²", $ctrlleft, $ctrltop, 30+$ctrlleft, 20), 2)
   endif
   ;GUICtrlSetColor(Eval("blu" & $j), $COLOR_GREEN)
   GUICtrlDelete(Eval("blu" & $j-500))
EndFunc ;==>AddNotesToGUI2

Func _AddNotesToGUI($begin, $end, $init)
   Local $end2
   if not $init then
	  if $notesAndDelay[0] < $begin+$end Then
		 $end2 = $notesAndDelay[0]
	  Else
		 $end2 = $begin+$end
	  EndIf
   Else
	  $end2 = $end
   EndIf
   ;ConsoleWrite("Adding " & $begin & " to " & $end2 & @CRLF)
   for $p=$begin to $end2 Step +1
	  If StringLen($notesAndDelay[$p]) > 4 Then
		 $note = StringLeft($notesAndDelay[$p], 1)
		 $delay = StringTrimLeft(StringTrimRight($notesAndDelay[$p], 1), 3)
		 if $delay < $LEASTDELAY and $delay >= 64 then
			$LEASTDELAY = $delay
		 Endif
			if $delay = 0 Then
			   $ctrlleft += $printwidth/2
			elseif $delay <= 64 then
			   $ctrlleft +=$printwidth
			Elseif $delay <= 128 then
			   $ctrlleft +=$printwidth*2
			Elseif $delay <= 256 then
			   $ctrlleft +=$printwidth*4
			Elseif $delay <= 512 then
			   $ctrlleft +=$printwidth*8
			Elseif $delay <= 1024 then
			   $ctrlleft +=$printwidth*16
			Elseif $delay <= 2048 then
			   $ctrlleft +=$printwidth*32
			Else
			   $ctrlleft +=$printwidth*64
			endif
			if $ctrlleft+18>$GUIWidth then
			   $ctrltop+=15
			   $ctrlleft=15 + ($ctrlleft - $GUIWidth)
			endif
			Assign("blu" & $p, GUICtrlCreateLabel($note, $ctrlleft, $ctrltop), 2)
			;ConsoleWrite("added blu"&$p&@CRLF)
			GUICtrlSetColor(Eval("blu" & $p), $COLOR_WHITE)
	  EndIf
   Next

EndFunc ;==>AddNotesToGUI

Func _AlterBrightness($delay)

    Local $grn = 255-(255*(($LEASTDELAY/2)/($delay+1)))
    Local $red = 255-$grn
    Local $blu = 0
    Return LimitCol($red) * 0x10000 + LimitCol($grn) * 0x100 + LimitCol($blu)

EndFunc  ;==>AlterBrightness

Func limitCol($cc)
    If $cc > 255 Then Return 255
    If $cc < 0 Then Return 0
    Return $cc
EndFunc  ;==>limitCol











; OLD STUFF ==================================================================================================
; ============================================================================================================
; ============================================================================================================
; ============================================================================================================
; ============================================================================================================
; ============================================================================================================
; ============================================================================================================
; ============================================================================================================
; ============================================================================================================
; ============================================================================================================
; ============================================================================================================
; ============================================================================================================
; ============================================================================================================
; ============================================================================================================
; ============================================================================================================




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
