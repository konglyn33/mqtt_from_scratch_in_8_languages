#include "mainwindow.h"
#include "ui_mainwindow.h"

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);

    socket = new QTcpSocket();

    connect(socket, &QTcpSocket::connected, this, &MainWindow::socketConnected);
    connect(socket, &QTcpSocket::disconnected, this, &MainWindow::socketDisconnected);
    connect(socket, &QTcpSocket::readyRead, this, &MainWindow::socketReadyRead);

    timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this,  &MainWindow::tmrPing);
    //timer->start(1000);
}

MainWindow::~MainWindow()
{
    delete ui;
}

void MainWindow::printMessage(QString message) {
    ui->txtReceive->append(message);
}

QByteArray MainWindow::make_packet_conn(QString client_id, QString username, QString password)
{
    int i, offset, remLen;

    QByteArray bUTF8ClientId = client_id.toUtf8();
    QByteArray bUTF8Username = username.toUtf8();
    QByteArray bUTF8Password = password.toUtf8();

    // "mqtt" + version + flag + keep_alive + client_id + username + password + strlen_header
    remLen = 6 + 1 + 1 + 2 + bUTF8ClientId.length() + bUTF8Username.length() + bUTF8Password.length() + 6;

    QByteArray bPacket(remLen + 2, 0); //new byte[remLen + 2];

    bPacket[0] = 0x10;
    bPacket[1] = remLen; // only small packet is supported for now (less than 127)

    bPacket[2] = 0x00;
    bPacket[3] = 0x04;
    bPacket[4] = 'M';
    bPacket[5] = 'Q';
    bPacket[6] = 'T';
    bPacket[7] = 'T';

    bPacket[8] = 0x04; // version -> mqtt v3.1.1
    bPacket[9] = (char)0xC2; // '\xC2' username_flag   password_flag  clean_session_flag

    bPacket[10] = 0x00;
    bPacket[11] = 0x3C; // keep_alive 60 sec

    bPacket[12] =(char) (bUTF8ClientId.length() / 256);
    bPacket[13] =(char) (bUTF8ClientId.length() % 256);
    offset = 14;
    for (i = 0; i < bUTF8ClientId.length(); i++){
        bPacket[offset + i] = bUTF8ClientId[i];
    }

    bPacket[offset + i + 0] =(char) (bUTF8Username.length() / 256);
    bPacket[offset + i + 1] =(char) (bUTF8Username.length() % 256);
    offset = offset + i + 2;
    for (i = 0; i < bUTF8Username.length(); i++){
        bPacket[offset + i] = bUTF8Username[i];
    }

    bPacket[offset + i + 0] =(char) (bUTF8Password.length() / 256);
    bPacket[offset + i + 1] =(char) (bUTF8Password.length() % 256);
    offset = offset + i + 2;
    for (i = 0; i < bUTF8Password.length(); i++){
        bPacket[offset + i] = bUTF8Password[i];
    }

    return bPacket;
    //return static_cast<QByteArray&&>(bPacket);
}

QByteArray MainWindow::make_packet_conn_without_password(QString client_id)
{
    int i, offset, remLen;

    QByteArray bUTF8 = client_id.toUtf8();
    remLen = 6 + 1 + 1 + 2 + bUTF8.length() + 2;

    QByteArray bPacket(remLen + 2, 0);

    bPacket[0] = 0x10;
    bPacket[1] = (char) remLen; // only small packet is supported for now (less than 127)

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

    bPacket[12] = (char) (bUTF8.length() / 256);
    bPacket[13] = (char) (bUTF8.length() % 256);
    offset = 14;
    for (i = 0; i < bUTF8.length(); i++){
        bPacket[offset + i] = bUTF8[i];
    }
    return bPacket;
    //return static_cast<QByteArray&&>(bPacket);
}
QByteArray MainWindow::make_packet_pub_qos0(QString topic, QString payload)
{
    int i, offset, remLen;

    QByteArray bUTF8Topic = topic.toUtf8();
    QByteArray bUTF8Payload = payload.toUtf8();

    remLen = 2 + bUTF8Topic.length() + bUTF8Payload.length();

    QByteArray bPacket(remLen + 2, 0);

    bPacket[0] = 0x30;
    bPacket[1] = (char) remLen; // only small packet is supported for now (less than 127)

    bPacket[2] = 0x00;
    bPacket[3] = (char) bUTF8Topic.length();

    offset = 4;
    for (i = 0; i < bUTF8Topic.length(); i++){
        bPacket[offset + i] = bUTF8Topic[i];
    }

    offset = 4 + bUTF8Topic.length();
    for (i = 0; i < bUTF8Payload.length(); i++){
        bPacket[offset + i] = bUTF8Payload[i];
    }
    return bPacket;
}
QByteArray MainWindow::make_packet_sub_qos0(int packet_id, QString topic)
{
    int i, offset, remLen;

    QByteArray bUTF8Topic = topic.toUtf8();

    // packet_id + topic_len + topic + qos
    remLen = 2 + 2 + bUTF8Topic.length() + 1;

    QByteArray bPacket(remLen + 2, 0);

    bPacket[0] = (char) 0x82;
    bPacket[1] = (char) remLen; // only small packet is supported for now (less than 127)

    bPacket[2] =  (char) (packet_id / 256);
    bPacket[3] =  (char) (packet_id % 256);

    bPacket[4] = 0x00;
    bPacket[5] = (char) bUTF8Topic.length();

    offset = 6;
    for (i = 0; i < bUTF8Topic.length(); i++){
        bPacket[offset + i] = bUTF8Topic[i];
    }
    offset = remLen + 2 - 1;
    bPacket[offset] = 0x00; // qos 0
    return bPacket;
}
QByteArray MainWindow::make_packet_unsub_qos0(int packet_id, QString topic)
{
    int i, offset, remLen;

    QByteArray bUTF8Topic = topic.toUtf8();

    // packet_id + topic_len + topic
    remLen = 2 + 2 + bUTF8Topic.length();

    QByteArray bPacket(remLen + 2, 0);

    bPacket[0] = (char) 0xA2;
    bPacket[1] = (char) remLen; // only small packet is supported for now (less than 127)

    bPacket[2] =  (char) (packet_id / 256);
    bPacket[3] =  (char) (packet_id % 256);

    bPacket[4] = 0x00;
    bPacket[5] = (char) bUTF8Topic.length();

    offset = 6;
    for (i = 0; i < bUTF8Topic.length(); i++){
        bPacket[offset + i] = bUTF8Topic[i];
    }
    return bPacket;
}
QByteArray MainWindow::make_packet_ping(void)
{
    QByteArray bPacket(2, 0);
    bPacket[0] = (char) 0xC0;
    bPacket[1] = 0x00;
    return  bPacket;
}
QByteArray MainWindow::make_packet_disconn(void)
{
    QByteArray bPacket(2, 0);
    bPacket[0] = (char) 0xE0;
    bPacket[1] = 0x00;
    return  bPacket;
}



void MainWindow::on_btnConnect_clicked()
{
    QString broker = ui->txtBroker->text();
    socket->connectToHost(broker, 1883);
}

void MainWindow::on_btnClose_clicked()
{
    QByteArray pkt = make_packet_disconn();
    socket->write(pkt);

    //socket->disconnectFromHost();
}

void MainWindow::on_btnSub_clicked()
{
    QByteArray pkt = make_packet_sub_qos0(0x0001,"sht30");
    socket->write(pkt);
}

void MainWindow::on_btnPub_clicked()
{
    QString tpc = ui->txtTopic->text();
    QString msg = ui->txtMsg->text();
    QByteArray pkt = make_packet_pub_qos0(tpc,msg);
    socket->write(pkt);
}

void MainWindow::tmrPing()
{
    QByteArray pkt = make_packet_ping();
    socket->write(pkt);
}


void MainWindow::socketConnected()
{
    qDebug() << "Connected to server.";

    printMessage("<font color=\"Green\">Connected to server.</font>");

    QByteArray pkt = make_packet_conn_without_password("Client08211013");
    socket->write(pkt);

    timer->start(30000);

    connectedToHost = true;
}
void MainWindow::socketDisconnected()
{
    qDebug() << "Disconnected from server.";

    printMessage("<font color=\"Red\">Disconnected from server.</font>");

    connectedToHost = false;
}
void MainWindow::socketReadyRead()
{
    QByteArray pkt = socket->readAll();
    QString hex = pkt.toHex(' ');
    printMessage(hex);
}
