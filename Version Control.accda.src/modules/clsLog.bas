Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Public PadLength As Integer
Public LogFilePath As String

Private Const cstrSpacer As String = "-------------------------------------"

Private m_Log As clsConcat      ' Log file output
Private m_Console As clsConcat  ' Console output
Private m_RichText As TextBox   ' Text box to display HTML
Private m_Prog As clsLblProg    ' Progress bar
Private m_blnProgressActive As Boolean
Private m_sngLastUpdate As Single


'---------------------------------------------------------------------------------------
' Procedure : Clear
' Author    : Adam Waller
' Date      : 4/16/2020
' Purpose   : Clear the log buffers
'---------------------------------------------------------------------------------------
'
Public Sub Clear()
    Class_Initialize
End Sub


'---------------------------------------------------------------------------------------
' Procedure : Spacer
' Author    : Adam Waller
' Date      : 4/28/2020
' Purpose   : Add a spacer to the log
'---------------------------------------------------------------------------------------
'
Public Sub Spacer(Optional blnPrint As Boolean = True)
    Me.Add cstrSpacer, blnPrint
End Sub


'---------------------------------------------------------------------------------------
' Procedure : Add
' Author    : Adam Waller
' Date      : 1/18/2019
' Purpose   : Add a log file entry.
'---------------------------------------------------------------------------------------
'
Public Sub Add(strText As String, Optional blnPrint As Boolean = True, Optional blnNextOutputOnNewLine As Boolean = True)

    Dim strHtml As String
    
    ' Add to log file output
    m_Log.Add strText, vbCrLf
    
    ' See if we want to print the output of this message.
    If blnPrint Then
        ' Remove existing progress indicator if in use.
        If m_blnProgressActive Then
            m_blnProgressActive = False
            m_Prog.Visible = False
        End If
    
        ' Use bold/green text for completion line.
        strHtml = Replace(strText, " ", "&nbsp;")
        If InStr(1, strText, "Done. ") = 1 Then
            strHtml = "<font color=green><strong>" & strText & "</strong></font>"
        End If
        m_Console.Add strHtml
        ' Add line break for HTML
        If blnNextOutputOnNewLine Then m_Console.Add "<br>"
        
        ' Run debug output
        If m_RichText Is Nothing Then
            ' Only print debug output if not running from the GUI.
            If blnNextOutputOnNewLine Then
                ' Create new line
                Debug.Print strText
            Else
                ' Continue next printout on this line.
                Debug.Print strText;
            End If
        End If
        
        ' Allow an update to the screen every second.
        ' (This keeps the aplication from an apparent hang while
        '  running intensive export processes.)
        If m_sngLastUpdate + 1 < Timer Then
            Me.Flush
            m_sngLastUpdate = Timer
        End If
    End If
 
End Sub


'---------------------------------------------------------------------------------------
' Procedure : Flush
' Author    : Adam Waller
' Date      : 4/29/2020
' Purpose   : Flushes the buffer to the console
'---------------------------------------------------------------------------------------
'
Public Sub Flush()

    ' See if the GUI form is loaded.
    Perf.OperationStart "Console Updates"
    If Not m_RichText Is Nothing Then
        With Form_frmVCSMain.txtLog
            m_blnProgressActive = False
            If Not m_Prog Is Nothing Then m_Prog.Visible = False
            ' Set value, not text to avoid errors with large text strings.
            Echo False
            '.SelStart = Len(.Text & vbNullString)
            ' Show the last 20K characters so
            ' we don't hit the Integer limit
            ' on the SelStart property.
            .Value = m_Console.RightStr(20000)
            .SelStart = 20000
            Echo True
            'Form_frmVCSMain.Repaint
        End With
    End If
    
    ' Update the display (especially for immediate window)
    DoEvents
    Perf.OperationEnd
    
End Sub


'---------------------------------------------------------------------------------------
' Procedure : SetConsole
' Author    : Adam Waller
' Date      : 4/28/2020
' Purpose   : Set a reference to the text box.
'---------------------------------------------------------------------------------------
'
Public Sub SetConsole(txtRichText As TextBox)
    Set m_RichText = txtRichText
    If Not m_RichText Is Nothing Then
        m_RichText.AllowAutoCorrect = False
    End If
End Sub


'---------------------------------------------------------------------------------------
' Procedure : ProgressBar
' Author    : Adam Waller
' Date      : 11/6/2020
' Purpose   : Pass the Progress Bar reference to this class.
'---------------------------------------------------------------------------------------
'
Public Property Set ProgressBar(cProg As clsLblProg)
    Set m_Prog = cProg
End Property
Public Property Get ProgressBar() As clsLblProg
    Set ProgressBar = m_Prog
End Property


'---------------------------------------------------------------------------------------
' Procedure : ProgMax
' Author    : Adam Waller
' Date      : 11/6/2020
' Purpose   : Wrapper to set max value for progress bar.
'---------------------------------------------------------------------------------------
'
Public Property Let ProgMax(lngMaxValue As Long)
    If Not m_Prog Is Nothing Then m_Prog.Max = lngMaxValue
End Property


'---------------------------------------------------------------------------------------
' Procedure : SaveFile
' Author    : Adam Waller
' Date      : 1/18/2019
' Purpose   : Saves the log data to a file, and resets the log buffer.
'---------------------------------------------------------------------------------------
'
Public Sub SaveFile(strPath As String)
    WriteFile m_Log.GetStr, strPath
    Set m_Log = New clsConcat
    LogFilePath = strPath
End Sub


'---------------------------------------------------------------------------------------
' Procedure : Class_Initialize
' Author    : Adam Waller
' Date      : 4/28/2020
' Purpose   : Set initial options
'---------------------------------------------------------------------------------------
'
Private Sub Class_Initialize()
    Set m_Console = New clsConcat
    Set m_Log = New clsConcat
    m_blnProgressActive = False
    m_sngLastUpdate = 0
    Me.PadLength = 30
End Sub


'---------------------------------------------------------------------------------------
' Procedure : PadRight
' Author    : Adam Waller
' Date      : 1/25/2019
' Purpose   : Pad a string on the right to make it `count` characters long.
'---------------------------------------------------------------------------------------
'
Public Sub PadRight(strText As String, Optional blnPrint As Boolean = True, Optional blnNextOutputOnNewLine As Boolean = False, Optional ByVal intCharacters As Integer)
    If intCharacters = 0 Then intCharacters = Me.PadLength
    If Len(strText) < intCharacters Then
        Me.Add strText & Space$(intCharacters - Len(strText)), blnPrint, blnNextOutputOnNewLine
    Else
        Me.Add strText, blnPrint, blnNextOutputOnNewLine
    End If
End Sub


'---------------------------------------------------------------------------------------
' Procedure : Increment
' Author    : Adam Waller
' Date      : 4/28/2020
' Purpose   : Increment the clock icon
'---------------------------------------------------------------------------------------
'
Public Sub Increment()
    
    ' Track the last time we did an increment
    Static sngLastIncrement As Single
    Static lngProgress As Long
    
    ' Ignore if we are not using the form
    If m_Prog Is Nothing Then Exit Sub
    
    ' Increment value, even if we don't display it.
    lngProgress = lngProgress + 1
    
    ' Don't run the incrementer unless it has been 1
    ' second since the last displayed output refresh.
    If m_sngLastUpdate > Timer - 1 Then Exit Sub
    
    ' Allow an update to the screen every x seconds.
    ' Find the balance between good progress feedback
    ' without slowing down the overall export time.
    If sngLastIncrement > Timer - 0.5 Then Exit Sub

    ' Check the current status.
    Perf.OperationStart "Increment Progress"
    If Not m_blnProgressActive Then
        ' Show the progress bar
        lngProgress = 1
        m_Prog.Visible = True
        ' Flush any pending output
        With m_RichText
            Echo False
            ' Show the last 20K characters so
            ' we don't hit the Integer limit
            ' on the SelStart property.
            .Value = m_Console.RightStr(20000)
            .SelStart = 20000
            Echo True
        End With
    End If
    
    ' Status is now active
    sngLastIncrement = Timer
    m_blnProgressActive = True
    m_Prog.Value = lngProgress
    Perf.OperationEnd
    
End Sub