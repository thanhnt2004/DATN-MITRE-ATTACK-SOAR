# Rà soát hạ tầng DATN ngày 13/10/2026

## Phạm vi

- pfSense và Ubuntu Server trong VMware lab.
- EC2 ELK tại `18.139.50.205`.
- Docker Compose, Elasticsearch, Logstash và Kibana 9.5.4.
- Filebeat, rsyslog, Nginx và ứng dụng Flaskr.
- Cấu hình, script và backup liên quan trong GitHub.

## Kết luận nhanh

- EC2 và ba container ELK đang hoạt động.
- Logstash ở trạng thái `green`, có một kết nối Filebeat, queue bằng 0.
- Ubuntu đã nhận lại `192.168.10.103`, gateway pfSense `192.168.10.1`; web trả HTTP 200.
- Filebeat kết nối Logstash bằng TLS 1.3 và log Ubuntu tiếp tục vào index ngày 13/10.
- pfSense WebGUI hoạt động nhưng chưa có log firewall thật; `datn-pfsense-*` vẫn chỉ có hai marker thử.
- Elasticsearch `yellow` do hệ thống một node không thể phân bổ replica; không có primary shard bị mất.
- Cấu hình đang chạy và các script tái triển khai đã được đồng bộ lên GitHub.
- GitHub không phải nơi lưu VM disk, Elasticsearch data volume, private key hoặc log thô.

## Trạng thái chi tiết

| Thành phần | Trạng thái | Bằng chứng chính |
|---|---|---|
| pfSense VM | Đang chạy | Cấp DHCP `192.168.10.103`, gateway `192.168.10.1`, WebGUI HTTP 200 |
| Ubuntu Server | Hoạt động | Filebeat, rsyslog, Nginx và Flaskr đều active/enabled |
| Filebeat | Hoạt động | Config OK, TLS 1.3, Logstash talk-to-server OK |
| Web server | Hoạt động | Nginx lắng nghe cổng 80, HTTP 200 |
| Logstash | Green | `2368 in = 2368 out`, queue 0, current connection 1 |
| Elasticsearch | Yellow | 58 primary shard hoạt động, không có unassigned primary |
| Kibana | Hoạt động | Container chạy và cổng 5601 reachable |
| Docker Compose | Hợp lệ | `docker compose config -q` trả về thành công |
| Dữ liệu Ubuntu | Có dữ liệu mới | `datn-ubuntu-2026.10.13` có bản ghi từ `prod-web-01` |
| Dữ liệu pfSense | Chưa hoàn tất | Chỉ có hai marker thử ngày 09/10 |

## Cấu hình Docker

- Ba container dùng restart policy `unless-stopped`.
- Không container nào chạy `privileged`.
- Elasticsearch dùng named volume `elk_elasticsearch-data`.
- Logstash mount pipeline và chứng chỉ từ host.
- EC2 còn khoảng 58 GB dung lượng trống.
- Docker image có khoảng 5,9 GB có thể thu hồi, nhưng chưa xóa để tránh ảnh hưởng rollback.

## Phát hiện

### F-001 — Nguồn Ubuntu hoạt động trở lại

- Mức độ: thông tin.
- Bằng chứng: E-001, E-002, E-003.
- Kết luận: chuỗi Ubuntu → Filebeat → TLS 5044 → Logstash → Elasticsearch hoạt động.

### F-002 — Log thật từ pfSense chưa được gửi

- Mức độ: trung bình.
- Bằng chứng: E-004.
- Kết luận: relay UDP 5514 đã được kiểm thử, nhưng file `/var/log/pfsense.log` chỉ có marker do Ubuntu tạo.
- Khắc phục: bật Remote Logging trên pfSense đến `192.168.10.103:5514`.

### F-003 — Elasticsearch/Kibana chưa bật Elastic Security

- Mức độ: cao nếu Security Group mở rộng.
- Bằng chứng: E-005, E-006.
- Kết luận: `xpack.security.enabled=false`; cổng 5601 và 5044 reachable từ mạng kiểm tra. EC2 UFW đang inactive.
- Khắc phục: giới hạn Security Group theo IP nguồn `/32`, bật Elastic Security trước khi mở rộng phạm vi truy cập.

### F-004 — Chưa có backup dữ liệu vận hành được xác minh

- Mức độ: trung bình.
- Bằng chứng: E-007.
- Kết luận: GitHub đã lưu cấu hình, nhưng chưa xác minh EBS snapshot, Elasticsearch snapshot hoặc backup VM disk.
- Khắc phục: tạo EBS snapshot; cấu hình Elasticsearch snapshot repository; lưu VMware snapshot/export ở kho riêng.

### F-005 — Nguy cơ trùng log sau khi VM tắt đột ngột

- Mức độ: thấp.
- Bằng chứng: E-003.
- Kết luận: sau lần boot, Filebeat đọc lại hơn 2.300 sự kiện. Registry từng báo lỗi sau khi VM bị tắt đột ngột.
- Khắc phục: shutdown VM đúng quy trình và theo dõi registry/duplicate events.

## Evidence

| ID | Quan sát |
|---|---|
| E-001 | Ubuntu có IPv4 `192.168.10.103/24`, route mặc định qua `192.168.10.1` |
| E-002 | `filebeat test output` xác nhận TLS 1.3 và Logstash OK |
| E-003 | Logstash `green`, `2368 in/out`, queue 0 và một kết nối |
| E-004 | `/var/log/pfsense.log` và index pfSense chỉ có hai marker thử |
| E-005 | Compose đặt `xpack.security.enabled: false` |
| E-006 | EC2 lắng nghe 22/5044/5601/9200/9600; 22/5044/5601 reachable từ mạng kiểm tra |
| E-007 | Backup hiện có chỉ gồm cấu hình cũ trên EC2/Ubuntu; chưa có bằng chứng snapshot dữ liệu |
| E-008 | Quét repository không phát hiện private key, PEM, token hoặc secret bị track |

## Path dữ liệu

1. Ubuntu ghi system/auth/Nginx log.
2. Filebeat đọc file và gắn `fields.log_source=ubuntu`.
3. Filebeat xác thực CA rồi gửi qua TLS/TCP 5044.
4. Logstash phân loại và ghi vào `datn-ubuntu-*`.
5. Kibana đọc dữ liệu từ Elasticsearch.
6. Với pfSense, bước đầu phải là pfSense → UDP 5514 → rsyslog → `/var/log/pfsense.log`; bước này chưa có log thật.

## Thay đổi đã đồng bộ lên GitHub

- `elk/docker-compose.yml`: mount chứng chỉ Logstash.
- `elk/logstash/pipeline/logstash.conf`: TLS 5044 và định tuyến theo nguồn.
- `elk/filebeat/filebeat.yml`: bản cấu hình Filebeat đang dùng.
- `elk/rsyslog/30-pfsense.conf`: cấu hình relay pfSense.
- `scripts/configure-ec2-logstash.sh`: script triển khai Logstash TLS.
- `scripts/configure-ubuntu-ingest.sh`: script triển khai Filebeat/rsyslog.

Không đưa lên GitHub: SSH private key, CA/private server key, VM disk, Elasticsearch data volume, log thô, HTML phiên đăng nhập và credential.
