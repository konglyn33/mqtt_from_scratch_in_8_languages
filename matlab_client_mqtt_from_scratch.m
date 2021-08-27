
% # ---------matlab client mqtt from scratch ----------
% connection will be closed after trying to read 15 times

% disp(to_hex(make_packet_conn_without_password("Client08211711")));
% disp(to_hex(make_packet_pub_qos0('sht30', "{""temp"":26.5}")));
% disp(to_hex(make_packet_sub_qos0(1, "sht30")));
% disp(to_hex(make_packet_ping()));
% disp(to_hex(make_packet_disconn()));
clk = 0;
address = resolvehost("broker-cn.emqx.io","address");
t = tcpclient(address, 1883);
%t = tcpclient("127.0.0.1", 4444);
disp("mqtt connection opened!");
write(t, make_packet_conn_without_password("Client08241340"));
pause(1);
pkt = read(t);
disp(to_hex(pkt));

write(t, make_packet_sub_qos0(1, "sht30"));
pause(1);
pkt = read(t);
disp(to_hex(pkt));

while true
    pause(3);
    clk = clk + 1;
    if clk == 15
        write(t, make_packet_disconn());
        clear t
        break
    elseif mod(clk, int32(10)) == 0 % safe when clk isInt && clk < 2^15 or -> int32(mod(clk, int32(10))) == 0
        write(t, make_packet_ping());
    end
    %disp("tic " + string(clk) + " ---------------");
    pkt = read(t);
    if isempty(pkt)
        %disp("read timeout!");
    else
        disp(to_hex(pkt));
    end
end

disp("mqtt connection closed!");
% #------------ the end --------------


function hx = to_hex(raw)
    %raw: uint8 vector 
    chars_hx = dec2hex(raw);
    cell_hx = cellstr(chars_hx);
    hx = strjoin(cell_hx,' ');
end

function pkt = make_packet_conn(client_id, username, password)
    
    bUTF8ClientId = unicode2native(client_id,'utf-8');
    bUTF8Username = unicode2native(username,'utf-8');
    bUTF8Password = unicode2native(password,'utf-8');

    %// "mqtt" + version + flag + keep_alive + client_id + username + password + strlen_header
    remLen = 6 + 1 + 1 + 2 + length(bUTF8ClientId) + length(bUTF8Username) + length(bUTF8Password) + 6;

    bPacket = zeros(remLen + 2, 1, 'uint8');

    bPacket(0 + 1) = hex2dec("10"); %  0x10
    bPacket(1 + 1) = remLen; %// only small packet is supported for now (less than 127)

    bPacket(2 + 1) = hex2dec("00"); % 0x00
    bPacket(3 + 1) = hex2dec("04"); % 0x04
    bPacket(4 + 1) = 'M';
    bPacket(5 + 1) = 'Q';
    bPacket(6 + 1) = 'T';
    bPacket(7 + 1) = 'T';

    bPacket(8 + 1) = hex2dec("04"); % 0x04; %// version -> mqtt v3.1.1
    bPacket(9 + 1) = hex2dec("C2"); % 0xC2; %// username_flag   password_flag  clean_session_flag

    bPacket(10 + 1) = hex2dec("00"); % 0x00;
    bPacket(11 + 1) = hex2dec("3C"); % 0x3C;  %// keep_alive 60 sec

    bPacket(12 + 1) = idivide(length(bUbUTF8ClientIdTF8),int32(256));
    bPacket(13 + 1) = mod(length(bUbUTF8ClientIdTF8) , int32(256));
    offset = 14;
    for k = 1:length(bUTF8ClientId)
        bPacket(offset + k) = bUTF8ClientId(k);
    end

    bPacket(offset + k + 0) = idivide(length(bUTF8Username),int32(256));
    bPacket(offset + k + 1) = mod(length(bUTF8Username) , int32(256));
    offset = offset + k + 1; %  offset + k + 2;
    for k = 1:length(bUTF8Username)
        bPacket(offset + k) = bUTF8Username(k);
    end

    bPacket(offset + k + 0) = idivide(length(bUTF8Password),int32(256));
    bPacket(offset + k + 1) = mod(length(bUTF8Password) , int32(256));
    offset = offset + k + 1; %  offset + k + 2;
    for k = 1:length(bUTF8Password)
        bPacket(offset + k) = bUTF8Password(k);
    end   
    pkt = bPacket;
end

function pkt = make_packet_conn_without_password(client_id)

    bUTF8 =  unicode2native(client_id,'utf-8');
    remLen = 6 + 1 + 1 + 2 + length(bUTF8) + 2;

    bPacket = zeros(remLen + 2, 1, 'uint8');

    bPacket(0 + 1) = hex2dec("10"); % 0x10
    bPacket(1 + 1) = remLen; %// only small packet is supported for now (less than 127)

    bPacket(2 + 1) = hex2dec("00"); % 0x00
    bPacket(3 + 1) = hex2dec("04"); % 0x04
    bPacket(4 + 1) = 'M';
    bPacket(5 + 1) = 'Q';
    bPacket(6 + 1) = 'T';
    bPacket(7 + 1) = 'T';

    bPacket(8 + 1) = hex2dec("04"); % 0x04 %// version -> mqtt v3.1.1
    bPacket(9 + 1) = hex2dec("02"); % 0x02 %// username_flag =0   password_flag =0  clean_session_flag

    bPacket(10 + 1) = hex2dec("00"); % 0x00
    bPacket(11 + 1) = hex2dec("3c"); % 0x3C %// keep_alive 60 sec

    bPacket(12 + 1) = idivide(length(bUTF8),int32(256));
    bPacket(13 + 1) = mod(length(bUTF8) , int32(256));
    offset = 14;
    for k = 1:length(bUTF8)
        bPacket(offset + k) = bUTF8(k);
    end
    pkt = bPacket;
end


function pkt = make_packet_pub_qos0(topic, payload)

    bUTF8Topic = unicode2native(topic,'utf-8');
    bUTF8Payload = unicode2native(payload,'utf-8');

    remLen = 2 + length(bUTF8Topic) + length(bUTF8Payload);

    bPacket = zeros(remLen + 2, 1, 'uint8');

    bPacket(0 + 1) = hex2dec("30"); % 0x30
    bPacket(1 + 1) = remLen; %// only small packet is supported for now (less than 127)

    bPacket(2 + 1) = hex2dec("00"); % 0x00
    bPacket(3 + 1) = length(bUTF8Topic);

    offset = 4;
    for k = 1:length(bUTF8Topic)
        bPacket(offset + k) = bUTF8Topic(k);
    end
    offset = 4 + length(bUTF8Topic);
    for k = 1:length(bUTF8Payload)
        bPacket(offset + k) = bUTF8Payload(k);
    end
    pkt = bPacket;
end

function pkt = make_packet_sub_qos0(packet_id, topic)

    bUTF8Topic = unicode2native(topic,'utf-8');

    %// packet_id + topic_len + topic + qos;
    remLen = 2 + 2 + length(bUTF8Topic) + 1;

    bPacket = zeros(remLen + 2, 1, 'uint8');

    bPacket(0 + 1) = hex2dec("82"); % 0x82
    bPacket(1 + 1) = remLen; %// only small packet is supported for now (less than 127)

    
    bPacket(2 + 1) = idivide(packet_id, int32(256));
    bPacket(3 + 1) =     mod(packet_id, int32(256));

    bPacket(4 + 1) = hex2dec("00"); % 0x00
    bPacket(5 + 1) = length(bUTF8Topic);

    offset = 6;
    for k = 1:length(bUTF8Topic)
        bPacket(offset + k) = bUTF8Topic(k);
    end
    offset = remLen + 2; % remLen + 2 - 1
    bPacket(offset) = hex2dec("00"); %// qos 0
    pkt = bPacket;
end

function pkt = make_packet_unsub_qos0(packet_id, topic)

    bUTF8Topic = unicode2native(topic,'utf-8');

    %// packet_id + topic_len + topic
    remLen = 2 + 2 + length(bUTF8Topic);

    bPacket = zeros(remLen + 2, 1, 'uint8');

    bPacket(0) = hex2dec("A2"); % 0xA2
    bPacket(1) = remLen; %// only small packet is supported for now (less than 127)

    bPacket(2) = idivide(packet_id, int32(256));
    bPacket(3) =     mod(packet_id, int32(256));

    bPacket(4) = hex2dec("00"); % 0x00
    bPacket(5) = length(bUTF8Topic);

    offset = 6;
    for k = 1:length(bUTF8Topic)
        bPacket(offset + k) = bUTF8Topic(k);
    end
    pkt = bPacket;
end

function pkt = make_packet_ping()
    bPacket = zeros(2, 1, 'uint8');
    bPacket(0 + 1) = hex2dec("C0"); %  0xC0
    bPacket(1 + 1) = hex2dec("00"); %  0x00
    pkt = bPacket;
end

function pkt = make_packet_disconn()
    bPacket = zeros(2, 1, 'uint8');
    bPacket(0 + 1) = hex2dec("E0"); %  0xE0
    bPacket(1 + 1) = hex2dec("00"); %  0x00
    pkt = bPacket;
end