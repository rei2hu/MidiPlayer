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
#include <Math.au3>
#include "format0parse.au3"
#include "format1parse.au3"
#include "format2parse.au3"
#include "vlvprocessing.au3"
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
   $file = "th4_09.mid"
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

Dim $binFlag = False

Local $hFileOpen = FileOpen($file, 16)
Local $sFileRead = FileRead($hFileOpen)
FileClose($hFileOpen)

; trim 2 off because it starts with 0x
$sFileRead = StringTrimLeft($sFileRead, 2)
Local $tBytes = StringSplit($sFileRead, "")

Local $pointerPos = 1;

Func nextBytes($bytes, $number)
   $number = $number
   $ret = ""
   For $i = 0 to $number - 1
	  $ret = $ret & $bytes[$pointerPos + $i]
   Next
   $pointerPos = $pointerPos + $number
   Return $ret
EndFunc

; this will make an array of 'bytes'
For $i = 1 to UBound($tBytes) - 1 Step 2
   $tBytes[($i + 1)/ 2] = $tBytes[$i] & $tBytes[$i + 1]
Next

#cs ======
   Actual MIDI processing section
   see: http://www.ccarh.org/courses/253/handout/smf/
#ce ======

; =
; Header Chunk
; =

; MThd (4) and header length (4)
nextBytes($tBytes, 4)
nextBytes($tBytes, 4)

Local $format = Dec(nextBytes($tBytes, 2))
Local $tracks = Dec(nextBytes($tBytes, 2))

; timing is ticks per beat
; if negative, SMPTE compatible units (look this up later)
Local $timing = Dec(nextBytes($tBytes, 2))

MsgBox(0, "Some Info", "Format: " & $format & @CRLF & "Tracks: " & $tracks & @CRLF & "Timing: " & $timing)

; this is for variable length values
; if highest bit of a byte is set, then keep going
; else return this value after adding this bytes value
Func dec2Bin($dec)
   Local $str = ""
   While $dec > 0
	  If BitAND($dec, 1) == 1 Then
		 $str = "1" & $str
	  Else
		 $str = "0" & $str
	  EndIf
	  $dec = BitShift($dec, 1)
   WEnd
   ; padding
   Return StringRight("00000000" & $str, 8)
EndFunc

Func bin2Dec($bin)
   Local $length = StringLen($bin)
   Local $value = 0
   For $i = 0 to $length
	  Local $char = StringMid($bin, $length - $i, 1)
	  If StringCompare($char, "1") = 0 Then
		 $value = $value + 2 ^ $i
	  EndIf
   Next
   Return $value
EndFunc

Func vlv($byte)
   $byte = Dec($byte)
   Local $totalVal = dec2Bin(BitAND($byte, 127)) ; removes msb
   While $byte >= 128
	  $byte = Dec(nextBytes($tBytes, 1))
	  $totalVal = $totalVal & dec2Bin(BitAND($byte, 127))
   WEnd

   Return bin2Dec($totalVal)
EndFunc

Sleep(3000)

; =
; Track Chunks (loop based on number)
; =
Local $curTrack = 1

$notesAndDelays = ""


Global $strs[$tracks]

For $j = 0 To $tracks - 1
   Local $str = ""
   Local $mtrk = nextBytes($tBytes, 4) ; MTrk
   ConsoleWrite("mtrk " & ($j + 1) & ": " & $mtrk & @CRLF)
   Local $bytes = nextBytes($tBytes, 4)
   ConsoleWrite("bytes: " & $bytes & @CRLF)
   Local $tLength = Dec($bytes)
   ConsoleWrite("length: " & $tLength & @CRLF)
   Local $i = 0
   Local $delay = 0

   While $i < $tLength
	  $delta = vlv(nextBytes($tBytes, 1))
	  $status = nextBytes($tBytes, 1)
	  $i += 2

	  ; ConsoleWrite(" Delta: " & $delta & @CRLF)
	  $delay = $delay + $delta


	  Switch(StringLeft($status, 1))
		 ; midi events
		 ; no fallthrough btw
	  Case "8"
		 ; off, dont care
		 nextBytes($tBytes, 2)
		 $i += 2
	  Case "9"
		 ; right byte is channel, dont care
		 $pressedKey = nextBytes($tBytes, 1)
		 $velocity = nextBytes($tBytes, 1)
		 $i += 2
		 Switch Dec($pressedKey)
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
		 If $delay <> 0 Then
			; ConsoleWrite("Waiting for " & $delay & @CRLF)
			; Sleep(($delay / $timing) * ($microPerQuarter / 1000))
		 EndIf
		 ; $delay = 0
		 $strs[$j] = $strs[$j] & "|" & ($delay / $timing) * 100 & "," & $note
		 ; ConsoleWrite(" " & $status & " " & $pressedKey & " " & $velocity & @CRLF)
		 ; Send($note)
	  Case "A"
		 ; polyphonic key pressure, dont care
		 nextBytes($tBytes, 2)
		 $i += 2
	  Case "B"
		 ; controller change, dont care
		 nextBytes($tBytes, 2)
		 $i += 2
	  Case "C"
		 ; program change, dont care
		 nextBytes($tBytes, 1)
		 $i += 1
	  Case "D"
		 ; channel key pressure, dont care
		 nextBytes($tBytes, 1)
		 $i += 1
	  Case "E"
		 ; pitch bend, dont care
		 nextBytes($tBytes, 2)
		 $i += 2
	  Case "F"
		 ; sysex or meta
		 ; meta
		 $i += 1
		 If $status == "FF" Then
			Local $byts = nextBytes($tBytes, 1)
			$isTempo = $byts == "51"
			; $length = vlv(nextBytes($tBytes, 1)) ; length of event data
			; nextBytes($tBytes, $length) ; discard those bytes
			$isEnd = $byts == "2F"
		 Else
			$isTempo = False
		 EndIf
		 If $isEnd Then
			nextBytes($tBytes, 1)
			ExitLoop
		 EndIf

		 $length = vlv(nextBytes($tBytes, 1)) ; length of event data
		 $i += 1
		 nextBytes($tBytes, $length) ; discard those bytes
		 $i += $length
		 ; ConsoleWrite(" META/SYSEX: " & $status & " (" & $length & ")" & @CRLF)
	  EndSwitch
   WEnd

Next

Local $maxLen = 0
For $i = 0 To Ubound($strs) - 1
   $maxLen = _Max(StringSplit($strs[$i], "|")[0], $maxLen)
Next

Local $container[UBound($strs)]; [$maxLen]

For $i = 0 To Ubound($strs) - 1
   Local $arr = StringSplit($strs[$i], "|")
   _ArrayDelete($arr, 0)
   #cs
   For $j = 1 To $arr[0] - 1
	  $container[$i][$j] = $arr[$j]
   Next
   #ce
   $container[$i] = $arr
Next

Func checkContainer(ByRef $ar, $time)
   ; ConsoleWrite($time & @CRLF)
   For $i = 0 To UBound($ar) - 1
	  ; ConsoleWrite("contents: " & ($ar[$i])[0] & @CRLF)
	  If StringInStr(($ar[$i])[0], ",") <> 0 Then
		 Local $stuff = StringSplit(($ar[$i])[0], ",")
		 Local $exc = $stuff[1]
		 Local $key = $stuff[2]
		 If $time > $exc Then
			Send($key, 1)
			_ArrayPush($ar[$i], 0)
		 EndIf
	  Else
		 _ArrayPush($ar[$i], 0)
	  EndIf
   Next
EndFunc

; _ArrayDisplay($container)

Local $tim = 0
While True
   checkContainer($container, $tim)
   ; multiplier here
   Sleep(20)
   $tim += 10
WEnd














