# EC2, ELK và Shuffle

## Hạ tầng và khởi tạo

EC2 Ubuntu từng được truy cập bằng user `ubuntu` và SSH key lưu trong `D:\DATN\SSH-server-ec2`. Kiểm tra public IP, instance status và Security Group trong AWS trước khi kết nối. Key, password và token chỉ lưu private. Docker chạy ELK 9.5.4; Elasticsearch live dùng security/TLS. Shuffle chạy riêng với backend/frontend và OpenSearch; không ghi đè các volume hoặc compose đang chạy.

Script `scripts/setup-host.sh` là tham khảo cho Docker/swap và kernel; kiểm tra nội dung và backup trước khi chạy trên host đang vận hành. Repository `elk/docker-compose.yml` là **mẫu cũ có security=false**, không phản ánh EC2 đã bật security. Muốn dựng mới với security/TLS phải chuẩn bị compose, tài khoản dịch vụ và CA hợp lệ từ cấu hình runtime đã backup; chưa có bộ compose TLS được kiểm chứng đầy đủ trong repo. Không dùng mẫu cũ làm cấu hình production.

Snapshot tham khảo đã loại secret của cấu hình EC2 live được lưu trong repository tại `elk/docker-compose.tls-reference.yml`. File thay các mật khẩu và ba encryption key bằng biến môi trường; chứng chỉ, private key, tài khoản dịch vụ và pipeline TLS live không nằm trong repo. Snapshot này chưa được triển khai mới hoặc xác minh khôi phục từ máy trống; không tự coi là bộ cài hoàn chỉnh. Healthcheck gốc dùng `curl -sk` để đọc mã HTTP, do đó không chứng minh CA hợp lệ.

## Truy cập và kiểm tra

```bash
docker ps
curl -fsS http://127.0.0.1:9600/_node/pipelines
systemctl is-active datn-pb01.timer datn-pb04.timer datn-t1059.timer datn-t1105.timer
```

Elasticsearch HTTPS dùng CA runtime `/opt/elk/elasticsearch/certs/ca/ca.crt`. Beats xác thực CA của Logstash tại `/opt/elk/logstash/certs/ca.crt`. Truy vấn bằng API key ít quyền; không đặt secret trong câu lệnh lưu lịch sử hoặc tài liệu. Dùng Kibana Discover/index pattern và xác nhận timestamp, host, source, event ID cũng như quyền search shard.

## Logstash

Pipeline live `/opt/elk/logstash/pipeline/logstash.conf` nhận Beats TLS TCP 5044, định tuyến theo `fields.log_source`: Ubuntu → `datn-ubuntu-*`, pfSense → `datn-pfsense-*`, Windows → `datn-windows-*`, PB04 → `datn-dns-*`. Output Elasticsearch live qua HTTPS. File `elk/logstash/pipeline/logstash.conf` trong repo là template khác/stale, không copy nguyên đè live.

PB04 có script `scripts/pb04-patch-live-logstash.py` chỉ thêm route tại anchor xác định và đặt backup `/opt/elk/logstash/logstash.conf.pre-pb04` ngoài thư mục pipeline. Logstash có thể đọc nhiều file trong thư mục pipeline; không đặt backup cấu hình vào đó. Sau sửa, xác nhận pipeline đã start và Beats test output.

## Shuffle và cảnh báo

Workflow đã triển khai có ID/trigger trong báo cáo playbook. Các script tạo workflow dùng action Telegram sẵn có; raw export/execution có thể chứa bot token. Không commit raw workflow, token hoặc `.env`; quản lý secret phù hợp và hạn chế truy cập. Detector lưu API key giới hạn tại `/opt/datn-pb01/`, `/opt/datn-pb04/`, `/opt/datn-t1059/`, `/opt/datn-t1105/`; `*.env` và state là dữ liệu riêng runtime.

Khi webhook trả HTTP 200, kiểm tra thêm workflow execution `FINISHED`, action `SUCCESS`, Telegram `ok=true`. Với T1105, đọc nhật ký responder và kiểm tra file tại guest; Telegram đầu tiên có trạng thái pending, không chứng minh quarantine.

## Sự cố thường gặp

- SSH/5044/3001 timeout: kiểm tra public IP, status checks, Security Group, route, firewall và dịch vụ. Tránh mở rộng ingress đại trà.
- Shuffle 502 sau khởi động: chờ backend/OpenSearch sẵn sàng, kiểm tra container/journal và thử lại.
- Logstash không chạy: xem pipeline API/log, config syntax và file backup trùng trong thư mục pipeline.
- Detector 401 hoặc 0 shard: kiểm tra thời gian khởi động Elastic, API key, CA, index và quyền. Không thay bằng tài khoản toàn quyền thường trực.
