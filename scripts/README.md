# Scripts

Script cài đặt, health-check, backup, maintenance và hỗ trợ lab.

Quy tắc:
- không hard-code credential;
- dùng biến môi trường hoặc file local đã được .gitignore;
- script thay đổi hệ thống phải có mô tả và cách rollback khi phù hợp.

## Ubuntu web server mẫu

- `deploy-flaskr-production.sh`: cài Flaskr từ upstream commit đã pin, Gunicorn, Nginx và systemd.
- `repair-flaskr-service.sh`: sửa working directory/HOME của service rồi restart.
- `collect-flaskr-evidence.sh`: thu trạng thái dịch vụ, HTTP, SQLite và log vào `/tmp/flaskr-evidence.txt`.
- `seed-flaskr-demo.sh`: tạo dữ liệu demo với mật khẩu ngẫu nhiên chỉ tồn tại trong tiến trình.

Ví dụ:

```bash
sudo bash scripts/deploy-flaskr-production.sh
sudo BASE_URL=http://127.0.0.1 bash scripts/seed-flaskr-demo.sh
sudo BASE_URL=http://127.0.0.1 bash scripts/collect-flaskr-evidence.sh
```

## Thu thập log ELK

- `configure-ec2-logstash.sh`: sao lưu cấu hình, tạo TLS certificate và cấu hình Logstash 5044 theo từng nguồn.
- `configure-ubuntu-ingest.sh`: cài Filebeat, cấu hình nguồn Ubuntu/Nginx và rsyslog relay pfSense.

Hai script không chứa credential. Private key và CA private key phải được giữ ngoài Git.
