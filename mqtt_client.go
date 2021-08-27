package main

import (
	"fmt"
	"log"
	"net"
	"time"
)

func main() {

	// pkt := make_packet_conn_without_password("Client08211711")
	// fmt.Println(to_hex(pkt))
	// pkt = make_packet_pub_qos0("sht30", "{\"temp\":26.5}")
	// fmt.Println(to_hex(pkt))
	// pkt = make_packet_sub_qos0(0x0001, "sht30")
	// fmt.Println(to_hex(pkt))
	// pkt = make_packet_unsub_qos0(0x0001, "sht30")
	// fmt.Println(to_hex(pkt))
	// pkt = make_packet_ping()
	// fmt.Println(to_hex(pkt))
	// pkt = make_packet_disconn()
	// fmt.Println(to_hex(pkt))

	// ---- golang client mqtt from scratch -----

	conn, err := net.Dial("tcp", "broker-cn.emqx.io:1883")
	if err != nil {
		log.Println("cannot connect to broker: ", err)
		return
	}
	defer conn.Close()

	buf := make([]byte, 1024)
	pkt := make_packet_conn_without_password("Client08211711")
	conn.Write(pkt)
	time.Sleep(1 * time.Second)
	cnt, _ := conn.Read(buf[:])
	fmt.Println(to_hex(buf[0:cnt]))

	pkt = make_packet_sub_qos0(0x0001, "sht30")
	conn.Write(pkt)
	time.Sleep(1 * time.Second)
	cnt, _ = conn.Read(buf[:])
	fmt.Println(to_hex(buf[0:cnt]))

	clk := 0
	for {
		time.Sleep(1 * time.Second)
		clk = clk + 1
		if clk == 15 {
			pkt = make_packet_disconn()
			conn.Write(pkt)
			break
		} else if clk%10 == 0 {
			pkt = make_packet_ping()
			conn.Write(pkt)
		}

		err := conn.SetReadDeadline(time.Now().Add(1 * time.Second))
		if err != nil {
			log.Println("SetReadDeadline failed:", err)
			return
		}
		n, err := conn.Read(buf[:]) // recv data
		if err != nil {
			if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
				//log.Println("read timeout:", err) // time out
				fmt.Println("read timeout!")
			} else {
				log.Println("read error:", err) // some error else
			}
		} else {
			rx := buf[0:n]
			fmt.Println(to_hex(rx))
		}
	}
	fmt.Println("mqtt connection closed!")
	//------ the end -----------------------------
}

func to_hex(raw []byte) string {

	hx := "["
	for _, b := range raw {
		hx = hx + fmt.Sprintf("%02x ", b)
	}
	hx = hx + "]"
	return hx // or %X or upper case
}

func checkErr(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func make_packet_conn(client_id string, username string, password string) []byte {
	utf8_client_id := []byte(client_id)
	utf8_username := []byte(username)
	utf8_password := []byte(password)

	// "mqtt" + version + flag + keep_alive + client_id + username + password + strlen_header
	rem_len := 6 + 1 + 1 + 2 + len(utf8_client_id) + len(utf8_username) + len(utf8_password) + 6

	mqtt_packet := make([]byte, rem_len+2) //new byte[remLen + 2];

	mqtt_packet[0] = 0x10
	mqtt_packet[1] = byte(rem_len) // only small packet is supported for now (less than 127)

	mqtt_packet[2] = 0x00
	mqtt_packet[3] = 0x04
	mqtt_packet[4] = 'M'
	mqtt_packet[5] = 'Q'
	mqtt_packet[6] = 'T'
	mqtt_packet[7] = 'T'

	mqtt_packet[8] = 0x04 // version -> mqtt v3.1.1
	mqtt_packet[9] = 0xC2 // '\xC2' username_flag   password_flag  clean_session_flag

	mqtt_packet[10] = 0x00
	mqtt_packet[11] = 0x3C // keep_alive 60 sec

	mqtt_packet[12] = byte(len(utf8_client_id) / 256)
	mqtt_packet[13] = byte(len(utf8_client_id) % 256)
	offset := 14
	for i := 0; i < len(utf8_client_id); i++ {
		mqtt_packet[offset+i] = utf8_client_id[i]
	}
	i := len(utf8_client_id) // after for loop, i is still alive in other language

	mqtt_packet[offset+i+0] = byte(len(utf8_username) / 256)
	mqtt_packet[offset+i+1] = byte(len(utf8_username) % 256)
	offset = offset + i + 2
	for i := 0; i < len(utf8_username); i++ {
		mqtt_packet[offset+i] = utf8_username[i]
	}
	i = len(utf8_username) // after for loop, i is still alive in other language

	mqtt_packet[offset+i+0] = byte(len(utf8_password) / 256)
	mqtt_packet[offset+i+1] = byte(len(utf8_password) % 256)
	offset = offset + i + 2
	for i := 0; i < len(utf8_password); i++ {
		mqtt_packet[offset+i] = utf8_password[i]
	}
	return mqtt_packet

}

func make_packet_conn_without_password(client_id string) []byte {

	utf8_client_id := []byte(client_id)
	rem_len := 6 + 1 + 1 + 2 + len(utf8_client_id) + 2

	mqtt_packet := make([]byte, rem_len+2)

	mqtt_packet[0] = 0x10
	mqtt_packet[1] = byte(rem_len) // only small packet is supported for now (less than 127)

	mqtt_packet[2] = 0x00
	mqtt_packet[3] = 0x04
	mqtt_packet[4] = 'M'
	mqtt_packet[5] = 'Q'
	mqtt_packet[6] = 'T'
	mqtt_packet[7] = 'T'

	mqtt_packet[8] = 0x04 // version -> mqtt v3.1.1
	mqtt_packet[9] = 0x02 // username_flag =0   password_flag =0  clean_session_flag

	mqtt_packet[10] = 0x00
	mqtt_packet[11] = 0x3C // keep_alive 60 sec

	mqtt_packet[12] = byte(len(utf8_client_id) / 256)
	mqtt_packet[13] = byte(len(utf8_client_id) % 256)
	offset := 14
	for i := 0; i < len(utf8_client_id); i++ {
		mqtt_packet[offset+i] = utf8_client_id[i]
	}
	return mqtt_packet
}

func make_packet_pub_qos0(topic string, payload string) []byte {

	utf8_topic := []byte(topic)
	utf8_payload := []byte(payload)

	rem_len := 2 + len(utf8_topic) + len(utf8_payload)

	mqtt_packet := make([]byte, rem_len+2)

	mqtt_packet[0] = 0x30
	mqtt_packet[1] = byte(rem_len) // only small packet is supported for now (less than 127)

	mqtt_packet[2] = 0x00
	mqtt_packet[3] = byte(len(utf8_topic))

	offset := 4
	for i := 0; i < len(utf8_topic); i++ {
		mqtt_packet[offset+i] = utf8_topic[i]
	}

	offset = 4 + len(utf8_topic)
	for i := 0; i < len(utf8_payload); i++ {
		mqtt_packet[offset+i] = utf8_payload[i]
	}
	return mqtt_packet
}

func make_packet_sub_qos0(packet_id uint32, topic string) []byte {

	utf8_topic := []byte(topic)

	// packet_id + topic_len + topic + qos
	rem_len := 2 + 2 + len(utf8_topic) + 1

	mqtt_packet := make([]byte, rem_len+2)

	mqtt_packet[0] = 0x82
	mqtt_packet[1] = byte(rem_len) // only small packet is supported for now (less than 127)

	mqtt_packet[2] = byte(packet_id / 256)
	mqtt_packet[3] = byte(packet_id % 256)

	mqtt_packet[4] = 0x00
	mqtt_packet[5] = byte(len(utf8_topic))

	offset := 6
	for i := 0; i < len(utf8_topic); i++ {
		mqtt_packet[offset+i] = utf8_topic[i]
	}
	offset = rem_len + 2 - 1
	mqtt_packet[offset] = 0x00 // qos 0
	return mqtt_packet
}

func make_packet_unsub_qos0(packet_id uint32, topic string) []byte {

	utf8_topic := []byte(topic)

	// packet_id + topic_len + topic
	rem_len := 2 + 2 + len(utf8_topic)

	mqtt_packet := make([]byte, rem_len+2)

	mqtt_packet[0] = 0xA2
	mqtt_packet[1] = byte(rem_len) // only small packet is supported for now (less than 127)

	mqtt_packet[2] = byte(packet_id / 256)
	mqtt_packet[3] = byte(packet_id % 256)

	mqtt_packet[4] = 0x00
	mqtt_packet[5] = byte(len(utf8_topic))

	offset := 6
	for i := 0; i < len(utf8_topic); i++ {
		mqtt_packet[offset+i] = utf8_topic[i]
	}
	return mqtt_packet
}

func make_packet_ping() []byte {
	mqtt_packet := make([]byte, 2)
	mqtt_packet[0] = 0xC0
	mqtt_packet[1] = 0x00
	return mqtt_packet
}

func make_packet_disconn() []byte {
	mqtt_packet := make([]byte, 2)
	mqtt_packet[0] = 0xE0
	mqtt_packet[1] = 0x00
	return mqtt_packet
}
