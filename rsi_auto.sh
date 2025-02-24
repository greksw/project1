#!/bin/bash

# Логирование
LOG_FILE="/var/log/setup_pki.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Начало настройки удостоверяющего центра (PKI)..."

# Установка зависимостей
echo "Установка зависимостей..."
sudo apt-get update
sudo apt-get install -y easy-rsa iptables

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

# Разрешение HTTP (порт 80) и HTTPS (порт 443) для доступа к репозиториям
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# Разрешение SSH (порт 22)
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT 

# HTTPS для передачи сертификатов
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT 

# Node Exporter (порт 9100 TCP)
iptables -A INPUT -p tcp --dport 9100 -j ACCEPT

# Блокировать все остальные входящие соединения
sudo iptables -A INPUT -j DROP  

#Логирование заблокированных пакетов
iptables -A INPUT -j LOG --log-prefix "Blocked: "

# Сохранение правил iptables
echo "Сохранение правил iptables..."
sudo iptables-save | sudo tee /etc/iptables/rules.v4

# Создание директории для PKI
echo "Создание директории для PKI..."
mkdir -p ~/easy-rsa
ln -s /usr/share/easy-rsa/* ~/easy-rsa/
cd ~/easy-rsa

# Инициализация PKI
echo "Инициализация PKI..."
./easyrsa init-pki

# Создание корневого сертификата
echo "Создание корневого сертификата..."
./easyrsa build-ca nopass

# Создание сертификата для VPN-сервера
echo "Создание сертификата для VPN-сервера..."
./easyrsa gen-req server nopass
./easyrsa sign-req server server

# Создание клиентского сертификата
echo "Создание клиентского сертификата..."
./easyrsa gen-req client nopass
./easyrsa sign-req client client

# Копирование сертификатов в нужные директории
echo "Копирование сертификатов..."
mkdir -p ~/certs
cp ~/easy-rsa/pki/ca.crt ~/certs/
cp ~/easy-rsa/pki/issued/server.crt ~/certs/
cp ~/easy-rsa/pki/private/server.key ~/certs/
cp ~/easy-rsa/pki/issued/client.crt ~/certs/
cp ~/easy-rsa/pki/private/client.key ~/certs/

# Защита приватных ключей
echo "Защита приватных ключей..."
chmod 600 ~/certs/server.key ~/certs/client.key

echo "Удостоверяющий центр настроен. Сертификаты находятся в ~/certs/"
