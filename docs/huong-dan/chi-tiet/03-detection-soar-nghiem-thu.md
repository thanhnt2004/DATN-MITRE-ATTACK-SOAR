# Detection, SOAR và nghiệm thu

## Năm playbook

| Playbook | Kiểm thử đã ghi nhận | Trạng thái phản ứng và giới hạn |
|---|---|---|
| T1046 Network Service Scanning | Kali scan giới hạn; log pfSense/Ubuntu; Shuffle và Telegram thành công | báo cáo 31/10 gửi webhook thủ công, chưa chứng minh tự kích hoạt detection |
| PB01 T1110.003 Password Spraying | Atomic lab mở rộng trên Kali, 5 user thất bại SSH trên Ubuntu; timer, Elastic, Shuffle và Telegram | notify-only; bản trong `MD Playbook` là lịch sử, xem bản nghiệm thu PB01 trong repo |
| PB04 T1071.004 DNS | Atomic lab mở rộng, Packetbeat DNS, 30 qname, detector/timer và Telegram; pfSense DNS relay có document | notify-only; `REVIEW_DOMAIN_BLOCK` là đề xuất, không thực thi chặn |
| T1059.001 PowerShell | Atomic upstream test 17 trên Windows, Sysmon Event 1 → timer → Shuffle → Telegram | notify-only; phạm vi encoded command, không bao phủ toàn T1059 |
| T1105 Ingress Tool Transfer | Atomic upstream tải marker, và Atomic DATN mở rộng giữ process để Event 3/11 cùng GUID; timer → Shuffle → responder → quarantine → restore | tự động chỉ với marker/host/IP/hash lab; restore thủ công; host cần đăng nhập |

## Cách nghiệm thu

1. Ghi test ID, giờ UTC, GUID bài Atomic, host nguồn/đích, index và ID event. Dùng marker vô hại và scope rõ ràng.
2. Kiểm tra prerequisite và exit code của Atomic. Xác minh event gốc tại guest, sau đó document tương ứng trong Elasticsearch; không coi fixture là log thật.
3. Kiểm tra timer/detector nhận sự kiện, điều kiện khớp, allowlist và chống lặp. Xem journal, số event và state; test âm tính cùng hành vi bình thường.
4. Kiểm tra Shuffle execution ID, trạng thái, action và kết quả Telegram. Với phản ứng thật, đọc lại trạng thái đối tượng tại hệ thống đích và kiểm tra rollback.
5. Lưu bằng chứng đã che secret và thời gian từ event tới alert/action. Không tuyên bố coverage cho kỹ thuật rộng khi chỉ thử một nhánh.

## Bằng chứng và báo cáo

- [T1046](../MD%20Playbook/2026-10-31_guide-t1046-pfsense-ubuntu-shuffle-report.md): scan và webhook thủ công.
- [PB01 bản lịch sử](../MD%20Playbook/2026-11-03_pb01-t1110-003-install-test-report.md): chưa có credential tại thời điểm viết; bản mới `github/DATN-MITRE-ATTACK-SOAR-update/docs/2026-11-03_pb01-t1110-003-install-test-report.md` có nghiệm thu Atomic thật.
- [PB04](../MD%20Playbook/2026-11-03_pb04-t1071-004-install-test-report.md), [T1059](../MD%20Playbook/2026-11-04_t1059-001-install-test-report.md), [T1105](../MD%20Playbook/2026-11-04_t1105-cai-dat-kiem-thu-quarantine.md).

Một số bản sao báo cáo có liên kết tương đối được viết cho vị trí cũ; dùng đường dẫn repository thật khi liên kết đó không hoạt động. Không sửa năm bản gốc đã được người dùng yêu cầu bảo vệ.

## Chuyển đổi sang môi trường khác

Ngưỡng, CIDR, hash, hostname, timer, retention và hành động được cấu hình theo lab. Cần baseline, false positive/negative, phân trang truy vấn khi tải lớn, quyền tối thiểu, webhook có xác thực/TLS, audit phê duyệt và thử thất bại/khôi phục trước vận hành rộng hơn. Không gửi credential hoặc nội dung nhạy cảm qua Telegram.
