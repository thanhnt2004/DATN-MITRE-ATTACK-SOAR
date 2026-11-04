# Triển khai tổng thể từ đầu đến cuối

## 1. Chuẩn bị

1. Xác nhận phạm vi lab, quyền truy cập VMware/AWS và backup; kiểm tra RAM, disk và trạng thái snapshot. Tránh chạy toàn bộ VM nặng cùng lúc trên host 16 GiB.
2. Xác định đúng repository `D:\DATN\github\DATN-MITRE-ATTACK-SOAR-update`, tài liệu `D:\DATN\docs`, credential riêng `D:\DATN\private`, SSH key `D:\DATN\SSH-server-ec2`. Không đưa private lên Git.
3. Kiểm tra IP EC2 thực tế, Security Group, DNS và đường ra của lab. Lưu CA/certificate an toàn; thiết lập password và API key theo môi trường, không sao chép mặc định từ báo cáo.

## 2. Thứ tự thực hiện

| Bước | Việc cần làm | Điều kiện chuyển bước | Tài liệu |
|---|---|---|---|
| 1 | Thiết lập VMnet10, NAT, khởi động pfSense và guest | endpoint có IP, gateway và DNS đúng | [VMware và endpoint](chi-tiet/01-vmware-pfsense-endpoint.md) |
| 2 | Chuẩn bị EC2, Docker, ELK và Shuffle | Elasticsearch healthy; Logstash, Kibana, Shuffle phản hồi | [EC2/ELK](chi-tiet/02-ec2-elk-shuffle.md) |
| 3 | Cấu hình rsyslog/Filebeat, Winlogbeat/Sysmon, Packetbeat theo playbook | event mới vào đúng index qua TLS | [agent](chi-tiet/01-vmware-pfsense-endpoint.md) |
| 4 | Tạo API key chỉ đọc, detector, timer, Shuffle webhook | timer active; không có lỗi chứng thực | [detection](chi-tiet/03-detection-soar-nghiem-thu.md) |
| 5 | Chạy Atomic có kiểm soát trong lab | đối chiếu source event, document ID, detection và execution | [năm báo cáo gốc](MD%20Playbook/) |
| 6 | Thử phản ứng, khôi phục và ghi evidence | trạng thái sau hành động và rollback được xác minh | [T1105](MD%20Playbook/2026-11-04_t1105-cai-dat-kiem-thu-quarantine.md) |

## 3. Kiểm tra sau triển khai

- Trên EC2: `docker ps`, `systemctl is-active datn-pb01.timer datn-pb04.timer datn-t1059.timer datn-t1105.timer`; xem journal khi service lỗi. Không kết luận detector hoạt động chỉ vì timer active.
- Trên Windows: `Get-Service Sysmon64,winlogbeat`; thử config/output Winlogbeat; trong Kibana kiểm tra document mới đúng channel và timestamp.
- Trên Kali: `systemctl is-active packetbeat`; kiểm tra output TLS. Trên Ubuntu: kiểm tra rsyslog/Filebeat, syslog và listener 5514.
- Đối chiếu ít nhất nguồn event → index → detection → execution → hành động → trạng thái sau hành động. Test fixture và webhook thủ công không chứng minh tự động đầu cuối.

## 4. Bảo trì và khôi phục

Giữ bản sao cấu hình, version, quyền file, certificate, state và danh sách API key theo [quy trình backup](chi-tiet/04-bao-ve-tai-lieu-va-backup.md). Thử rollback trên bản lab trước. Khi một dịch vụ hoặc host khởi động lại, kiểm tra timer, responder và nguồn telemetry thay vì giả định chúng tự phục hồi.
