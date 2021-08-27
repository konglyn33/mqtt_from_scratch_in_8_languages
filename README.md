# implement mqtt client from scratch in 8 languages

## supported mqtt version
- MQTT V3.1.1

## languages used in this tutorial
- java -> MainActivity.java
- c# -> Form1.cs
- c++ -> mainwindow.cpp
- vba/vb6 -> frmNativeMQTT.frm
- python -> python_client_mqtt_from_scratch.py
- matlab -> matlab_client_mqtt_from_scratch.m
- golang -> mqtt_client.go
- rust -> main.rs

## socket layer
- we already have it, socket api is provided by the core framework in most programming languages

## mqtt layer
- make_packet_conn
- make_packet_pub_qos0
- make_packet_sub_qos0
- make_packet_unsub_qos0
- make_packet_ping
- make_packet_disconn

## ui layer
- btnConnect_Click
- btnClose_Click
- btnSub_Click
- btnPub_Click
- tmrPing_Tick