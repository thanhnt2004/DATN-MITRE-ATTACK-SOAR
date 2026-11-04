# Bảo vệ tài liệu và backup

## Tài liệu quan trọng

Sáu file cần giữ: file credential master trong `D:\DATN\private\2026-11-04_credentials-master-private.md` và năm báo cáo T1046, PB01, PB04, T1059, T1105 trong `D:\DATN\docs\MD Playbook`. Không đưa file credential, bản sao raw hoặc SSH key lên GitHub. Tên chính xác của năm báo cáo có trong [danh mục](05-danh-muc-va-lich-su.md).

Ngày 04/11/2026 đã cấu hình NTFS deny quyền Delete cho user host hiện tại trên sáu file, và deny DeleteSubdirectoriesAndFiles cho user đó trên hai thư mục cha. Quyền đọc được xác nhận; một file thử với cùng cơ chế đọc được và bị từ chối xóa. Quyền này chặn xóa vô ý trong ngữ cảnh user đó, **không phải bảo đảm không thể xóa**: chủ sở hữu/administrator có thể đổi ACL, quyền trên filesystem khác hoặc ứng dụng đồng bộ có hành vi khác. Quyền deny DeleteChild trên thư mục cha có thể ảnh hưởng thao tác thay thế/xóa file khác; khi cần chỉnh sửa, dùng ứng dụng ghi trực tiếp và kiểm tra kết quả, hoặc nhờ chủ sở hữu điều chỉnh ACL có kiểm soát.

Không dùng thuộc tính Read-only để giả làm cơ chế chống xóa. Không xóa, đổi tên hoặc áp ACL lại các bản gốc chỉ để dọn thư mục. Trước mọi sửa đổi, tạo bản backup an toàn và xác minh hash; credential backup phải được mã hóa hoặc lưu tại kho bí mật phù hợp. ACL không thay thế backup ngoại tuyến.

## Kho bí mật

File tài khoản là thông tin nhạy cảm và có thể đã được người dùng chỉnh sửa. Không tự ghi đè, in hoặc sao chép nội dung vào báo cáo công khai; ghi thời điểm và trạng thái xác minh từng tài khoản. Password của user khác không thể suy ra từ danh sách account. SSH private key, API key, Telegram bot token, CA private key, `.env`, state nhạy cảm và export workflow raw cần lưu riêng.

T1105 host responder dùng file DPAPI gắn user Windows host; sao chép file XML một mình sang user/máy khác không bảo đảm giải mã được. Khi phục hồi sang host mới cần tạo credential lại và kiểm tra task. Hạn chế quyền đọc process và nhật ký vì `vmrun` nhận credential khi gọi guest.

## Backup và phục hồi

1. Lưu VMX, danh sách snapshot, cấu hình network, filebeat/winlogbeat/sysmon, compose/pipeline và service/timer. Không sao lưu vào thư mục Logstash pipeline đang được nạp.
2. Backup dữ liệu Elasticsearch bằng cơ chế snapshot phù hợp, đồng thời sao lưu Shuffle workflows đã loại secret và cấu hình runtime riêng theo chính sách; Git không thay thế backup volume.
3. Đối chiếu SHA-256, thời điểm, vị trí và thử phục hồi trên môi trường riêng. Ghi lại chủ sở hữu backup và thời hạn giữ.
4. Với T1105, dừng timer EC2 và task host trước thay đổi. Restore marker bằng script có kiểm tra hash, không ghi đè tệp đích. Với cấu hình Sysmon/Beats, khôi phục bản trước thay đổi rồi kiểm tra playbook còn lại.
