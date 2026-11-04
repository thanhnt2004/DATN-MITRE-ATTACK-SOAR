# Tài liệu triển khai và vận hành DATN

Điểm bắt đầu cho lab phát hiện và ứng phó MITRE ATT&CK. Kiểm kê và đối chiếu ngày 04/11/2026; địa chỉ, phiên bản và trạng thái có thể thay đổi. Tài liệu mô tả hệ thống lab thực tế cùng các bước tái tạo; kiểm tra cấu hình đang chạy trước khi áp dụng.

## Đọc theo thứ tự

1. [Kiến trúc và sơ đồ mạng](01-kien-truc-va-mang.md): thành phần, đường đi telemetry và giới hạn.
2. [Hướng dẫn triển khai tổng thể](02-trien-khai-tong-the.md): trình tự cài đặt từ host đến kiểm thử.
3. [VMware, pfSense và endpoint](chi-tiet/01-vmware-pfsense-endpoint.md): topology, guest, agent và cách xác minh.
4. [EC2, ELK và Shuffle](chi-tiet/02-ec2-elk-shuffle.md): các dịch vụ, chứng chỉ, định tuyến log và vận hành.
5. [Detection, SOAR và nghiệm thu](chi-tiet/03-detection-soar-nghiem-thu.md): năm playbook, minh chứng và giới hạn.
6. [Tài liệu quan trọng và sao lưu](chi-tiet/04-bao-ve-tai-lieu-va-backup.md): file được bảo vệ, credential, backup và khôi phục.
7. [Danh mục tài liệu và lịch sử](chi-tiet/05-danh-muc-va-lich-su.md): các báo cáo gốc, bằng chứng và tình trạng trùng lặp.

Năm báo cáo cài đặt/kiểm thử gốc ở [MD Playbook](MD%20Playbook/). File tài khoản tổng hợp được giữ riêng trong `D:\DATN\private\2026-11-04_credentials-master-private.md`; không đưa file này hoặc private key, bot token và `.env` lên Git.

> **Thận trọng khi cài lại:** `elk/docker-compose.yml` và một số README trong repository là bản lịch sử từng tắt Elastic security, còn EC2 đang chạy security/TLS. Không triển khai đè mẫu cũ lên cấu hình live. Trước mọi thay đổi, backup và kiểm tra cấu hình hiện hữu.
