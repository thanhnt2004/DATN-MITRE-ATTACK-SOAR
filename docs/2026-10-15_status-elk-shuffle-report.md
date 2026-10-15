# Trạng thái ELK, Shuffle và luồng log — 15/10/2026

Kiểm tra từ khoảng 14:08 đến 14:27 ICT trên EC2 và các VM lab. Đây là ảnh chụp trạng thái tại thời điểm kiểm tra, **không phải xác nhận dịch vụ sẽ luôn ổn định**. Tài liệu công khai này không chứa mật khẩu, khóa SSH, địa chỉ EC2 hoặc thông tin đăng nhập; hồ sơ truy cập đầy đủ được giữ riêng ngoài Git.

## Kết quả

| Thành phần | Kết quả | Cần hoàn tất |
| --- | --- | --- |
| Elasticsearch | API đọc/tìm kiếm hoạt động; cluster `yellow`, một node, không có primary shard chưa gán. | Xem lại replica policy nếu cần `green` hoặc khả năng dự phòng. |
| Kibana | Trạng thái `available`; data view Winlogbeat/Auditbeat có sẵn. | Tạo/kiểm tra data view Ubuntu và kiểm thử detection rule → alert. |
| Logstash | Pipeline `main` `green`; Beats TLS đang nhận sự kiện. | Theo dõi lỗi parsing và độ trễ ingest. |
| Ubuntu Server | Index `datn-ubuntu-2026.10.15` tăng từ 164 lên 2.225, rồi 2.227 bản ghi sau khi bật lại VM. Kết nối Beats còn mở. | Theo dõi thêm trong thời gian dài hơn. |
| pfSense | VM đã bật, nhưng index pfSense chỉ có hai marker thử relay cũ từ Ubuntu; chưa xác nhận syslog pfSense thật. | Kiểm tra remote syslog → Ubuntu relay → Filebeat. |
| Windows 10 | Bật thử khoảng bốn phút, không thấy bản ghi Winlogbeat/Auditbeat mới hoặc kết nối Beats trong cửa sổ thử. | Kiểm tra agent, output TLS, mạng/firewall ngay trong guest; chưa thể kết luận nguyên nhân. |
| Shuffle | Đăng nhập UI và các API nền được; health self-test báo `workflows.run=false`. OpenSearch lỗi mapping `workflow.actions.parameters.value` (`date` → `keyword`); Orborus báo thiếu network `shuffle_swarm_executions` khi Docker Swarm inactive. | Sửa mapping và execution network, sau đó chạy thử một workflow thật. Hiện **chưa xác nhận SOAR hoạt động ổn định**. |

VMware host thiếu dư địa RAM khi chạy đồng thời nhiều guest: Windows đã được tắt mềm sau phép thử. Cuối phiên, pfSense và Ubuntu Server đang bật. Các nguồn Windows/Auditbeat cũ trong Elasticsearch không chứng minh còn gửi log ở ngày kiểm tra.

## Evidence → Finding → Path

| Evidence | Quan sát có thể kiểm lại từ EC2 hoặc lab | Finding |
| --- | --- | --- |
| E-01 | Elasticsearch `_cluster/health`: `yellow`, một node, 0 primary chưa gán; Kibana `/api/status`: `available`. | F-01: ELK lõi hoạt động, nhưng chưa có bằng chứng dự phòng replica hay cảnh báo đầu-cuối. |
| E-02 | Logstash `/_node/stats/pipelines/main`: 2.227 sự kiện vào/ra và một kết nối Beats lúc 14:26:55; Elasticsearch `datn-ubuntu-2026.10.15/_count`: 2.227. | F-02: Tuyến ingest Ubuntu hoạt động trong phép thử. |
| E-03 | Index pfSense không tăng ngoài hai marker relay; data stream Winlogbeat/Auditbeat không tăng khi Windows bật. | F-03: Chưa có bằng chứng log pfSense thật hoặc Windows mới. |
| E-04 | Shuffle health self-test `workflows.run=false` với lỗi mapping; log Orborus thiếu network execution; UI đăng nhập được nhưng chưa có workflow chạy. | F-04: Đăng nhập/health nền thành công không đồng nghĩa workflow chạy được. |

P-01 — Đường log đã xác nhận: Ubuntu Filebeat → Logstash Beats/TLS → Elasticsearch `datn-ubuntu-*` → Kibana. E-02 xác nhận phần ingest; bước hiển thị dashboard và phát hiện/cảnh báo còn phải kiểm thử. Đường pfSense dự kiến: pfSense syslog → rsyslog Ubuntu → Filebeat → Logstash → `datn-pfsense-*`; E-03 cho thấy đường này **chưa được xác nhận với log thật**. Đường SOAR dự kiến: Elastic alert/webhook → Shuffle workflow → hành động phản hồi; E-04 chặn xác nhận đường này.

## Bước tiếp theo

1. Khắc phục mapping/index Shuffle và network execution, chạy workflow mẫu rồi đối chiếu kết quả thực thi.
2. Kiểm tra dịch vụ Beats trong Windows guest, tạo sự kiện thử và xác nhận bộ đếm index tăng.
3. Kiểm tra cấu hình remote logging pfSense, đường UDP đến Ubuntu relay và bản ghi nguồn pfSense thật.
4. Rà soát giới hạn truy cập, xác thực/TLS cho các UI/API; kiểm thử detection rule → alert → Shuffle sau khi ingest ổn định.

Phép kiểm tra dùng Docker/API nội bộ EC2, VMware `vmrun` và UI Shuffle qua SSH tunnel; không thay đổi cấu hình EC2. Xem [hướng dẫn ingest Ubuntu/pfSense](2026-10-13-ubuntu-pfsense-log-ingestion.md) và [báo cáo hạ tầng trước đó](2026-10-13-infrastructure-audit.md) để đối chiếu cấu hình gốc.
