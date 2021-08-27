import socket
import time


def make_packet_conn(client_id:str, username:str, password:str):
    i, offset, remLen = 0, 0, 0
    
    bUTF8ClientId = client_id.encode('utf8')
    bUTF8Username = username.encode('utf8')
    bUTF8Password = password.encode('utf8')

    #// "mqtt" + version + flag + keep_alive + client_id + username + password + strlen_header
    remLen = 6 + 1 + 1 + 2 + len(bUTF8ClientId) + len(bUTF8Username) + len(bUTF8Password) + 6

    bPacket = bytearray(remLen + 2)

    bPacket[0] = 0x10
    bPacket[1] = remLen #// only small packet is supported for now (less than 127)

    bPacket[2] = 0x00
    bPacket[3] = 0x04
    bPacket[4] = ord('M')
    bPacket[5] = ord('Q')
    bPacket[6] = ord('T')
    bPacket[7] = ord('T')

    bPacket[8] = 0x04 #// version -> mqtt v3.1.1
    bPacket[9] = 0xC2 #// username_flag   password_flag  clean_session_flag

    bPacket[10] = 0x00
    bPacket[11] = 0x3C  #// keep_alive 60 sec

    bPacket[12] = len(bUTF8ClientId) // 256
    bPacket[13] = len(bUTF8ClientId) % 256
    offset = 14
    for i in range(0, len(bUTF8ClientId)):
        bPacket[offset + i] = bUTF8ClientId[i]
    

    bPacket[offset + i + 0] = len(bUTF8Username) // 256
    bPacket[offset + i + 1] = len(bUTF8Username) % 256
    offset = offset + i + 2
    for i in range(0, len(bUTF8Username)):
        bPacket[offset + i] = bUTF8Username[i]

    bPacket[offset + i + 0] = len(bUTF8Password) // 256
    bPacket[offset + i + 1] = len(bUTF8Password) % 256
    offset = offset + i + 2;
    for i in range(0, len(bUTF8Password)):
        bPacket[offset + i] = bUTF8Password[i]
        
    return bPacket

def make_packet_conn_without_password(client_id:str):
    i, offset, remLen = 0, 0, 0

    bUTF8 = client_id.encode('utf8')
    remLen = 6 + 1 + 1 + 2 + len(bUTF8) + 2

    bPacket = bytearray(remLen + 2)

    bPacket[0] = 0x10
    bPacket[1] = remLen #// only small packet is supported for now (less than 127)

    bPacket[2] = 0x00
    bPacket[3] = 0x04
    bPacket[4] = ord('M')
    bPacket[5] = ord('Q')
    bPacket[6] = ord('T')
    bPacket[7] = ord('T')

    bPacket[8] = 0x04 #// version -> mqtt v3.1.1
    bPacket[9] = 0x02 #// username_flag =0   password_flag =0  clean_session_flag

    bPacket[10] = 0x00
    bPacket[11] = 0x3C #// keep_alive 60 sec

    bPacket[12] = len(bUTF8) // 256
    bPacket[13] = len(bUTF8) % 256
    offset = 14
    for i in range(0, len(bUTF8)):
        bPacket[offset + i] = bUTF8[i]
    
    return bPacket

def make_packet_pub_qos0(topic:str, payload:str):
    i, offset, remLen = 0, 0, 0

    bUTF8Topic = topic.encode('utf8')
    bUTF8Payload = payload.encode('utf8')

    remLen = 2 + len(bUTF8Topic) + len(bUTF8Payload)

    bPacket = bytearray(remLen + 2)

    bPacket[0] = 0x30
    bPacket[1] = remLen #// only small packet is supported for now (less than 127)

    bPacket[2] = 0x00
    bPacket[3] = len(bUTF8Topic)

    offset = 4
    for i in range(0, len(bUTF8Topic)):
        bPacket[offset + i] = bUTF8Topic[i]

    offset = 4 + len(bUTF8Topic)
    for i in range(0, len(bUTF8Payload)):
        bPacket[offset + i] = bUTF8Payload[i]
    
    return bPacket

def make_packet_sub_qos0(packet_id:int, topic:str):
    i, offset, remLen = 0, 0, 0

    bUTF8Topic = topic.encode('utf8')

    #// packet_id + topic_len + topic + qos
    remLen = 2 + 2 + len(bUTF8Topic) + 1

    bPacket = bytearray(remLen + 2)

    bPacket[0] = 0x82
    bPacket[1] = remLen #// only small packet is supported for now (less than 127)

    bPacket[2] =  packet_id // 256
    bPacket[3] =  packet_id % 256

    bPacket[4] = 0x00
    bPacket[5] = len(bUTF8Topic)

    offset = 6
    for i in range(0, len(bUTF8Topic)):
        bPacket[offset + i] = bUTF8Topic[i]
    
    offset = remLen + 2 - 1
    bPacket[offset] = 0x00 #// qos 0
    return bPacket

def make_packet_unsub_qos0(packet_id:int, topic:str):
    i, offset, remLen = 0, 0, 0

    bUTF8Topic = topic.encode('utf8')

    #// packet_id + topic_len + topic
    remLen = 2 + 2 + len(bUTF8Topic)

    bPacket = bytearray(remLen + 2)

    bPacket[0] = 0xA2
    bPacket[1] = remLen #// only small packet is supported for now (less than 127)

    bPacket[2] = packet_id // 256
    bPacket[3] = packet_id % 256

    bPacket[4] = 0x00
    bPacket[5] = len(bUTF8Topic)

    offset = 6
    for i in range(0, len(bUTF8Topic)):
        bPacket[offset + i] = bUTF8Topic[i]
    
    return bPacket

def make_packet_ping():
    bPacket = bytearray(2)
    bPacket[0] = 0xC0
    bPacket[1] = 0x00
    return  bPacket

def make_packet_disconn():
    bPacket = bytearray(2)
    bPacket[0] = 0xE0
    bPacket[1] = 0x00
    return  bPacket

def to_hex(raw:bytearray):
    hx = ""
    for b in raw:
        hx_0x = hex(b)
        hx_0 = str.replace(hx_0x, "0x","0")
        hx = hx + hx_0[-2:] + " "
    return hx

# print(to_hex(make_packet_conn_without_password("Client08211711")))
# print(to_hex(make_packet_pub_qos0("sht30","{\"temp\":26.5}")))
# print(to_hex(make_packet_sub_qos0(0x0001, "sht30")))
# print(to_hex(make_packet_ping()))
# print(to_hex(make_packet_disconn()))

# ---------python client mqtt from scratch ----------
# HEADERSIZE = 10
clk = 0

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("broker-cn.emqx.io", 1883))

s.send(make_packet_conn_without_password("Client08211711"))
pkt = s.recv(256)
print(to_hex(pkt))

s.send(make_packet_sub_qos0(0x0001, "sht30"))
pkt = s.recv(256)
print(to_hex(pkt))


s.settimeout(0.3)
while True:
    time.sleep(3)
    clk = clk + 1
    if (clk == 15):
        s.send(make_packet_disconn())
        s.close()
        break
    elif (clk % 10 == 0):
        s.send(make_packet_ping())
    
    try:
        pkt = s.recv(256)
        print(to_hex(pkt))
    except Exception as e:
        if str(e) == 'timed out':
            continue
        else:
            print(str(e))
            break

print("mqtt connection closed!")
# --------- the end ----------