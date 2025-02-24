Автоматизация развёртывания сервера
Вы можете развернуть этот сервер, используя наши инструменты автоматизации.

Используйте этот запрос, чтобы автоматизировать создание сервера с вашими настройками.

curl -X POST \
https://api.serverspace.ru/api/v1/servers \
-H 'content-type: application/json' \
-H 'x-api-key: <ваш API-ключ>' \
-d '{
  "location_id": "ds1",
  "cpu": 1,
  "ram_mb": 1024,
  "image_id": "Ubuntu-24.04.2-X64",
  "name": "ovpn-01",
  "networks": [
    {
      "bandwidth_mbps": 50
    }
  ],
  "volumes": [
    {
      "name": "boot",
      "size_mb": 25600
    }
  ],
  "ssh_key_ids": [
    17455
  ]
}'
