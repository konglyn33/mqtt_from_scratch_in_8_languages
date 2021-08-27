VERSION 5.00
Object = "{248DD890-BB45-11CF-9ABC-0080C7E7B78D}#1.0#0"; "MSWINSCK.OCX"
Begin VB.Form Form1 
   Caption         =   "vb6 native mqtt demo"
   ClientHeight    =   8310
   ClientLeft      =   120
   ClientTop       =   450
   ClientWidth     =   9930
   LinkTopic       =   "Form1"
   ScaleHeight     =   8310
   ScaleWidth      =   9930
   StartUpPosition =   3  '窗口缺省
   Begin VB.TextBox txtTopic 
      Appearance      =   0  'Flat
      BackColor       =   &H00000000&
      ForeColor       =   &H000080FF&
      Height          =   270
      Left            =   5160
      TabIndex        =   8
      Text            =   "sht30"
      Top             =   1320
      Width           =   4215
   End
   Begin VB.CommandButton btnSub 
      Caption         =   "Sub Topic"
      Height          =   495
      Left            =   4320
      TabIndex        =   7
      Top             =   360
      Width           =   1335
   End
   Begin VB.Timer tmrPing 
      Enabled         =   0   'False
      Interval        =   10000
      Left            =   9360
      Top             =   1920
   End
   Begin VB.CommandButton btnRunTest 
      Caption         =   "print test packet"
      Height          =   495
      Left            =   6840
      TabIndex        =   6
      Top             =   360
      Width           =   2535
   End
   Begin VB.CommandButton btnPub 
      Caption         =   "Pub Msg"
      Height          =   495
      Left            =   2760
      TabIndex        =   5
      Top             =   360
      Width           =   1455
   End
   Begin VB.TextBox txtTx 
      Appearance      =   0  'Flat
      BackColor       =   &H00000000&
      ForeColor       =   &H000080FF&
      Height          =   270
      Left            =   120
      TabIndex        =   4
      Text            =   "{""temp"":25.4,""humid"":56.7}"
      Top             =   1320
      Width           =   4935
   End
   Begin VB.CommandButton btnClose 
      Caption         =   "Close"
      Height          =   495
      Left            =   1320
      TabIndex        =   3
      Top             =   360
      Width           =   1215
   End
   Begin VB.TextBox txtBroker 
      Appearance      =   0  'Flat
      BackColor       =   &H00000000&
      ForeColor       =   &H000080FF&
      Height          =   270
      Left            =   120
      TabIndex        =   2
      Text            =   "127.0.0.1"
      Top             =   1680
      Width           =   9255
   End
   Begin VB.CommandButton btnConnect 
      Caption         =   "Connect "
      Height          =   495
      Left            =   120
      TabIndex        =   1
      Top             =   360
      Width           =   1095
   End
   Begin VB.TextBox txtRx 
      Appearance      =   0  'Flat
      BackColor       =   &H00000000&
      ForeColor       =   &H00FFFF00&
      Height          =   6135
      Left            =   120
      MultiLine       =   -1  'True
      ScrollBars      =   2  'Vertical
      TabIndex        =   0
      Text            =   "frmNativeMQTT.frx":0000
      Top             =   2040
      Width           =   9495
   End
   Begin MSWinsockLib.Winsock MqttSock 
      Left            =   9360
      Top             =   1440
      _ExtentX        =   741
      _ExtentY        =   741
      _Version        =   393216
   End
   Begin VB.Label Label2 
      BackStyle       =   0  'Transparent
      Caption         =   "Topic"
      Height          =   255
      Left            =   5160
      TabIndex        =   10
      Top             =   1080
      Width           =   615
   End
   Begin VB.Label Label1 
      BackStyle       =   0  'Transparent
      Caption         =   "Msg"
      Height          =   255
      Left            =   120
      TabIndex        =   9
      Top             =   1080
      Width           =   615
   End
End
Attribute VB_Name = "Form1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False

Option Explicit
'


Private Const Address = "tcp://broker-cn.emqx.io:1883"
Private Const CLIENTID = "Client1628227243"
Private Const TOPIC = "sht30"
Private Const payload = "{""temp"":26.5}"
Private Const qos = 1&
Private Const timeout = 10000&

Public Sub DelaySeconds(ByVal sglSec As Single)  '秒级延时  精确到 0.005s
    
    Dim tStart As Single
    Dim tCheck As Single
    
    If sglSec > 86000 Then
    
        MsgBox "延时太长，参数必须小于等于86000！"
        Exit Sub
    End If
    
    tStart = Timer
    tCheck = Timer
    If tCheck < tStart Then tCheck = tCheck + 86400!
    
    Do While Abs(tCheck - tStart) < sglSec
          DoEvents
          tCheck = Timer
          If tCheck < tStart Then tCheck = tCheck + 86400!
         ' Debug.Print Str(tCheck - tStart) & "  s Elapsed"
    Loop
    
End Sub

Public Function Bytes2Hex(ByRef aBytes() As Byte) As String
   
   Dim j As Integer
   
   Bytes2Hex = Right("0" & Hex(aBytes(0)), 2)
   
   For j = 1 To UBound(aBytes)
       Bytes2Hex = Bytes2Hex & " " & Right("0" & Hex(aBytes(j)), 2)
   Next j
   
End Function


Function make_packet_conn_without_password(ByVal CLIENTID As String) As Byte()
    
    Dim i As Long, offset As Long
    Dim remLen As Long
    Dim bPacket() As Byte
    Dim bAnsiClientID() As Byte
    
    ' "mqtt" + version + flag + keep_alive + client_id + username + password + strlen_header
    remLen = 6 + 1 + 1 + 2 + Len(CLIENTID) + 2
    
    ReDim bPacket(0 To remLen + 2 - 1) As Byte
    
    bPacket(0) = &H10
    bPacket(1) = CByte(remLen) ' only small packet is supported for now (less than 127)
    
    bPacket(2) = &H0
    bPacket(3) = &H4
    bPacket(4) = AscB("M")
    bPacket(5) = AscB("Q")
    bPacket(6) = AscB("T")
    bPacket(7) = AscB("T")
    
    bPacket(8) = &H4 ' version -> mqtt v3.1.1
    
    bPacket(9) = &H2  'username_flag =0   password_flag =0  clean_session_flag
    
    bPacket(10) = &H0
    bPacket(11) = &H3C 'keep_alive 60 sec
    
    bPacket(12) = &H0
    bPacket(13) = CByte(Len(CLIENTID))
    
    bAnsiClientID = StrConv(CLIENTID, vbFromUnicode)
    offset = 14
    For i = 0 To UBound(bAnsiClientID)
        bPacket(offset + i) = bAnsiClientID(i)
    Next i
    
    make_packet_conn_without_password = bPacket

End Function



Function make_packet_conn(ByVal client_id As String, ByVal username As String, ByVal password As String) As Byte()
    
    Dim i As Long, offset As Long
    Dim remLen As Long
    Dim bPacket() As Byte
    Dim bAnsiClientID() As Byte
    Dim bAnsiUsername() As Byte
    Dim bAnsiPassWord() As Byte
    
    ' "mqtt" + version + flag + keep_alive + client_id + username + password + strlen_header
    remLen = 6 + 1 + 1 + 2 + Len(client_id) + Len(username) + Len(password) + 6
    
    ReDim bPacket(0 To remLen + 2 - 1) As Byte
    
    bPacket(0) = &H10
    bPacket(1) = CByte(remLen) ' only small packet is supported for now (less than 127)
    
    bPacket(2) = &H0
    bPacket(3) = &H4
    bPacket(4) = AscB("M")
    bPacket(5) = AscB("Q")
    bPacket(6) = AscB("T")
    bPacket(7) = AscB("T")
    
    bPacket(8) = &H4 ' version -> mqtt v3.1.1
    
    bPacket(9) = &HC2 'username_flag password_flag clean_session_flag
    
    bPacket(10) = &H0
    bPacket(11) = &H3C 'keep_alive 60 sec
    
    bPacket(12) = &H0
    bPacket(13) = CByte(Len(client_id))
    
    bAnsiClientID = StrConv(client_id, vbFromUnicode)
    offset = 14
    For i = 0 To UBound(bAnsiClientID)
        bPacket(offset + i) = bAnsiClientID(i)
    Next i
    
    bPacket(offset + i + 0) = &H0
    bPacket(offset + i + 1) = CByte(Len(username))
    offset = offset + i + 2
    
    bAnsiUsername = StrConv(username, vbFromUnicode)
    For i = 0 To UBound(bAnsiUsername)
        bPacket(offset + i) = bAnsiUsername(i)
    Next i
    
    bPacket(offset + i + 0) = &H0
    bPacket(offset + i + 1) = CByte(Len(password))
    offset = offset + i + 2
    
    bAnsiPassWord = StrConv(password, vbFromUnicode)
    For i = 0 To UBound(bAnsiPassWord)
        bPacket(offset + i) = bAnsiPassWord(i)
    Next i
    
    make_packet_conn = bPacket

End Function


Function make_packet_sub_qos0(ByVal packet_id As Long, ByVal TOPIC As String) As Byte()
    
    Dim i As Long, offset As Long
    Dim remLen As Long
    Dim bPacket() As Byte
    Dim bAnsiTopic() As Byte
    
    remLen = 2 + 2 + Len(TOPIC) + 1 'packet_id + topic_len + topic + qos
    
    ReDim bPacket(0 To remLen + 2 - 1) As Byte
    
    bPacket(0) = &H82
    bPacket(1) = CByte(remLen) ' only small packet is supported for now (less than 127)
    
    bPacket(2) = CByte(packet_id \ 256)  ' msb of packet_id
    bPacket(3) = CByte(packet_id Mod 256)  ' lsb of packet_id
    
    bPacket(4) = &H0  ' msb of topic len
    bPacket(5) = CByte(Len(TOPIC))  ' lsb of topic len
    
    bAnsiTopic = StrConv(TOPIC, vbFromUnicode)
    
    offset = 6
    For i = 0 To UBound(bAnsiTopic)
        bPacket(offset + i) = bAnsiTopic(i)
    Next i
    
    offset = remLen + 2 - 1
    bPacket(offset) = &H0 'qos 0
    
    make_packet_sub_qos0 = bPacket
End Function


Function make_packet_unsub_qos0(ByVal packet_id As Long, ByVal TOPIC As String) As Byte()
    
    Dim i As Long, offset As Long
    Dim remLen As Long
    Dim bPacket() As Byte
    Dim bAnsiTopic() As Byte
    
    remLen = 2 + 2 + Len(TOPIC)  'packet_id + topic_len + topic
    
    ReDim bPacket(0 To remLen + 2 - 1) As Byte
    
    bPacket(0) = &HA2
    bPacket(1) = CByte(remLen) ' only small packet is supported for now (less than 127)
    
    bPacket(2) = CByte(packet_id \ 256)  ' msb of packet_id
    bPacket(3) = CByte(packet_id Mod 256)  ' lsb of packet_id
    
    bPacket(4) = &H0  ' msb of topic len
    bPacket(5) = CByte(Len(TOPIC))  ' lsb of topic len
    
    bAnsiTopic = StrConv(TOPIC, vbFromUnicode)
    
    offset = 6
    For i = 0 To UBound(bAnsiTopic)
        bPacket(offset + i) = bAnsiTopic(i)
    Next i
    
    make_packet_unsub_qos0 = bPacket
End Function



Function make_packet_pub_qos0(ByVal TOPIC As String, ByVal payload As String) As Byte()
    
    Dim i As Long, offset As Long
    Dim remLen As Long
    Dim bPacket() As Byte
    Dim bAnsiTopic() As Byte
    Dim bAnsiPayload() As Byte
    
    remLen = 2 + Len(TOPIC) + Len(payload)
    
    ReDim bPacket(0 To remLen + 2 - 1) As Byte
    
    
    bPacket(0) = &H30
    bPacket(1) = CByte(remLen) ' only small packet is supported for now (less than 127)
    
    bPacket(2) = &H0  ' msb of topic len
    bPacket(3) = CByte(Len(TOPIC))  ' lsb of topic len
    
    bAnsiTopic = StrConv(TOPIC, vbFromUnicode)
    
    bAnsiPayload = StrConv(payload, vbFromUnicode)
    
    offset = 4
    For i = 0 To UBound(bAnsiTopic)
        bPacket(offset + i) = bAnsiTopic(i)
    Next i
    
    offset = 4 + Len(TOPIC)
    For i = 0 To UBound(bAnsiPayload)
        bPacket(offset + i) = bAnsiPayload(i)
    Next i
    
    make_packet_pub_qos0 = bPacket

End Function


Function make_packet_ping() As Byte()
    
    Dim bPacket() As Byte
    
    ReDim bPacket(0 To 1) As Byte
    
    bPacket(0) = &HC0
    bPacket(1) = &H0
    
    make_packet_ping = bPacket
End Function


Function make_packet_disconn() As Byte()
    
    Dim bPacket() As Byte
    
    ReDim bPacket(0 To 1) As Byte
    
    bPacket(0) = &HE0
    bPacket(1) = &H0
    
    make_packet_disconn = bPacket
End Function

 

Private Sub btnClose_Click()

    tmrPing.Enabled = False
    MqttSock.SendData make_packet_disconn()
   'MqttSock.Close
End Sub

Private Sub btnConnect_Click()
    
    
    MqttSock.RemoteHost = txtBroker.Text
    MqttSock.RemotePort = 1883
    MqttSock.Connect
 
End Sub


Private Sub btnPub_Click()

   MqttSock.SendData make_packet_pub_qos0("sht30", txtTx.Text)
End Sub

Private Sub btnRunTest_Click()

   Dim b() As Byte
   
   b = make_packet_conn_without_password("MQTT_FX_Client")
   
   txtRx.Text = txtRx.Text & Bytes2Hex(b)

End Sub

Private Sub btnSub_Click()

   MqttSock.SendData make_packet_sub_qos0(1, "sht30")
End Sub

Private Sub Form_Load()

    
   Dim strIP As String
    
   If DNS.SocketsInitialize Then
        
        strIP = DNS.GetIPFromHostName("broker-cn.emqx.io")
        txtBroker.Text = strIP
   Else
        txtRx.Text = "dns lookup ini: failed!" & vbCrLf
   End If
End Sub

Private Sub Form_Unload(Cancel As Integer)
   Call DNS.SocketsCleanup
End Sub

Private Sub MqttSock_Close()
    txtRx.Text = txtRx.Text & "connection closed!" & vbCrLf
End Sub

Private Sub MqttSock_Connect()
   
   txtRx.Text = txtRx.Text & "connected to broker: " & Address & vbCrLf
   
   'MqttSock.SendData make_packet_conn(CLIENTID, u, p)
   MqttSock.SendData make_packet_conn_without_password(CLIENTID)
   
   tmrPing.Enabled = True
End Sub

Private Sub MqttSock_DataArrival(ByVal bytesTotal As Long)

  Dim rawData() As Byte
  Dim s As String
  
  DelaySeconds 0.1
  
  MqttSock.GetData rawData
  
  s = Bytes2Hex(rawData)
  
  txtRx.Text = txtRx.Text & s & vbCrLf
  
  
End Sub

Private Sub MqttSock_Error(ByVal Number As Integer, Description As String, ByVal Scode As Long, ByVal Source As String, ByVal HelpFile As String, ByVal HelpContext As Long, CancelDisplay As Boolean)
    MsgBox "Error " & Number & ": " & Description
End Sub

Private Sub tmrPing_Timer()
    MqttSock.SendData make_packet_ping()
End Sub
