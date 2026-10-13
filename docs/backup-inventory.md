# Kiểm kê backup và chính sách lưu trữ

Ngày đối chiếu: 13/10/2026

## Đã lưu trên GitHub

| Nội dung | Đường dẫn | Trạng thái |
|---|---|---|
| Docker Compose ELK | `elk/docker-compose.yml` | Đã đồng bộ |
| Logstash TLS pipeline | `elk/logstash/pipeline/logstash.conf` | Đã đồng bộ |
| Filebeat inputs/output | `elk/filebeat/filebeat.yml` | Đã đồng bộ |
| rsyslog relay pfSense | `elk/rsyslog/30-pfsense.conf` | Đã đồng bộ |
| Script cấu hình EC2 | `scripts/configure-ec2-logstash.sh` | Đã đồng bộ |
| Script cấu hình Ubuntu | `scripts/configure-ubuntu-ingest.sh` | Đã đồng bộ |
| Báo cáo tiến độ/kiểm thử | `docs/` | Đã đồng bộ |

Git history đóng vai trò backup phiên bản cho các file cấu hình dạng văn bản. Các file backup `.bak-*` không cần commit riêng nếu nội dung đã có trong lịch sử Git.

## Cố ý không lưu trên GitHub

- SSH private key và AWS credential.
- `ca.key`, `logstash.key`, PKCS#8 private key.
- Mật khẩu, token, cookie, CSRF token và file `.env`.
- Elasticsearch data volume.
- SQLite database có dữ liệu người dùng.
- VMware VMDK, memory snapshot và VM snapshot.
- Log thô, HTML đăng nhập và evidence chưa khử thông tin nhạy cảm.
- Chứng chỉ CA đang vận hành; script có thể tạo lại bộ chứng chỉ mới.

## Backup vận hành còn thiếu hoặc chưa xác minh

| Backup | Trạng thái | Nơi lưu phù hợp |
|---|---|---|
| AWS EBS snapshot | Chưa xác minh | AWS EBS Snapshot |
| Elasticsearch snapshot | Chưa cấu hình/xác minh | S3 snapshot repository |
| VMware pfSense | Chưa xác minh | VMware snapshot hoặc OVF export |
| VMware Ubuntu Server | Chưa xác minh | VMware snapshot hoặc OVF export |
| Flaskr SQLite | Chưa xác minh | File backup mã hóa ngoài Git |
| Kibana saved objects | Chưa xác minh | Export NDJSON, loại bỏ secret |
| Detection rules/Shuffle workflows | Chưa hoàn thiện | Export JSON/YAML đã khử secret |

## Quy tắc trước khi commit

1. Chạy quét secret.
2. Không commit file có đuôi `.pem`, `.key`, `.p12`, `.pfx` hoặc `.env`.
3. Chỉ commit log/evidence đã khử IP nhạy cảm, cookie và credential.
4. Dùng snapshot chuyên dụng cho dữ liệu nhị phân và dữ liệu runtime; không dùng GitHub thay thế backup hệ thống.
