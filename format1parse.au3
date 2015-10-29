#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.12.0
 Author:         Reimu

 Script Function:
	Parse format 1 midi file

#ce ----------------------------------------------------------------------------

; Script Start - Add your code below here

Func format1parse(ByRef $info)

   ConsoleWrite("format1parse" & @CRLF)

   ; TRACK CHUNK
   ; 4 BYTES ; ######## should be 4D54726B which is MTrk, the track chunk
   ; 4 BYTES ; ######## should be 0000000# which is the track length
   ; ? BYTES ; a sequenced track event
   ; this is a format 1 file so it has 2 tracks, one that is the tempo map and another that is the notes
   ; i = 2 is the first track
   ; i = 3 is the second track
   For $i = 2 To 3 Step +1
	  $delayTotal = 0
	  $newNotes = ""
	  $2split = StringRegExp($split[$i], "..", 3)
	  For $k = 0 To UBound($2split)-1 Step +1
		 $newNotes &= $2split[$k] & " "
	  Next
	  $split[$i] = $newNotes
	  ;ConsoleWrite($split[$i] & @CRLF)

	  ; remove length of chunk
	  $myChunk = StringTrimLeft($split[$i], 8)
	  $actualNotes = StringSplit($myChunk, "FF", 1)

	  ; TEMPO MAP PROCESSING
	  ; SET TEMPO =      FF 51 03 tt tt tt    ; tttttt = microseconds per quaternote
	  ; TIME SIGNATURE = FF 58 04 nn dd cc bb ; nn / 2^dd = time signature, cc = MIDI clocks per tick, bb = number of 1/32 notes per 24 MIDI clocks (default 8)

	  If($i == 2) Then
		 For $p = 1 to $actualNotes[0] Step +1
			$metaEventIdentifier = StringRight(StringLeft($actualNotes[$p], 3), 2)
			$stuff = StringReplace(StringTrimLeft($actualNotes[$p], 7), " ", "")
			Switch($metaEventIdentifier)
			   Case "51"
				  $timeUntilChange = StringTrimLeft($stuff, 6)
				  $delayTotal += vlvMe($timeUntilChange)
				  $stuff = StringLeft($stuff, 6)
				  ; milliseconds per quaternote aka sleep time
				  $tempoInfo &= Dec($stuff) & " (" & vlvMe($timeUntilChange) & ") " & @CRLF
			   Case "58"
				  $stuff = StringLeft($stuff, 8)
				  $nn = StringLeft($stuff, 2)
				  $dd = StringMid($stuff, 3, 2)
				  $cc = StringMid($stuff, 5, 2)
				  $bb = StringMid($stuff, 7, 2)
				  $timeInfo &= "Time Signature: " & Dec($nn) & "/" & 2^Dec($dd) & @CRLF
			   Case Else
			EndSwitch
		 Next
		 ;ConsoleWrite($timeInfo & @CRLF)
		 ;ConsoleWrite($tempoInfo & @CRLF)
		 ; $tempo info is structured like this - tempo (duration)
	  ; note/delay processing
	  Else
	     ; if -1 then you get FF 2F 00 or Gust 2F 00, the end of the chunk
		 ; if -2 then you get last meta event and rest of chunk
		 $metaAndNotes = $actualNotes[UBound($actualNotes)-2]
		 $lastMetaLength = Dec(StringLeft(StringTrimLeft($metaAndNotes, 4), 2))
		 $actualData =StringTrimLeft($metaAndNotes, $lastMetaLength * 3 + 7)
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
				  ;ConsoleWrite("(" & $delay & ") " & Dec($delay) & @CRLF)
				  ;ConsoleWrite("(" & $not & " @" & $vel & ") " & $note & @CRLF)
				  ;$delay = vlvMe($delay)
				  $delay = vlvMe($delay)
				  $noteInfo &= ($note & " (" & $delay & ")" & @CRLF)
				  ;Sleep(50)
				  ;FileWrite("notes.txt", $note & " || WAIT: " & $delay &@CRLF)
				  $delay = ""
			   ElseIf ($notes == 80) then
				  ;ConsoleWrite("(" & $delay & ")" & Dec($delay) & @CRLF)
				  $not = " "
				  $vel = Dec($onAndOffNotes[$j+2])
				  $delay = vlvMe($delay)
				  $noteInfo &= ($not & " (" & $delay & ")" & @CRLF)
				  $j = $j + 2
				  $delay = ""
			   Else
				  $delay &= $notes
			   EndIf
		 Next
	  EndIf
   Next
   ;ConsoleWrite($noteInfo & @CRLF)
EndFunc
