# Tiến độ kết nối log Ubuntu và pfSense lên ELK

Ngày cập nhật: 13/10/2026

## Mô hình kết nối

```text
Ubuntu system/auth/Nginx logs
  -> Filebeat 9.5.4
  -> TLS/TCP 5044
  -> Logstash
  -> datn-ubuntu-YYYY.MM.dd

pfSense
  -> Syslog UDP 5514
  -> rsyslog trên Ubuntu
  -> /var/log/pfsense.log
  -> Filebeat
  -> TLS/TCP 5044
  -> Logstash
  -> datn-pfsense-YYYY.MM.dd
```

## Công việc đã hoàn thành

### ELK trên EC2

- Cấu hình Logstash Beats input tại `5044/TCP`.
- Tạo CA và chứng chỉ để mã hóa kết nối Filebeat–Logstash bằng TLS.
- Phân loại log theo `fields.log_source`.
- Tách dữ liệu vào các index `datn-ubuntu-*`, `datn-pfsense-*`, `datn-windows-*` và `datn-other-*`.
- Di chuyển các file backup ra ngoài thư mục pipeline để Logstash chỉ nạp một `logstash.conf`.

Cấu hình input chính:

```logstash
input {
  beats {
    id => "datn-beats-tls"
    port => 5044
    ssl_enabled => true
    ssl_certificate => "/usr/share/logstash/certs/logstash.crt"
    ssl_key => "/usr/share/logstash/certs/logstash.pkcs8.key"
  }
}
```

### Ubuntu Server

- Cài Filebeat 9.5.4.
- Thu thập `/var/log/syslog`, `/var/log/auth.log`, Nginx access/error log và `/var/log/pfsense.log`.
- Cài CA tại `/etc/filebeat/certs/ca.crt`.
- Gửi log đến Logstash tại `18.139.50.205:5044`.
- Bật Filebeat tự khởi động cùng hệ điều hành.
- Nginx và Gunicorn phục vụ ứng dụng web Flaskr/SQLite.

Các lệnh kiểm tra:

```bash
sudo filebeat test config -e
sudo filebeat test output -e
sudo systemctl enable --now filebeat
systemctl is-active filebeat
sudo journalctl -u filebeat -n 60 --no-pager
```

### Relay log pfSense

- Cấu hình rsyslog trên Ubuntu lắng nghe `5514/UDP`.
- Ghi dữ liệu nhận được vào `/var/log/pfsense.log`.
- UFW chỉ cho phép pfSense `192.168.10.1` gửi đến `5514/UDP`.
- Filebeat chuyển tiếp file log này đến Logstash với `fields.log_source: pfsense`.

Các lệnh kiểm tra:

```bash
sudo rsyslogd -N1
sudo systemctl restart rsyslog
systemctl is-active rsyslog
sudo ss -lunp | grep ':5514 '
sudo tail -n 20 /var/log/pfsense.log
```

## Kết quả kiểm thử

- Filebeat kết nối thành công đến Logstash bằng TLS 1.3.
- Log hệ thống Ubuntu và log truy cập Nginx/Gunicorn xuất hiện trong `datn-ubuntu-2026.10.09`.
- Marker thử của relay xuất hiện trong `datn-pfsense-2026.10.09`.
- Bài test năm lượt tạo đủ 15 sự kiện dự kiến: 5 syslog, 5 Nginx và 5 Gunicorn.
- Filebeat ghi nhận `18 added = 18 done = 18 acked`.
- Logstash có trạng thái `green`, `7833 events.in = 7833 events.out`, queue bằng 0 và không có lỗi ERROR/FATAL mới.
- Elasticsearch ở trạng thái `yellow` vì hệ thống chỉ có một node nên replica shard chưa được phân bổ; primary shard vẫn hoạt động.

## Trạng thái nguồn log

| Nguồn | Trạng thái | Ghi chú |
|---|---|---|
| Ubuntu Server | Hoàn thành | Log hệ thống và web đã được xác minh từ nguồn đến Elasticsearch |
| Relay dành cho pfSense | Hoàn thành | UDP 5514, rsyslog, Filebeat và index đích hoạt động |
| Log thật từ pfSense | Chưa hoàn thành | Hiện chỉ có marker thử từ Ubuntu, chưa có bằng chứng sự kiện do pfSense gửi |
| Winlogbeat/Auditbeat của Bình | Đã có dữ liệu | Đang đi trực tiếp vào Elasticsearch 9200 theo ngoại lệ tạm thời; cần kiểm tra lại độ mới |

## Công việc tiếp theo

1. Bật Remote Logging trên pfSense.
2. Đặt Remote Log Server là `192.168.10.103:5514`.
3. Chọn Firewall Events và System Events.
4. Tạo sự kiện trên rule có bật logging.
5. Xác nhận log thật xuất hiện trong `datn-pfsense-*`.
6. Chuẩn hóa các nguồn Windows chuyển qua Logstash thay vì ghi trực tiếp vào Elasticsearch.
7. Xây dựng dashboard và detection rule trên Kibana.

## Lưu ý an toàn

- Không commit mật khẩu, API key, SSH private key, AWS credential hoặc file `.env`.
- Các cổng quản trị và ingest trên Security Group phải giới hạn theo địa chỉ nguồn `/32`.
- Tránh tắt VM đột ngột để giảm nguy cơ Filebeat đọc lại log cũ sau lỗi registry.
