use std::str;
use std::time::Duration;
use std::fmt::Write as FmtWrite;
use std::net::{SocketAddr, Shutdown, TcpStream};
use std::io::{Read, Write};
use dns_lookup::lookup_host;
//---Cargo.toml---
//[dependencies]
//dns-lookup = "1.0.8"

#[allow(dead_code)]
fn make_packet_conn(client_id: &str, username: &str, password: &str) -> Vec<u8> {

    let utf8_client_id = client_id.as_bytes();
    let utf8_username = username.as_bytes();
    let utf8_password = password.as_bytes();

    // "mqtt" + version + flag + keep_alive + client_id + username + password + strlen_header
    let rem_len = 6 + 1 + 1 + 2 + utf8_client_id.len() + utf8_username.len() + utf8_password.len() + 6;

    let mut mqtt_packet= vec![0; rem_len + 2]; //new byte[remLen + 2];

    mqtt_packet[0] = 0x10;
    mqtt_packet[1] = rem_len as u8; // only small packet is supported for now (less than 127)

    mqtt_packet[2] = 0x00;
    mqtt_packet[3] = 0x04;
    mqtt_packet[4] = b'M';
    mqtt_packet[5] = b'Q';
    mqtt_packet[6] = b'T';
    mqtt_packet[7] = b'T';

    mqtt_packet[8] = 0x04; // version -> mqtt v3.1.1
    mqtt_packet[9] = 0xC2; // '\xC2' username_flag   password_flag  clean_session_flag

    mqtt_packet[10] = 0x00;
    mqtt_packet[11] = 0x3C; // keep_alive 60 sec

    mqtt_packet[12] = (utf8_client_id.len() / 256) as u8;
    mqtt_packet[13] = (utf8_client_id.len() % 256) as u8;
    let mut offset = 14;
    for i in 0..utf8_client_id.len() {
        mqtt_packet[offset + i] = utf8_client_id[i];
    }
    let mut i = utf8_client_id.len(); // after for loop, i is still alive in other language

    mqtt_packet[offset + i + 0] = (utf8_username.len() / 256) as u8;
    mqtt_packet[offset + i + 1] = (utf8_username.len() % 256) as u8;
    offset = offset + i + 2;
    for i in 0..utf8_username.len() {
        mqtt_packet[offset + i] = utf8_username[i];
    }
    i = utf8_username.len(); // after for loop, i is still alive in other language

    mqtt_packet[offset + i + 0] = (utf8_password.len() / 256) as u8;
    mqtt_packet[offset + i + 1] = (utf8_password.len() % 256) as u8;
    offset = offset + i + 2;
    for i in 0..utf8_password.len() {
        mqtt_packet[offset + i] = utf8_password[i];
    }

    return mqtt_packet;
}

fn make_packet_conn_without_password(client_id: &str) -> Vec<u8> {

    let utf8_client_id = client_id.as_bytes();
    let rem_len = 6 + 1 + 1 + 2 + utf8_client_id.len() + 2;

    let mut mqtt_packet = vec![0; rem_len + 2]; 

    mqtt_packet[0] = 0x10;
    mqtt_packet[1] = rem_len as u8; // only small packet is supported for now (less than 127)

    mqtt_packet[2] = 0x00;
    mqtt_packet[3] = 0x04;
    mqtt_packet[4] = b'M';
    mqtt_packet[5] = b'Q';
    mqtt_packet[6] = b'T';
    mqtt_packet[7] = b'T';

    mqtt_packet[8] = 0x04; // version -> mqtt v3.1.1
    mqtt_packet[9] = 0x02; // username_flag =0   password_flag =0  clean_session_flag

    mqtt_packet[10] = 0x00;
    mqtt_packet[11] = 0x3C; // keep_alive 60 sec

    mqtt_packet[12] = (utf8_client_id.len() / 256) as u8;
    mqtt_packet[13] = (utf8_client_id.len() % 256) as u8;
    let offset = 14;
    for i in 0..utf8_client_id.len() {
        mqtt_packet[offset + i] = utf8_client_id[i];
    }
    return mqtt_packet;

}


fn make_packet_pub_qos0(topic: &str, payload: &str) -> Vec<u8> {

    let utf8_topic = topic.as_bytes();
    let utf8_payload = payload.as_bytes();

    let rem_len = 2 + utf8_topic.len() + utf8_payload.len();

    let mut mqtt_packet = vec![0; rem_len + 2];

    mqtt_packet[0] = 0x30;
    mqtt_packet[1] = rem_len as u8; // only small packet is supported for now (less than 127)

    mqtt_packet[2] = 0x00;
    mqtt_packet[3] = utf8_topic.len() as u8;

    let mut offset = 4;
    for i in 0..utf8_topic.len() {
        mqtt_packet[offset + i] = utf8_topic[i];
    }

    offset = 4 + utf8_topic.len();
    for i in 0..utf8_payload.len() {
        mqtt_packet[offset + i] = utf8_payload[i];
    }
    return mqtt_packet;
}

fn make_packet_sub_qos0(packet_id: u32, topic: &str) -> Vec<u8> {

    let utf8_topic = topic.as_bytes();

    // packet_id + topic_len + topic + qos
    let rem_len = 2 + 2 + utf8_topic.len() + 1;

    let mut mqtt_packet = vec![0; rem_len + 2];

    mqtt_packet[0] = 0x82;
    mqtt_packet[1] = rem_len as u8; // only small packet is supported for now (less than 127)

    mqtt_packet[2] = (packet_id / 256) as u8;
    mqtt_packet[3] = (packet_id % 256) as u8;

    mqtt_packet[4] = 0x00;
    mqtt_packet[5] = utf8_topic.len() as u8;

    let mut offset = 6;
    for i in 0..utf8_topic.len() {
        mqtt_packet[offset + i] = utf8_topic[i];
    }
    offset = rem_len + 2 - 1;
    mqtt_packet[offset] = 0x00; // qos 0
    return mqtt_packet;
}


fn make_packet_unsub_qos0(packet_id: u32, topic: &str) -> Vec<u8> {

    let utf8_topic = topic.as_bytes();

    // packet_id + topic_len + topic
    let rem_len = 2 + 2 + utf8_topic.len();

    let mut mqtt_packet = vec![0; rem_len + 2];

    mqtt_packet[0] = 0xA2;
    mqtt_packet[1] = rem_len as u8; // only small packet is supported for now (less than 127)

    mqtt_packet[2] =  (packet_id / 256) as u8;
    mqtt_packet[3] =  (packet_id % 256) as u8;

    mqtt_packet[4] = 0x00;
    mqtt_packet[5] = utf8_topic.len() as u8;

    let offset = 6;
    for i in 0..utf8_topic.len() {
        mqtt_packet[offset + i] = utf8_topic[i];
    }
    return mqtt_packet;
}

fn make_packet_ping() -> Vec<u8> {
    let mut mqtt_packet = vec![0; 2];
    mqtt_packet[0] = 0xC0;
    mqtt_packet[1] = 0x00;
    return  mqtt_packet;
}

fn make_packet_disconn() -> Vec<u8> {
    let mut mqtt_packet = vec![0; 2];
    mqtt_packet[0] = 0xE0;
    mqtt_packet[1] = 0x00;
    return  mqtt_packet;
}

fn to_hex(raw: &Vec<u8>) -> String {
    let n = raw.len();
    let mut s = String::with_capacity(3 * n);
    for byte in raw {
        write!(s, "{:02X} ", byte).unwrap();
    }
    return s;
}


fn main() {

    // let mut pkt = make_packet_conn_without_password("Client08211711");
    // println!("{:02X?}", pkt);
    let pkt = make_packet_pub_qos0("sht30", "{\"temp\":26.5}");
    println!("{:02X?}", pkt);
    // pkt = make_packet_sub_qos0(0x0001, "sht30");
    // println!("{:02X?}", pkt);
    let pkt = make_packet_unsub_qos0(0x0001, "sht30");
    println!("{}", to_hex(&pkt));
    // pkt = make_packet_ping();
    // println!("{:02X?}", pkt);

    // pkt = make_packet_disconn();
    // println!("{}", to_hex(&pkt));


    // -------- rust client mqtt from scrath ----------
    let mut clk = 0 as u32;
    //let remote: SocketAddr = "broker-cn.emqx.io:1883".parse().unwrap();
    let hostname = "broker-cn.emqx.io";
    let ips: Vec<std::net::IpAddr> = lookup_host(hostname).unwrap();
    let ip = ips[0];
    let broker: SocketAddr = SocketAddr::new(ip,1883);
    let wait_time = Duration::from_secs(3);
    let mut stream = TcpStream::connect_timeout(&broker, wait_time).expect("Could not connect to server");
    // let mut stream = TcpStream::connect("broker-cn.emqx.io:1883").unwrap();
    stream.set_read_timeout(Some(wait_time)).expect("Could not set a read timeout");

    let mut buf = [0 as u8; 256];
    let pkt = make_packet_conn_without_password("Client08211711");
    stream.write(&pkt).expect("Faild to send mqtt conn packet");
    let mut bytes_read = stream.read(&mut buf).expect("Could not read into buf");
    println!("Server: {:02X?}", &buf[..bytes_read]);

    let pkt = make_packet_sub_qos0(0x0001, "sht30");
    stream.write(&pkt).expect("Faild to send mqtt conn packet");
    bytes_read = stream.read(&mut buf).expect("Could not read into buf");
    println!("Server: {:02X?}", &buf[0..bytes_read]);

    loop {
        std::thread::sleep(Duration::from_millis(3000));
        clk = clk + 1;

        if clk == 15 {
            let pkt = make_packet_disconn();
            stream.write(&pkt).expect("Faild to send mqtt disconn packet");
            break
        } else if clk % 10 == 0 {
            let pkt = make_packet_ping();
            stream.write(&pkt).expect("Faild to send mqtt ping packet");
        }
        match stream.read(&mut buf) {
            Ok(cnt) => {println!("Server: {:02X?}", &buf[0..cnt]);}
            Err(_) => {println!("Server: read timeout!");}
        }
    }
    stream.shutdown(Shutdown::Both).expect("shutdown call failed");
    println!("mqtt connection closed.");
}