' ============================================================
'  pc_info_hidden.vbs   --  DOUBLE-CLICK THIS FILE
'
'  It runs pc_info.ps1 with NO visible console window. That script is what
'  feeds the ESP32 right-hand panel (CPU% / MEM% / temperature / weather)
'  over TCP port 8889.
'
'  DOUBLE-CLICK, no arguments  <-- the easy way, nothing to type
'
'    It asks ONE Yes/No question:
'
'      Yes = install the logon auto-start task.
'            Windows shows ONE UAC prompt, then it is done forever: from
'            the next logon on, the task starts pc_info by itself, hidden,
'            with administrator rights. Administrator rights are what let
'            the script read the temperature sensors - a normal startup
'            shortcut can not, so the panel temperature row would stay --.
'            Nothing to type, ever again. This is the recommended answer.
'
'      No  = just run it now, in the background, no administrator rights.
'            CPU% and MEM% will show on the panel, temperature will not.
'
'  Double-clicking again while it is already running does not start a
'  second copy (a second copy would make the panel numbers flicker).
'
'  Where the auto-start lives: a Task Scheduler task named
'      ESP32-panel-info      (Task Scheduler -> Task Scheduler Library)
'  configured as "run with highest privileges", trigger "at logon".
'  Remove it with "pc_info.bat uninstall" (or delete it in Task Scheduler).
'
'  TO STOP IT NOW : Task Manager -> end the "powershell.exe" task
'
'  Console entries (same thing, if you prefer typing):
'      pc_info.bat               foreground, keeps a window showing all the
'                                [pc_info] messages - use this when a value
'                                shows "--" on the panel
'      pc_info.bat install       install + start, no dialog
'      pc_info.bat uninstall     remove the logon auto-start
'      pc_info.bat probe         one-shot self test of this PC only
'                                (tells you which temperature channel works)
'
'  The ESP32 IP comes from Connection.ini next to this file. You can also
'  pass it as an argument (a plain IP is passed through, switches are not):
'      "C:\...\pc_info_hidden.vbs" 192.168.0.31
' ============================================================

Option Explicit

Dim fso, sh, here, ps1, arg, ans, rc

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")

here = fso.GetParentFolderName(WScript.ScriptFullName)
ps1  = fso.BuildPath(here, "pc_info.ps1")

If Not fso.FileExists(ps1) Then
  MsgBox "pc_info.ps1 was not found next to this script:" & vbCrLf & ps1, _
         vbExclamation, "pc_info"
  WScript.Quit 1
End If

arg = ""
If WScript.Arguments.Count > 0 Then arg = LCase(Trim(WScript.Arguments(0)))

' ---- switches that manage the logon auto-start -----------------
' All of them hand over to pc_info.ps1, which creates/removes the task
' with highest privileges and asks for UAC itself if needed.
If arg = "/install" Or arg = "-install" Or arg = "install" Then
  rc = sh.Run(Cmd("-InstallAuto"), 1, True)
  If rc <> 0 Then MsgBox "pc_info install failed (exit code " & rc & ").", _
                          vbExclamation, "pc_info"
  WScript.Quit rc
End If

If arg = "/uninstall" Or arg = "-uninstall" Or arg = "uninstall" Then
  rc = sh.Run(Cmd("-UninstallAuto"), 1, True)
  If rc <> 0 Then MsgBox "pc_info uninstall failed (exit code " & rc & ").", _
                          vbExclamation, "pc_info"
  WScript.Quit rc
End If

' ---- "/silent" = started by the scheduled task: say nothing -----
' (the task runs pc_info.ps1 directly, but keep this for shortcuts that
'  somebody may have pointed at this file)
If arg = "/silent" Or arg = "-silent" Or arg = "silent" Then
  StartHidden ""
  WScript.Quit 0
End If

' ---- plain IP = start hidden with that IP, no dialogs ----------
If arg <> "" Then
  If Left(arg, 1) <> "/" And Left(arg, 1) <> "-" Then
    StartHidden " " & WScript.Arguments(0)
  End If
  WScript.Quit 0
End If

' ---- double-clicked with no argument ---------------------------
' Ask BEFORE starting anything: answering Yes installs the elevated task,
' and we must NOT also leave a non-elevated copy running, otherwise the two
' copies would take turns pushing to the panel (one with temperature, one
' with "--") and the numbers would flicker.
ans = MsgBox("Start pc_info automatically at every logon?" & vbCrLf & vbCrLf & _
             "Yes = Windows asks for administrator rights ONE time, then it runs" & vbCrLf & _
             "      by itself forever, hidden. CPU%, MEM% AND the temperature" & vbCrLf & _
             "      (administrator rights are needed for the sensors)." & vbCrLf & _
             "      Nothing to type ever again. Recommended." & vbCrLf & vbCrLf & _
             "No  = only run it in the background right now, without" & vbCrLf & _
             "      administrator rights: CPU% and MEM% show on the panel," & vbCrLf & _
             "      the temperature row stays --." & vbCrLf & vbCrLf & _
             "To stop it later: Task Manager -> end the powershell.exe task.", _
             vbYesNoCancel + vbQuestion, "pc_info")

If ans = vbCancel Or ans = 0 Then WScript.Quit 0

If ans = vbYes Then
  rc = sh.Run(Cmd("-InstallAuto"), 1, True)
  WScript.Quit rc
End If

If AlreadyRunning() Then
  MsgBox "pc_info is already running in the background." & vbCrLf & vbCrLf & _
         "To stop it: Task Manager -> end the powershell.exe task.", _
         vbInformation, "pc_info"
  WScript.Quit 0
End If

StartHidden ""
MsgBox "pc_info is now running in the background (no administrator rights)." & vbCrLf & vbCrLf & _
       "The ESP32 panel needs a few seconds before CPU% and MEM% fill in" & vbCrLf & _
       "(the CPU counter needs two samples). The temperature row will stay" & vbCrLf & _
       "-- because reading the sensors needs administrator rights." & vbCrLf & vbCrLf & _
       "To get the temperature too: run pc_info.bat install (one UAC prompt)." & vbCrLf & _
       "To stop it now: Task Manager -> end the powershell.exe task.", _
       vbInformation, "pc_info"

WScript.Quit 0

' ================================================================
' helpers
' ================================================================

' powershell command line that runs pc_info.ps1 with the given extra args
Function Cmd(extra)
  Cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File """ & ps1 & """ " & extra
End Function

' 0 = hidden window, False = do not wait for it to finish
Sub StartHidden(theIp)
  sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -File """ & ps1 & """" & theIp, 0, False
End Sub

' True when a powershell.exe whose command line mentions pc_info.ps1 is alive
Function AlreadyRunning()
  Dim wmi, list, p
  AlreadyRunning = False
  On Error Resume Next
  Set wmi = GetObject("winmgmts:\\.\root\cimv2")
  Set list = wmi.ExecQuery("Select CommandLine from Win32_Process Where Name='powershell.exe'")
  For Each p In list
    If Not IsNull(p.CommandLine) Then
      If InStr(LCase(p.CommandLine), "pc_info.ps1") > 0 Then AlreadyRunning = True
    End If
  Next
  On Error GoTo 0
End Function
