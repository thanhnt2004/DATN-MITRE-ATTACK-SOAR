# Danh mục tài liệu và lịch sử

## Năm tài liệu gốc được bảo vệ

| Playbook | File trong `D:\DATN\docs\MD Playbook` | Trạng thái cần đọc đúng |
|---|---|---|
| T1046 | `2026-10-31_guide-t1046-pfsense-ubuntu-shuffle-report.md` | scan thật; webhook gửi thủ công |
| PB01 | `2026-11-03_pb01-t1110-003-install-test-report.md` | bản lịch sử, có banner dẫn bản nghiệm thu đầy đủ trong repo |
| PB04 | `2026-11-03_pb04-t1071-004-install-test-report.md` | Atomic DNS và timer, notify-only |
| T1059 | `2026-11-04_t1059-001-install-test-report.md` | Atomic PowerShell, notify-only |
| T1105 | `2026-11-04_t1105-cai-dat-kiem-thu-quarantine.md` | marker lab, quarantine giới hạn và restore thủ công |

Các báo cáo ngày 08–31/10 và kế hoạch là lịch sử hữu ích, có thể mô tả trạng thái đã thay đổi. Ưu tiên tài liệu mới và trạng thái live được kiểm tra. Không xóa báo cáo khác chỉ vì cùng chủ đề; chỉ xem trùng khi nội dung giống hệt hoặc đã đối chiếu đầy đủ.

## Thư mục dự án

| Đường dẫn | Mục đích |
|---|---|
| `docs/` | tài liệu tổng thể, chi tiết và năm báo cáo gốc |
| `github/DATN-MITRE-ATTACK-SOAR-update/` | checkout Git; scripts, cấu hình, rule và tài liệu được chọn để công bố |
| `private/` | credential và state riêng, không commit |
| `SSH-server-ec2/` | private key, không commit |
| `evidence/` | bằng chứng đã loại secret; kiểm tra trước chia sẻ |
| `work/` | file trung gian và log; một số là bằng chứng vận hành, không tự động xóa |
| `archive/` | tài liệu lịch sử/backup; kiểm tra trước thay đổi |

## Trùng lặp xác định bằng SHA-256

Bốn bản trùng byte ở gốc `D:\DATN` và gốc `docs` đã được xóa sau khi đối chiếu SHA-256 với năm bản được bảo vệ; bản PB04 trong repository được giữ để phục vụ Git. Hai bản PB01 khác nhau về nội dung và trạng thái: bản được bảo vệ là lịch sử, bản trong repository là nghiệm thu mới; không xóa hay đánh đồng chúng.

## Lưu ý liên kết

Các báo cáo được chuyển/copy vào `MD Playbook` có thể chứa liên kết tương đối hướng tới vị trí cũ. Dùng các đường dẫn tuyệt đối trong phần hướng dẫn hoặc tìm cùng file dưới repository; không sửa bản gốc khi chưa đối chiếu. Bản tài liệu trên GitHub không chứa `private/`, bằng chứng thô hoặc VMX.
