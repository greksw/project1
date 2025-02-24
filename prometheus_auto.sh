#!/bin/bash

# Логирование
LOG_FILE="/var/log/setup_prometheus.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Начало настройки Prometheus..."

# Установка Prometheus и экспортёров
echo "Установка Prometheus и экспортёров..."
sudo apt-get update
sudo apt-get install -y prometheus node-exporter alertmanager iptables

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
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Prometheus (порт 9090 TCP)
sudo iptables -A INPUT -p tcp --dport 9090 -j ACCEPT

# Node Exporter (порт 9100 TCP)
sudo iptables -A INPUT -p tcp --dport 9100 -j ACCEPT

# Блокировать все остальные входящие соединения
sudo iptables -A INPUT -j DROP

#Логирование заблокированных пакетов
iptables -A INPUT -j LOG --log-prefix "Blocked: "

# Сохранение правил iptables
echo "Сохранение правил iptables..."
sudo iptables-save | sudo tee /etc/iptables/rules.v4

# Настройка конфигурации Prometheus
echo "Настройка конфигурации Prometheus..."
cat <<EOF | sudo tee /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
  - job_name: 'openvpn'
    static_configs:
      - targets: ['vpn_server:9115']
EOF

# Настройка алертов
echo "Настройка алертов..."
cat <<EOF | sudo tee /etc/prometheus/alert.rules.yml
groups:
- name: example
  rules:
  - alert: HighMemoryUsage
    expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100 < 10
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High memory usage on {{ $labels.instance }}"
      description: "Memory usage is above 90% for 5 minutes."
  - alert: OpenVPNDown
    expr: up{job="openvpn"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "OpenVPN is down on {{ $labels.instance }}"
      description: "OpenVPN service is not running."
EOF

# Настройка Alertmanager
echo "Настройка Alertmanager..."
cat <<EOF | sudo tee /etc/alertmanager/alertmanager.yml
route:
  receiver: 'email-notifications'

receivers:
- name: 'email-notifications'
  email_configs:
  - to: 'your-email@example.com'
    from: 'alertmanager@example.com'
    smarthost: 'smtp.example.com:587'
    auth_username: 'your-email@example.com'
    auth_password: 'your-password'
EOF

# Включение и запуск сервисов
echo "Запуск сервисов..."
sudo systemctl enable prometheus alertmanager node-exporter
sudo systemctl start prometheus alertmanager node-exporter

echo "Prometheus настроен и запущен. Алерты и экспортёры настроены."
