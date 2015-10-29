#cs ----------------------------------------------------------------------------

AutoIt Version: 3.3.12.0
Author:         multiple
Compiler:       Reimu

Script Function:
credits to all the people in this script
https://www.autoitscript.com/forum/topic/70507-converter-dec-hex-bin/
variable length value processing
hex -> binary -> process -> hex -> dec

#ce ----------------------------------------------------------------------------

Func vlvMe($hexValue)

; HEX TO BIN ================================================
Global $tempoType
Local $Allowed = '0123456789ABCDEF'
Local $Test,$n
Local $Result = ''
if $hexValue = '' then
SetError(-2)
EndIf
$hexvalue = StringSplit($hexvalue,'')
for $n = 1 to $hexValue[0]
if not StringInStr($Allowed,$hexvalue[$n]) Then
SetError(-1)
EndIf
Next
Local $bits = "0000|0001|0010|0011|0100|0101|0110|0111|1000|1001|1010|1011|1100|1101|1110|1111"
$bits = stringsplit($bits,'|')
for $n = 1 to $hexvalue[0]
$Result &= $bits[Dec($hexvalue[$n])+1]
Next
$Result = StringRight($Result, 16)
;ConsoleWrite($Result & " ")

#cs
; SIGNED STUFF ====================================
Local $newBin
$sign = StringLeft($Result, 1)
if $sign == 1 Then ; negative number, flip all bits. if positive(==0), do nothing
   $Result = StringRegExpReplace($Result, "1", "a")
   $Result = StringRegExpReplace($Result, "0", "b")
   $Result = StringRegExpReplace($Result, "a", "0")
   $Result = StringRegExpReplace($Result, "b", "1")
EndIf
$newBin = $Result
ConsoleWrite($newBin & @CRLF)
#ce
#ce

; REMOVING MOST SIGNIFICANT BYTES ===========================
Local $Result2
For $p = 1 To StringLen($Result) Step +8
   $Result2 &= StringMid($Result,$p+1,7)
Next
;ConsoleWrite($Result2 & @CRLF)

; PADDING WITH 0s UNTIL LENGHT IS MULTIPLE OF 4 =============
Do
   $Result2 = "0" & $Result2
   $check = Mod(StringLen($Result2), 4)
Until ($check == 0)

; BIN TO HEX ================================================
$BinaryValue = $Result2
Local $test, $Result = '',$numbytes,$nb
If StringRegExp($BinaryValue,'[0-1]') then

if $BinaryValue = '' Then ; if empty??
SetError(-2)
Return
endif

Local $bits = "0000|0001|0010|0011|0100|0101|0110|0111|1000|1001|1010|1011|1100|1101|1110|1111"
$bits = stringsplit($bits,'|')
#region check string is binary
$test = stringreplace($BinaryValue,'1','')
$test = stringreplace($test,'0','')
if $test <> '' Then
SetError(-1);non binary character detected
ConsoleWrite("ducked")
Return
endif
#endregion check string is binary
#region make binary string an integral multiple of 4 characters
While 1
$nb = Mod(StringLen($BinaryValue),4)
if $nb = 0 then exitloop
$BinaryValue = '0' & $BinaryValue
WEnd
#endregion make binary string an integral multiple of 4 characters
$numbytes = Int(StringLen($BinaryValue)/4);the number of bytes
Dim $bytes[$numbytes],$Deci[$numbytes]
For $j = 0 to $numbytes - 1;for each byte
;extract the next byte
$bytes[$j] = StringMid($BinaryValue,1+4*$j,4)
;find what the dec value of the byte is
for $k = 0 to 15;for all the 16 possible hex values
if $bytes[$j] = $bits[$k+1] Then
$Deci[$j] = $k
ExitLoop
EndIf
next
Next
;now we have the decimal value for each byte, so stitch the string together again
$Result = ''
for $l = 0 to $numbytes - 1
$Result &= Hex($Deci[$l],1)
    Next
Else
    MsgBox(0,"Error","Wrong input, try again ...")
    Return
EndIf
;ConsoleWrite($Result & @CRLF)
;ConsoleWrite($Result2 & " " & $Result & @CRLF)
Return Dec($Result)
#cs
; BIN TO DEC =======================================
$strBin = $newBin
Local $Return
Local $lngResult
Local $intIndex
If StringRegExp($strBin,'[0-1]') then
$lngResult = 0
For $intIndex = StringLen($strBin) to 1 step -1
$strDigit = StringMid($strBin, $intIndex, 1)
Select
case $strDigit="0"
; do nothing
case $strDigit="1"
$lngResult = $lngResult + (2 ^ (StringLen($strBin)-$intIndex))
case else
; invalid binary digit, so the whole thing is invalid
$lngResult = 0
$intIndex = 0 ; stop the loop
EndSelect
Next
if $sign == 1 Then
   $lngResult += 1
EndIf
;ConsoleWrite($lngResult & @CRLF)
EndIf
$tempo = $lngResult
#cs
; HEX TO DEC ========================================
Global Const $HX_REF="0123456789ABCDEF"
$hx_hex = $Result
If StringLeft($hx_hex, 2) = "0x" Then $hx_hex = StringMid($hx_hex, 3)
If StringIsXDigit($hx_hex) = 0 Then
SetError(1)
MsgBox(0,"Error","Wrong input, try again ...")
Return ""
EndIf
Local $ret="", $hx_count=0, $hx_array = StringSplit($hx_hex, ""), $Ii, $hx_tmp
For $Ii = $hx_array[0] To 1 Step -1
$hx_tmp = StringInStr($HX_REF, $hx_array[$Ii]) - 1
$ret += $hx_tmp * 16 ^ $hx_count
$hx_count += 1
Next
ConsoleWrite( $ret)
#ce
ConsoleWrite($tempoType & @CRLF)
ConsoleWrite($lngResult & @CRLF)
#ce

EndFunc
