package com.example.android_client_mqtt_from_scratch;

import androidx.appcompat.app.AppCompatActivity;

import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.PrintWriter;
import java.net.Socket;
import java.nio.charset.StandardCharsets;

public class MainActivity extends AppCompatActivity {

    Thread Thread1 = null;
    EditText etIP, etPort;
    TextView tvMessages;
    EditText etMessage;
    EditText etTopic;
    Button btnSend;
    Button btnClose;
    String SERVER_IP;
    int SERVER_PORT;
    boolean autoReconn;

    public static String bytes_to_hex(byte[] a) {
        StringBuilder sb = new StringBuilder(a.length * 3);
        for(byte b: a)
            sb.append(String.format("%02x ", b));
        return sb.toString();
    }

    public static byte[] make_packet_conn(String client_id, String username, String password){
        int i, offset, remLen;
        byte[] bPacket;
        byte[] bUTF8ClientId;
        byte[] bUTF8Username;
        byte[] bUTF8Password;

        bUTF8ClientId = client_id.getBytes(StandardCharsets.UTF_8);
        bUTF8Username = username.getBytes(StandardCharsets.UTF_8);
        bUTF8Password = password.getBytes(StandardCharsets.UTF_8);

        // "mqtt" + version + flag + keep_alive + client_id + username + password + strlen_header
        remLen = 6 + 1 + 1 + 2 + bUTF8ClientId.length + bUTF8Username.length + bUTF8Password.length + 6;

        bPacket = new byte[remLen + 2];

        bPacket[0] = 0x10;
        bPacket[1] = (byte) remLen; // only small packet is supported for now (less than 127)

        bPacket[2] = 0x00;
        bPacket[3] = 0x04;
        bPacket[4] = 'M';
        bPacket[5] = 'Q';
        bPacket[6] = 'T';
        bPacket[7] = 'T';

        bPacket[8] = 0x04; // version -> mqtt v3.1.1
        bPacket[9] = (byte) 0xC2; // username_flag   password_flag  clean_session_flag

        bPacket[10] = 0x00;
        bPacket[11] = 0x3C; // keep_alive 60 sec

        bPacket[12] = (byte) (bUTF8ClientId.length / 256);
        bPacket[13] = (byte) (bUTF8ClientId.length % 256);
        offset = 14;
        for (i = 0; i < bUTF8ClientId.length; i++){
            bPacket[offset + i] = bUTF8ClientId[i];
        }

        bPacket[offset + i + 0] = (byte) (bUTF8Username.length / 256);
        bPacket[offset + i + 1] = (byte) (bUTF8Username.length % 256);
        offset = offset + i + 2;
        for (i = 0; i < bUTF8Username.length; i++){
            bPacket[offset + i] = bUTF8Username[i];
        }

        bPacket[offset + i + 0] = (byte) (bUTF8Password.length / 256);
        bPacket[offset + i + 1] = (byte) (bUTF8Password.length % 256);
        offset = offset + i + 2;
        for (i = 0; i < bUTF8Password.length; i++){
            bPacket[offset + i] = bUTF8Password[i];
        }

        return bPacket;
    }

    public static byte[] make_packet_conn_without_password(String client_id){
        int i, offset, remLen;
        byte[] bPacket;
        byte[] bUTF8;

        bUTF8 = client_id.getBytes(StandardCharsets.UTF_8);
        remLen = 6 + 1 + 1 + 2 + bUTF8.length + 2;

        bPacket = new byte[remLen + 2];

        bPacket[0] = 0x10;
        bPacket[1] = (byte) remLen; // only small packet is supported for now (less than 127)

        bPacket[2] = 0x00;
        bPacket[3] = 0x04;
        bPacket[4] = 'M';
        bPacket[5] = 'Q';
        bPacket[6] = 'T';
        bPacket[7] = 'T';

        bPacket[8] = 0x04; // version -> mqtt v3.1.1
        bPacket[9] = 0x02; // username_flag =0   password_flag =0  clean_session_flag

        bPacket[10] = 0x00;
        bPacket[11] = 0x3C; // keep_alive 60 sec

        bPacket[12] = (byte) (bUTF8.length / 256);
        bPacket[13] = (byte) (bUTF8.length % 256);
        offset = 14;
        for (i = 0; i < bUTF8.length; i++){
            bPacket[offset + i] = bUTF8[i];
        }
        return bPacket;
    }

    public static byte[] make_packet_pub_qos0(String topic, String payload){
        int i, offset, remLen;
        byte[] bPacket;
        byte[] bUTF8Topic;
        byte[] bUTF8Payload;

        bUTF8Topic = topic.getBytes(StandardCharsets.UTF_8);
        bUTF8Payload = payload.getBytes(StandardCharsets.UTF_8);

        remLen = 2 + bUTF8Topic.length + bUTF8Payload.length;

        bPacket = new byte[remLen + 2];

        bPacket[0] = 0x30;
        bPacket[1] = (byte) remLen; // only small packet is supported for now (less than 127)

        bPacket[2] = 0x00;
        bPacket[3] = (byte) bUTF8Topic.length;

        offset = 4;
        for (i = 0; i < bUTF8Topic.length; i++){
            bPacket[offset + i] = bUTF8Topic[i];
        }

        offset = 4 + bUTF8Topic.length;
        for (i = 0; i < bUTF8Payload.length; i++){
            bPacket[offset + i] = bUTF8Payload[i];
        }
        return bPacket;
    }

    public static byte[] make_packet_sub_qos0(int packet_id, String topic){
        int i, offset, remLen;
        byte[] bPacket;
        byte[] bUTF8Topic;

        bUTF8Topic = topic.getBytes(StandardCharsets.UTF_8);

        // packet_id + topic_len + topic + qos
        remLen = 2 + 2 + bUTF8Topic.length + 1;

        bPacket = new byte[remLen + 2];

        bPacket[0] = (byte) 0x82;
        bPacket[1] = (byte) remLen; // only small packet is supported for now (less than 127)

        bPacket[2] =  (byte) (packet_id / 256);
        bPacket[3] =  (byte) (packet_id % 256);

        bPacket[4] = 0x00;
        bPacket[5] = (byte) bUTF8Topic.length;

        offset = 6;
        for (i = 0; i < bUTF8Topic.length; i++){
            bPacket[offset + i] = bUTF8Topic[i];
        }
        offset = remLen + 2 - 1;
        bPacket[offset] = 0x00; // qos 0
        return bPacket;
    }

    public static byte[] make_packet_unsub_qos0(int packet_id, String topic){
        int i, offset, remLen;
        byte[] bPacket;
        byte[] bUTF8Topic;

        bUTF8Topic = topic.getBytes(StandardCharsets.UTF_8);

        // packet_id + topic_len + topic
        remLen = 2 + 2 + bUTF8Topic.length;

        bPacket = new byte[remLen + 2];

        bPacket[0] = (byte) 0xA2;
        bPacket[1] = (byte) remLen; // only small packet is supported for now (less than 127)

        bPacket[2] =  (byte) (packet_id / 256);
        bPacket[3] =  (byte) (packet_id % 256);

        bPacket[4] = 0x00;
        bPacket[5] = (byte) bUTF8Topic.length;

        offset = 6;
        for (i = 0; i < bUTF8Topic.length; i++){
            bPacket[offset + i] = bUTF8Topic[i];
        }
        return bPacket;
    }

    public static byte[] make_packet_ping(){
        byte[] bPacket;
        bPacket = new byte[2];
        bPacket[0] = (byte) 0xC0;
        bPacket[1] = 0x00;
        return  bPacket;
    }

    public static byte[] make_packet_disconn(){
        byte[] bPacket;
        bPacket = new byte[2];
        bPacket[0] = (byte) 0xE0;
        bPacket[1] = 0x00;
        return  bPacket;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        autoReconn = false;
        etIP = findViewById(R.id.etIP);
        etPort = findViewById(R.id.etPort);
        tvMessages = findViewById(R.id.tvMessages);
        etMessage = findViewById(R.id.etMessage);
        etTopic = findViewById(R.id.etTopic);
        btnSend = findViewById(R.id.btnSend);
        btnClose = findViewById(R.id.btnClose);
        Button btnReceive = findViewById(R.id.btnReceive);
        Button btnConnect = findViewById(R.id.btnConnect);
        btnConnect.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                tvMessages.setText("");
                SERVER_IP = etIP.getText().toString().trim();
                SERVER_PORT = Integer.parseInt(etPort.getText().toString().trim());
                Thread1 = new Thread(new Thread1());
                Thread1.start();
            }
        });
        btnSend.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                String message = etMessage.getText().toString().trim();
                if (!message.isEmpty()) {
                    new Thread(new Thread3(message)).start();
                }
            }
        });
        btnClose.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                autoReconn = false;
                byte[] pkt = make_packet_disconn();
                new Thread(new Thread4(pkt)).start();
            }
        });
        btnReceive.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                String topic = etTopic.getText().toString().trim();
                byte[] pkt = make_packet_sub_qos0(0x0001, topic);
                new Thread(new Thread4(pkt)).start();
            }
        });
    }

    private PrintWriter output;
    private BufferedReader input;
    //private DataInputStream in;
    //private DataOutputStream out;
    private OutputStream out;
    private InputStream in;

    class Thread1 implements Runnable {
        public void run() {
            Socket socket;
            try {
                socket = new Socket(SERVER_IP, SERVER_PORT);
                //output = new PrintWriter(socket.getOutputStream());
                //input = new BufferedReader(new InputStreamReader(socket.getInputStream()));
                out = socket.getOutputStream();
                in = socket.getInputStream();
                out.write(make_packet_conn_without_password("Client08181508"));
                out.flush();
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        tvMessages.setText("Connected\n");
                    }
                });
                new Thread(new Thread2()).start();
                new Thread(new Thread5()).start(); // mqtt ping
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }
    class Thread2 implements Runnable {
        @Override
        public void run() {
            while (true) {
                try {
                    //final String message = input.readLine();
                    byte[] rawData = new byte[256];
                    int cnt = in.read(rawData,0,256);

                    if (cnt > 0) {
                        byte[] copiedArray = new byte[cnt];
                        System.arraycopy(rawData, 0, copiedArray, 0, cnt);
                        final String message = bytes_to_hex(copiedArray);

                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                tvMessages.append("server: " + message + "\n");
                            }
                        });
                    } else {
                        in.close();
                        out.close();
                        if (autoReconn) {
                            Thread1 = new Thread(new Thread1());
                            Thread1.start();
                        }
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                tvMessages.append("server: connection closed" + "\n");
                            }
                        });
                        return;
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
    }
    class Thread3 implements Runnable {
        private String message;
        Thread3(String message) {
            this.message = message;
        }
        @Override
        public void run() {
            //output.write(message);
            //output.flush();
            try {
                out.write(make_packet_pub_qos0("sht30", message));
                out.flush();
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        tvMessages.append("client: " + message + "\n");
                        etMessage.setText("");
                    }
                });
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    class Thread4 implements Runnable {
        private byte[] message;
        Thread4(byte[] message) {
            this.message = message;
        }
        @Override
        public void run() {
            try {
                out.write(message);
                out.flush();
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        tvMessages.append("client: " + bytes_to_hex(message) + "\n");
                    }
                });
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    class Thread5 implements Runnable {

        boolean stopWorking = false;
        @Override
        public void run() {
            while (!stopWorking){
                try {
                    out.write(make_packet_ping());
                    out.flush();
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            tvMessages.append("client: ping..." + "\n");
                        }
                    });
                    Thread.sleep(30000);
                } catch (IOException | InterruptedException e) {
                    stopWorking = true;
                    e.printStackTrace();
                }
            }
        }
    }
}