# PB01 — T1110.003 Password Spraying: cài đặt và nghiệm thu

Ngày kiểm thử: 03/11/2026. Môi trường: DATN lab. Nguồn tấn công là **Invoke-AtomicTest chạy trên Kali**, dùng bài Atomic mở rộng riêng cho lab (GUID `9d3c97df-01f6-44b8-b28e-4a56e2d781eb`). Bài này không nằm trong bộ upstream của Red Canary.

## Trạng thái

| Chặng | Kết quả |
|---|---|
| Kali `192.168.10.102` → Ubuntu SSH `192.168.10.103` | Atomic test `T1110.003-1`, prerequisites met, exit code 0 |
| Ubuntu `sshd` → Filebeat/Logstash → Elasticsearch | 5 tài liệu `Failed password` cho 5 username từ cùng IP, index `datn-ubuntu-2026.11.03` |
| PB01 correlation | 1 finding, `distinct_user_count=5`, `failed_authentication_count=5`, cửa sổ 5 phút |
| PB01 → Shuffle → Telegram | Webhook HTTP 200, Shuffle `FINISHED`, action `SUCCESS`, Telegram `ok=true` |
| Vận hành liên tục | `datn-pb01.timer` bật, chạy khoảng mỗi 60 giây; lượt Atomic thứ hai được phát hiện và gửi tự động, `Result=success` |
| Phản ứng | **Thông báo và ghi nhận**. Chưa tự động chặn IP; xem giới hạn bên dưới. |

## Tệp cài đặt

| Tệp | Mục đích |
|---|---|
| [`scripts/pb01_password_spraying.py`](../scripts/pb01_password_spraying.py) | Truy vấn và tương quan đăng nhập thất bại, allowlist, chống lặp, gửi webhook |
| [`scripts/pb01-ec2-api-key.py`](../scripts/pb01-ec2-api-key.py) | Tạo API key Elastic chỉ đọc và tệp môi trường quyền `0600` |
| [`scripts/pb01-ec2-evidence.py`](../scripts/pb01-ec2-evidence.py) | Xuất document ID, IP, username, thời gian đã lọc để đối chiếu |
| [`scripts/datn-pb01.service`](../scripts/datn-pb01.service), [`scripts/datn-pb01.timer`](../scripts/datn-pb01.timer) | Chạy detector mỗi phút trên EC2 |
| [`scripts/create-pb01-shuffle-workflow.ps1`](../scripts/create-pb01-shuffle-workflow.ps1) | Tạo/cập nhật workflow PB01 theo ID |
| [`atomic-red-team/test-cases/T1110.003/T1110.003.yaml`](../atomic-red-team/test-cases/T1110.003/T1110.003.yaml) | Bài Atomic DATN: một mật khẩu sai trên 5 username lab |
| [`scripts/pb01-kali-run-atomic.ps1`](../scripts/pb01-kali-run-atomic.ps1) | Chạy prerequisites và test GUID trên Kali |
| [`scripts/pb01-check-shuffle-execution.ps1`](../scripts/pb01-check-shuffle-execution.ps1) | Kiểm tra execution, chỉ xuất trạng thái đã lọc |
| [`sigma/rules/pb01_password_spraying_linux.yml`](../sigma/rules/pb01_password_spraying_linux.yml), [`sigma/rules/pb01_password_spraying_windows.yml`](../sigma/rules/pb01_password_spraying_windows.yml) | Quy tắc chọn sự kiện cơ sở; correlation thực tế nằm trong detector |

## Cài lại trong lab

1. Bật các VM Kali, Ubuntu, pfSense. Xác nhận Kali có IP `192.168.10.102`, Ubuntu `192.168.10.103`; SSH Ubuntu mở trên VMnet10. Không dùng tài khoản thật trong bài Atomic.
2. Trên Kali, cài PowerShell Core, `sshpass`, rồi cài `Invoke-AtomicRedTeam` và `powershell-yaml` bằng [`pb01-kali-install-atomic.ps1`](../scripts/pb01-kali-install-atomic.ps1). Đặt `T1110.003.yaml` và `src/lab_users.txt` vào `/home/kali/AtomicRedTeam/atomics/T1110.003/`. Thư mục `src` chứa 5 username `datn_spray_01` đến `_05`.
3. Trong PowerShell Kali chạy:

   ```powershell
   Import-Module Invoke-AtomicRedTeam
   Invoke-AtomicTest T1110.003 -TestGuids 9d3c97df-01f6-44b8-b28e-4a56e2d781eb -PathToAtomicsFolder /home/kali/AtomicRedTeam/atomics -CheckPrereqs -Confirm:$false
   Invoke-AtomicTest T1110.003 -TestGuids 9d3c97df-01f6-44b8-b28e-4a56e2d781eb -PathToAtomicsFolder /home/kali/AtomicRedTeam/atomics -Confirm:$false
   ```

4. Trên EC2, chép detector vào `/opt/datn-pb01/`. Tạo API key bằng [`pb01-ec2-api-key.py`](../scripts/pb01-ec2-api-key.py) với `PB01_ES_URL`, `PB01_ES_CA`, `PB01_SHUFFLE_WEBHOOK`, `PB01_BOOTSTRAP_USER`, `PB01_BOOTSTRAP_PASSWORD` trong môi trường. Không ghi mật khẩu vào Git. Script ghi `/opt/datn-pb01/pb01.env` quyền `0600`. Tài khoản bootstrap chỉ cần khi tạo key.
5. Chép hai unit vào `/etc/systemd/system/`, chạy `sudo systemctl daemon-reload` và `sudo systemctl enable --now datn-pb01.timer`. Kiểm tra `systemctl list-timers datn-pb01.timer` và `systemctl show datn-pb01.service -p Result -p ExecMainStatus`.
6. Workflow Shuffle hiện có ID `2c92993a-4901-479c-a677-44bf2851186f`, webhook trigger ID `b1b0832f-e1d8-43b8-b329-120addde42dd`. Chạy lại script PowerShell với ID đó sẽ cập nhật workflow, tránh tạo bản trùng. Khi cài trên tổ chức mới, chỉ dùng `-TargetWorkflowId ''` một lần, sau đó lưu ID trả về.

## Bằng chứng lượt Atomic ngày 03/11/2026

- Kali: bắt đầu `07:14:31.8899706Z`, kết thúc `07:14:55.0460042Z`; `CheckPrereqs` báo đạt; `Invoke-AtomicTest` exit code `0`.
- Elasticsearch: 5 event từ `192.168.10.102` trên host `prod-web-01`, thời gian `07:14:37.169Z` đến `07:14:53.174Z`, user `datn_spray_01` đến `_05`. Document ID lần lượt: `ITxCoKEB0EtnosVasKcQ`, `HDxCoKEB0EtnosVar6f7`, `JjxCoKEB0EtnosVasKcQ`, `LTxCoKEB0EtnosVa16cq`, `NTxCoKEB0EtnosVa16cv`.
- Detector live đọc 10 event liên quan trong 5 phút, tạo 1 finding đúng IP và 5 user. Gửi webhook trả `http_status=200`, `accepted=true`, `notifications_sent=1`.
- Shuffle execution `2261ce62-453b-4102-8d5a-9043769259ef`, test ID `DATN-PB01-ATOMIC-20261103-071431Z`, `FINISHED`; Telegram action `SUCCESS`, `ok=true`. Từ event cuối đến Shuffle bắt đầu khoảng 16 giây; đến execution hoàn tất khoảng 37 giây.
- Chạy detector với `--allow-ip 192.168.10.102` trên cùng log thật: 0 finding. Lượt timer kế tiếp nhận finding cũ nhưng ghi `notification_suppressed=duplicate_window`, không gửi thêm. Fixture 8 event cho 1 finding; ca dưới ngưỡng/allowlist cho 0 finding.
- API key `cTxEoKEB0EtnosVaQqdd` chỉ có `read` và `view_index_metadata` trên `datn-ubuntu-*`, `datn-windows-*`; truy vấn live bằng key thành công. **ID này không phải secret**; giá trị key nằm riêng trong `/opt/datn-pb01/pb01.env`.

## Nghiệm thu timer tự động — lượt Atomic thứ hai

- Atomic bắt đầu `07:19:59.591Z`, kết thúc `07:20:25.017Z`, prerequisites met và exit code `0`.
- Năm document mới có thời gian `07:20:03.204Z` đến `07:20:23.213Z`, cùng IP `192.168.10.102`, user `datn_spray_01` đến `_05`. Document ID: `MTxHoKEB0EtnosVaoajo`, `ODxHoKEB0EtnosVaoaj1`, `PzxHoKEB0EtnosVayagC`, `RjxHoKEB0EtnosVayagC`, `TzxHoKEB0EtnosVa76i_`.
- `datn-pb01.timer` kích hoạt service lúc `07:21:15Z`. Journal ghi 1 finding, `http_status=200`, `accepted=true`, `notifications_sent=1`, `Result=success`, `ExecMainStatus=0`. Lần này **không gọi detector thủ công với `--send`**.
- Shuffle execution `b2eab3fd-d67b-4545-b20e-73da9cb5a3f2`, test ID `PB01-AUTO`, `FINISHED`; Telegram action `SUCCESS`, `ok=true`. Từ event thứ năm đến lúc service gửi webhook khoảng 52 giây; đến lúc execution hoàn tất khoảng 64 giây.
- Một lần timer trước khi đủ 5 user không gửi cảnh báo. Trong lượt đầu, các lần timer kế tiếp trong cửa sổ chống lặp đều ghi `notification_suppressed=duplicate_window`.

## Giới hạn và quyết định vận hành

### Sửa định dạng trường Hosts ngày 03/11/2026

Hai cảnh báo đầu tiên trong Telegram dừng ở `Hosts: [` vì workflow chèn trực tiếp `$exec.hosts` (mảng JSON) vào nội dung message. Detector hiện gửi thêm `hosts_text` là chuỗi tên host nối bằng dấu phẩy; template Shuffle dùng `$exec.hosts_text`. Cảnh báo kiểm tra `PB01-HOST-FORMAT-CHECK` được gửi từ fixture có nhãn `synthetic-fixture`, execution `8c0dd2c8-dd5c-4db1-b4f6-08d683ed5832` đã `FINISHED`, action `SUCCESS`, Telegram `ok=true`. Trường `text` do Telegram trả về chứa đầy đủ `Hosts: win-lab`, `Test ID: PB01-HOST-FORMAT-CHECK` và `Status: DETECTED_NOTIFY_ONLY`.

Tin thử này còn lỗi mã hóa emoji/dấu đầu dòng (`�`). Mẫu Shuffle đã đổi sang văn bản ASCII. Tin kiểm tra `PB01-ASCII-FORMAT-CHECK`, execution `8f4cd0ee-4d3f-4f81-a4e8-fb4501854a83`, trả `FINISHED`, action `SUCCESS`, Telegram `ok=true`; trường `text` Telegram trả về bắt đầu `[PB01] T1110.003 Password Spraying` và có đầy đủ `Hosts: win-lab`, `Test ID: PB01-ASCII-FORMAT-CHECK`, `Status: DETECTED_NOTIFY_ONLY` mà không còn ký tự lỗi.

PB01 hiện là **notify only**. Trên mạng lab, Kali và Ubuntu cùng subnet `192.168.10.0/24`; chặn tại pfSense không bảo đảm ngăn luồng đi trực tiếp giữa hai VM. Cần đặt luồng qua gateway hoặc chặn ở Ubuntu trước khi tuyên bố tự động ngăn tấn công. Không đưa hành động block vào chuỗi nghiệm thu này.

Nhánh Windows chưa nghiệm thu: các mẫu Event 4625 cũ thiếu `source.ip`/`TargetUserName` đủ để correlation. Nhánh Linux đã được chứng minh bằng log thật. Ngưỡng 5 user/5 phút là ngưỡng lab, cần hiệu chỉnh theo baseline khi chuyển sang môi trường khác. Token Telegram của workflow gốc còn nằm trong Shuffle action; cần xoay và quản lý bằng Authentication trước khi công bố bản export workflow.

## Nguồn tham khảo

- [Red Canary: cài Invoke-AtomicRedTeam](https://github.com/redcanaryco/invoke-atomicredteam/wiki/Installing-Invoke-AtomicRedTeam)
- [Red Canary: chạy test bằng GUID và custom atomics folder](https://github.com/redcanaryco/invoke-atomicredteam/wiki/Execute-Atomic-Tests-%28Local%29)
- [Atomic Red Team upstream T1110.003](https://github.com/redcanaryco/atomic-red-team/blob/master/atomics/T1110.003/T1110.003.md)
