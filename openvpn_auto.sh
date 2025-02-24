#!/bin/bash

# Логирование
LOG_FILE="/var/log/setup_openvpn.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Начало настройки OpenVPN..."

# Установка OpenVPN
echo "Установка OpenVPN..."
sudo apt-get update
sudo apt-get install -y openvpn iptables

# Настройка фаервола с использованием iptables
echo "Настройка фаервола..."
# Сброс всех правил (очистка текущих правил)
iptables -F
iptables -X

# Разрешение всех исходящих соединений
iptables -P OUTPUT ACCEPT

# Разрешение loopback-интерфейса
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Разрешение установленных соединений
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Разрешение SSH (порт 22)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Разрешение портов для сервисов
# OpenVPN (порт 1194 UDP)
iptables -A INPUT -p udp --dport 1194 -j ACCEPT

# Node Exporter (порт 9100 TCP)
iptables -A INPUT -p tcp --dport 9100 -j ACCEPT

# Блокировка всех остальных входящих соединений
iptables -A INPUT -j DROP

#Логирование заблокированных пакетов
iptables -A INPUT -j LOG --log-prefix "Blocked: "

# Сохранение правил iptables
echo "Сохранение правил iptables..."
sudo iptables-save | sudo tee /etc/iptables/rules.v4

# Проверка наличия сертификатов
echo "Проверка наличия сертификатов..."
if [[ ! -f ~/certs/ca.crt || ! -f ~/certs/server.crt || ! -f ~/certs/server.key ]]; then
  echo "Ошибка: Сертификаты не найдены. Скопируйте их с удостоверяющего центра."
  exit 1
fi

# Копирование сертификатов
echo "Копирование сертификатов..."
sudo cp ~/certs/{ca.crt,server.crt,server.key} /etc/openvpn/server/

# Настройка конфигурации OpenVPN
echo "Настройка конфигурации OpenVPN..."
cat <<EOF | sudo tee /etc/openvpn/server/server.conf
port 1194
proto udp
dev tun
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh none
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
tls-crypt /etc/openvpn/server/ta.key
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn-status.log
verb 3
EOF

# Включение и запуск OpenVPN
echo "Запуск OpenVPN..."
sudo systemctl enable openvpn@server
sudo systemctl start openvpn@server

echo "OpenVPN сервер настроен и запущен."
