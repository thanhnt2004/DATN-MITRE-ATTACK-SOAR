# Cài đặt Docker và ELK cho DATN

Baseline server:
- AWS EC2 `m7i-flex.large`
- Ubuntu 24.04.4 LTS
- 2 vCPU
- ~8 GiB RAM
- 80 GB EBS
- Swap mục tiêu: 4 GiB
- Timezone: Asia/Ho_Chi_Minh

## 1. Clone repository

```bash
git clone https://github.com/thanhnt2004/DATN-MITRE-ATTACK-SOAR.git
cd DATN-MITRE-ATTACK-SOAR
```

Không commit SSH private key, AWS credential, password, token hoặc file `.env`.

## 2. Chuẩn hóa host

Script `scripts/setup-host.sh` thực hiện:
- cài package cơ bản;
- tạo 4 GiB swap nếu chưa có;
- đặt `vm.swappiness=10`;
- đặt `vm.max_map_count=1048576`;
- cài Docker Engine + Docker Compose plugin;
- bật Docker khi boot;
- giới hạn Docker JSON logs;
- thêm user hiện tại vào group `docker`.

Chạy:

```bash
chmod +x scripts/setup-host.sh
./scripts/setup-host.sh
```

Sau khi script hoàn tất, logout/login lại trước khi dùng Docker không cần `sudo`.

Kiểm tra:

```bash
free -h
swapon --show
sysctl vm.swappiness
sysctl vm.max_map_count
docker --version
docker compose version
```

Giá trị mong muốn:

```text
Swap: ~4 GiB
vm.swappiness = 10
vm.max_map_count = 1048576
```

## 3. ELK baseline

Stack hiện tại:
- Elasticsearch 9.5.4
- Kibana 9.5.4
- Logstash 9.5.4

Cấu hình:
- Elasticsearch JVM heap: 2 GiB
- Elasticsearch container limit: 3 GiB
- Kibana container limit: 1200 MiB
- Logstash JVM heap: 512 MiB
- Logstash container limit: 1 GiB

Elasticsearch chỉ bind localhost:

```text
127.0.0.1:9200
```

Kibana:

```text
0.0.0.0:5601
```

Logstash Beats input:

```text
0.0.0.0:5044
```

Logstash API chỉ bind localhost:

```text
127.0.0.1:9600
```

## 4. Tải image

```bash
cd elk
docker compose config
docker compose pull
```

## 5. Khởi động ELK

```bash
docker compose up -d
```

Kiểm tra:

```bash
docker compose ps
docker stats --no-stream
free -h
```

## 6. Kiểm tra Elasticsearch

```bash
curl http://localhost:9200
curl http://localhost:9200/_cluster/health?pretty
```

## 7. Kiểm tra Kibana

```bash
docker logs datn-kibana --tail 100
```

Truy cập:

```text
http://<EC2_PUBLIC_IP>:5601
```

Không hard-code Public IP vào repository vì địa chỉ có thể thay đổi sau stop/start nếu không dùng Elastic IP.

## 8. AWS Security Group

Baseline đề xuất:

| Port | Service | Source |
|---:|---|---|
| 22/TCP | SSH | IP quản trị |
| 5601/TCP | Kibana | IP quản trị |
| 5044/TCP | Beats -> Logstash | IP endpoint/lab |
| 9200/TCP | Elasticsearch | Không public |
| 9600/TCP | Logstash API | Không public |

Không mở Elasticsearch `9200` ra `0.0.0.0/0`.

## 9. Logstash pipeline

File:

```text
elk/logstash/pipeline/logstash.conf
```

Luồng ban đầu:

```text
Winlogbeat / Filebeat
        |
        v
Logstash :5044
        |
        v
Elasticsearch
        |
        v
Kibana
```

Index mặc định:

```text
datn-YYYY.MM.dd
```

Pipeline sẽ được cập nhật khi triển khai Sysmon, Windows Event Log và Linux telemetry.

## 10. Lệnh vận hành thường dùng

Start:

```bash
cd elk
docker compose up -d
```

Stop:

```bash
docker compose down
```

Xem log:

```bash
docker compose logs -f
```

Xem riêng Elasticsearch:

```bash
docker logs datn-elasticsearch --tail 100
```

Xem riêng Kibana:

```bash
docker logs datn-kibana --tail 100
```

Xem riêng Logstash:

```bash
docker logs datn-logstash --tail 100
```

## 11. Lưu ý security

Baseline hiện tắt Elastic security:

```yaml
xpack.security.enabled: "false"
```

Mục đích là làm lab ban đầu cho luồng ingest và detection. Không dùng cấu hình này như production và không public Elasticsearch.

Khi tích hợp Shuffle SOAR, security/authentication sẽ được bật và secret sẽ được lưu ngoài Git.
