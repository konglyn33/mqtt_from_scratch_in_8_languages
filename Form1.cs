using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Net.Sockets;


namespace Winform_Client_Mqtt_From_Scratch
{
    public partial class Form1 : Form
    {
        int iCLK = 0;
        System.Net.Sockets.TcpClient clientSocket = new System.Net.Sockets.TcpClient();

        public Form1()
        {
            InitializeComponent();
        }

        private static byte[] make_packet_conn_without_password(string client_id)
        {
            int i, offset, remLen;
            byte[] bPacket;
            byte[] bUTF8;

            bUTF8 = Encoding.UTF8.GetBytes(client_id);
            remLen = 6 + 1 + 1 + 2 + bUTF8.Length + 2;

            bPacket = new byte[remLen + 2];

            bPacket[0] = 0x10;
            bPacket[1] = (byte)remLen; // only small packet is supported for now (less than 127)

            bPacket[2] = 0x00;
            bPacket[3] = 0x04;
            bPacket[4] = (byte)'M';
            bPacket[5] = (byte)'Q';
            bPacket[6] = (byte)'T';
            bPacket[7] = (byte)'T';

            bPacket[8] = 0x04; // version -> mqtt v3.1.1
            bPacket[9] = 0x02; // username_flag =0   password_flag =0  clean_session_flag

            bPacket[10] = 0x00;
            bPacket[11] = 0x3C; // keep_alive 60 sec

            bPacket[12] = (byte)(bUTF8.Length / 256);
            bPacket[13] = (byte)(bUTF8.Length % 256);
            offset = 14;
            for (i = 0; i < bUTF8.Length; i++)
            {
                bPacket[offset + i] = bUTF8[i];
            }
            return bPacket;
        }

        private static byte[] make_packet_conn(string client_id, string username, string password)
        {
            int i, offset, remLen;
            byte[] bPacket;
            byte[] bUTF8ClientId;
            byte[] bUTF8Username;
            byte[] bUTF8Password;

            bUTF8ClientId = Encoding.UTF8.GetBytes(client_id);
            bUTF8Username = Encoding.UTF8.GetBytes(username);
            bUTF8Password = Encoding.UTF8.GetBytes(password);

            // "mqtt" + version + flag + keep_alive + client_id + username + password + strlen_header
            remLen = 6 + 1 + 1 + 2 + bUTF8ClientId.Length + bUTF8Username.Length + bUTF8Password.Length + 6;

            bPacket = new byte[remLen + 2];

            bPacket[0] = 0x10;
            bPacket[1] = (byte)remLen; // only small packet is supported for now (less than 127)

            bPacket[2] = 0x00;
            bPacket[3] = 0x04;
            bPacket[4] = (byte)'M';
            bPacket[5] = (byte)'Q';
            bPacket[6] = (byte)'T';
            bPacket[7] = (byte)'T';

            bPacket[8] = 0x04; // version -> mqtt v3.1.1
            bPacket[9] = (byte)0xC2; // username_flag   password_flag  clean_session_flag

            bPacket[10] = 0x00;
            bPacket[11] = 0x3C; // keep_alive 60 sec

            bPacket[12] = (byte)(bUTF8ClientId.Length / 256);
            bPacket[13] = (byte)(bUTF8ClientId.Length % 256);
            offset = 14;
            for (i = 0; i < bUTF8ClientId.Length; i++)
            {
                bPacket[offset + i] = bUTF8ClientId[i];
            }

            bPacket[offset + i + 0] = (byte)(bUTF8Username.Length / 256);
            bPacket[offset + i + 1] = (byte)(bUTF8Username.Length % 256);
            offset = offset + i + 2;
            for (i = 0; i < bUTF8Username.Length; i++)
            {
                bPacket[offset + i] = bUTF8Username[i];
            }

            bPacket[offset + i + 0] = (byte)(bUTF8Password.Length / 256);
            bPacket[offset + i + 1] = (byte)(bUTF8Password.Length % 256);
            offset = offset + i + 2;
            for (i = 0; i < bUTF8Password.Length; i++)
            {
                bPacket[offset + i] = bUTF8Password[i];
            }

            return bPacket;
        }

        private static byte[] make_packet_sub_qos0(int packet_id, string topic)
        {
            int i, offset, remLen;
            byte[] bPacket;
            byte[] bUTF8Topic;

            bUTF8Topic = Encoding.UTF8.GetBytes(topic);

            // packet_id + topic_len + topic + qos
            remLen = 2 + 2 + bUTF8Topic.Length + 1;

            bPacket = new byte[remLen + 2];

            bPacket[0] = (byte)0x82;
            bPacket[1] = (byte)remLen; // only small packet is supported for now (less than 127)

            bPacket[2] = (byte)(packet_id / 256);
            bPacket[3] = (byte)(packet_id % 256);

            bPacket[4] = 0x00;
            bPacket[5] = (byte)bUTF8Topic.Length;

            offset = 6;
            for (i = 0; i < bUTF8Topic.Length; i++)
            {
                bPacket[offset + i] = bUTF8Topic[i];
            }
            offset = remLen + 2 - 1;
            bPacket[offset] = 0x00; // qos 0
            return bPacket;
        }

        private static byte[] make_packet_unsub_qos0(int packet_id, string topic)
        {
            int i, offset, remLen;
            byte[] bPacket;
            byte[] bUTF8Topic;

            bUTF8Topic = Encoding.UTF8.GetBytes(topic);

            // packet_id + topic_len + topic
            remLen = 2 + 2 + bUTF8Topic.Length;

            bPacket = new byte[remLen + 2];

            bPacket[0] = (byte)0xA2;
            bPacket[1] = (byte)remLen; // only small packet is supported for now (less than 127)

            bPacket[2] = (byte)(packet_id / 256);
            bPacket[3] = (byte)(packet_id % 256);

            bPacket[4] = 0x00;
            bPacket[5] = (byte)bUTF8Topic.Length;

            offset = 6;
            for (i = 0; i < bUTF8Topic.Length; i++)
            {
                bPacket[offset + i] = bUTF8Topic[i];
            }
            return bPacket;
        }

        private static byte[] make_packet_pub_qos0(string topic, string payload)
        {
            int i, offset, remLen;
            byte[] bPacket;
            byte[] bUTF8Topic;
            byte[] bUTF8Payload;

            bUTF8Topic = Encoding.UTF8.GetBytes(topic);
            bUTF8Payload = Encoding.UTF8.GetBytes(payload);

            remLen = 2 + bUTF8Topic.Length + bUTF8Payload.Length;

            bPacket = new byte[remLen + 2];

            bPacket[0] = 0x30;
            bPacket[1] = (byte)remLen; // only small packet is supported for now (less than 127)

            bPacket[2] = 0x00;
            bPacket[3] = (byte)bUTF8Topic.Length;

            offset = 4;
            for (i = 0; i < bUTF8Topic.Length; i++)
            {
                bPacket[offset + i] = bUTF8Topic[i];
            }

            offset = 4 + bUTF8Topic.Length;
            for (i = 0; i < bUTF8Payload.Length; i++)
            {
                bPacket[offset + i] = bUTF8Payload[i];
            }
            return bPacket;
        }

        private static byte[] make_packet_ping()
        {
            byte[] bPacket;
            bPacket = new byte[2];
            bPacket[0] =(byte)0xC0;
            bPacket[1] = 0x00;
            return bPacket;
        }

        private static byte[] make_packet_disconn()
        {
            byte[] bPacket;
            bPacket = new byte[2];
            bPacket[0] = (byte)0xE0;
            bPacket[1] = 0x00;
            return bPacket;
        }

        private static bool connection_closed(Socket s)
        {
            bool part1 = s.Poll(100, SelectMode.SelectRead);
            bool part2 = (s.Available == 0);
            if (part1 && part2)
                return true;
            else
                return false;
        }

        private void logRx(string mesg)
        {
            txtReceive.Text = txtReceive.Text + " >> " + mesg + "\r\n";
        }



        private void btnConnect_Click(object sender, EventArgs e)
        {
            string broker = txtBroker.Text.Trim();
            try
            {
                clientSocket.Connect(broker, 1883);

                NetworkStream serverStream = clientSocket.GetStream();
                byte[] pkt = make_packet_conn_without_password("Client08201014");
                serverStream.Write(pkt, 0, pkt.Length);
                serverStream.Flush();
                tmrRx.Enabled = true;
                logRx("Server Connected ...");
            }
            catch(Exception someErr)
            {
                logRx(someErr.Message);
            }

        }

        private void btnClose_Click(object sender, EventArgs e)
        {
            NetworkStream serverStream = clientSocket.GetStream();
            byte[] pkt = make_packet_disconn();
            serverStream.Write(pkt, 0, pkt.Length);
            serverStream.Flush();
            logRx("client >> connection closing ...");
        }

        private void btnSub_Click(object sender, EventArgs e)
        {
            string tpc = txtTopic.Text.Trim();

            NetworkStream serverStream = clientSocket.GetStream();
            byte[] pkt = make_packet_sub_qos0(0x0001, tpc);
            serverStream.Write(pkt, 0, pkt.Length);
            serverStream.Flush();
            logRx("client >> subscribe to " + tpc);
        }

        private void btnPub_Click(object sender, EventArgs e)
        {
            string msg = txtMsg.Text.Trim();

            NetworkStream serverStream = clientSocket.GetStream();
            byte[] pkt = make_packet_pub_qos0("sht30", msg);
            serverStream.Write(pkt, 0, pkt.Length);
            serverStream.Flush();
            logRx("client >> " + msg);
        }

        private void tmrRx_Tick(object sender, EventArgs e)
        {
            iCLK = iCLK + 1;

            NetworkStream serverStream = clientSocket.GetStream();

            if (iCLK % 30 == 0)
            {
                byte[] pkt = make_packet_ping();
                serverStream.Write(pkt, 0, pkt.Length);
                serverStream.Flush();
                logRx("client >> ping ...");
            }
            else
            {
                int rxCnt = clientSocket.Available;
                if (rxCnt > 1)
                {
                    byte[] pkt = new byte[rxCnt];
                    serverStream.Read(pkt, 0, rxCnt);
                    string hex = BitConverter.ToString(pkt).Replace("-", " ");
                    logRx("server >> " + hex);
                } 
                else
                {
                    if (connection_closed(clientSocket.Client))
                    {
                        tmrRx.Enabled = false;
                        logRx("Connection closed!");
                    }
                }
            }
        }
    }
}
