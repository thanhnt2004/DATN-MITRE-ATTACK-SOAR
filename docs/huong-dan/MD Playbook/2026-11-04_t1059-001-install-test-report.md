# T1059.001 — PowerShell: cài đặt và kiểm thử playbook DATN

Ngày kiểm thử: **04/11/2026**, giờ Việt Nam (UTC+7). Đã kiểm thử đầu cuối nhánh **T1059.001 PowerShell** hai lần bằng Atomic Red Team trên Windows 10 Client. T1059 bao gồm nhiều kỹ thuật con; báo cáo này nghiệm thu hành vi PowerShell dùng tham số mã hóa, không đại diện cho toàn bộ T1059.

## Kết quả nghiệm thu

| Thành phần | Kết quả |
|---|---|
| VMware và mạng | pfSense LAN `192.168.10.1`; Windows 10 Client `192.168.10.101` trên VMnet10; Windows ra EC2 qua pfSense. Kali đã cấu hình VMnet10 từ PB04; lượt này Atomic chạy trực tiếp trên Windows để tạo sự kiện tiến trình tại endpoint. Kali không được bật hoặc kiểm thử trong lượt này. |
| Windows agent | Sysmon64 và Winlogbeat 9.5.4 đều Running, Automatic. PowerShell Script Block Logging được bật. |
| Vận chuyển log | Winlogbeat `Config OK`, xác minh CA, TLSv1.3 và `talk to server... OK` với Logstash EC2 `18.139.50.205:5044`. |
| Elasticsearch | Chỉ mục `datn-windows-2026.11.04` nhận Sysmon Event 1 và PowerShell Operational Event 4104. Kiểm tra trong 10 phút có 62 event 1 và 332 event 4104. |
| Atomic upstream | Test 17 GUID `a538de64-1c74-46ed-aa60-b995ed302598`, prerequisites met, in “Hello, from PowerShell!”, exit code 0 trong cả hai lượt. |
| Tự động hóa | `datn-t1059.timer` active, service success. Mỗi event Atomic được phát hiện, webhook vào Shuffle và Telegram trả `ok=true`. |
| Phản ứng | `DETECTED_NOTIFY_ONLY`, rủi ro medium. Shuffle ghi lịch sử execution và gửi Telegram; chưa có cách ly máy, chặn hay luồng phê duyệt. |

```text
Atomic Red Team trên Windows 10 Client
  → Sysmon Event 1 / PowerShell Event 4104
  → Winlogbeat → Logstash (TLS/5044) → Elasticsearch datn-windows-*
  → detector T1059.001 (systemd timer) → Shuffle webhook → Telegram
```

## 1. VMware và chuẩn bị mạng

| Máy | Cấu hình trong lượt kiểm thử |
|---|---|
| pfSense | VMX `C:\Users\taola\OneDrive\Documents\Virtual Machines\FreeBSD version 10 and earlier 64-bit\FreeBSD version 10 and earlier 64-bit.vmx`; WAN NAT, LAN custom VMnet10, LAN IP `192.168.10.1`. |
| Windows 10 Client | VMX `D:\tool\Windows 10 x64\Windows 10 x64.vmx`; NIC custom VMnet10, host `DESKTOP-2FV6M9C`, IP `192.168.10.101`. VMware Tools hoạt động; tài khoản đang dùng có quyền administrator. |
| Kali | VMX `D:\tool\Kali Linux\kali-linux-2025.4-vmware-amd64\kali-linux-2025.4-vmware-amd64.vmwarevm\kali-linux-2025.4-vmware-amd64.vmx`; NIC custom VMnet10 đã có từ PB04. Kali không cần để thực thi bài Atomic PowerShell cục bộ và không bật trong lượt này vì tài nguyên host còn hạn chế. |

Trên Windows host có thể dùng `vmrun.exe -T ws start <đường dẫn VMX> nogui` cho pfSense và Windows, rồi `vmrun.exe list` và `vmrun.exe getGuestIPAddress <Windows VMX> -wait`. Trong Windows guest dùng `ipconfig /all` và kiểm tra gateway. Dùng tài khoản quản trị guest và giữ mật khẩu ngoài tài liệu/repository. Máy Windows ban đầu chưa có dịch vụ Sysmon hoặc Winlogbeat; PowerShell Operational đã bật.

## 2. Sysmon, PowerShell logging và Winlogbeat

### Gói và xác minh

- Tải Sysmon từ `https://download.sysinternals.com/files/Sysmon.zip`, giải nén và kiểm tra `Get-AuthenticodeSignature Sysmon64.exe`: chữ ký **Valid**, Microsoft Windows Publisher.
- Tải `winlogbeat-9.5.4-windows-x86_64.zip` và file SHA512 cùng phiên bản từ `https://artifacts.elastic.co/downloads/beats/winlogbeat/`. Gói đã dùng 33.336.466 byte, SHA512 `8622C9454773162931FF9318891EB283B4CEE475BEB0519651B7A8BD26B1B68E317E9A29C80A8631E174BD75A3289A42F34477B2FB0742FC1D1A77E0AF6AF779`; đối chiếu checksum trước khi cài.
- CA Logstash hiện dùng được lấy từ EC2 `/opt/elk/logstash/certs/ca.crt`. Không thay bằng cách tắt kiểm tra certificate.

### Cài trên Windows guest

Các file cài được lưu trong repository `D:\DATN\github\DATN-MITRE-ATTACK-SOAR-update`:

- `scripts/t1059-install-windows-agent.ps1`: cài Sysmon cấu hình mặc định, bật Script Block Logging, cài Winlogbeat, thử config và TLS, tạo service.
- `agents/windows/winlogbeat-t1059-example.yml`: kênh Sysmon Operational Event 1 và 3, PowerShell Operational 4104, Security 4688; gắn `fields.log_source: windows`; gửi Logstash với CA.
- Script từ chối cài đè nếu đã có service Sysmon hoặc Winlogbeat. Nếu đã có agent, kiểm tra và gộp kênh/output vào cấu hình hiện tại.

Trên Windows guest tạo `C:\Windows\Temp\datn-t1059`. Chép vào thư mục này:

| Tên file trong guest | Nguồn |
|---|---|
| `Sysmon64.exe` | Gói Sysmon đã xác minh |
| `winlogbeat.zip` | Gói Elastic đã xác minh checksum |
| `ca.crt` | CA Logstash EC2 |
| `winlogbeat.yml` | File `agents/windows/winlogbeat-t1059-example.yml` |
| `install.ps1` | File `scripts/t1059-install-windows-agent.ps1` |

Chạy PowerShell với quyền administrator:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\datn-t1059\install.ps1
Get-Service Sysmon64,winlogbeat
& 'C:\Program Files\Winlogbeat\winlogbeat.exe' test config -c 'C:\Program Files\Winlogbeat\winlogbeat.yml'
& 'C:\Program Files\Winlogbeat\winlogbeat.exe' test output -c 'C:\Program Files\Winlogbeat\winlogbeat.yml'
```

Cài đặt thực tế ghi `INSTALL_STATUS=SUCCESS` trong `C:\Windows\Temp\datn-t1059\install.log`. Sysmon cài cấu hình mặc định; Event 1 đã được kiểm tra. Cấu hình Winlogbeat có đăng ký Event 3 và 4688 nhưng hai loại này **chưa được nghiệm thu**; Sysmon mặc định không bật network Event 3. Event 4104 đã tới Elasticsearch, dùng để điều tra; detector hiện chỉ đọc Event 1.

## 3. Logstash và Elasticsearch

ELK 9.5.4 đã có sẵn trên EC2. Pipeline live `/opt/elk/logstash/pipeline/logstash.conf` đã có route cho `fields.log_source=windows` tới `datn-windows-YYYY.MM.dd`; không cài lại hay sửa pipeline trong lượt này. Kiểm tra `datn-logstash`, `datn-elasticsearch`, `datn-kibana` và API Logstash `http://127.0.0.1:9600/_node/pipelines` trên EC2.

API key mới ID `KJ8epKEB5OJCB0FcmGcs` có quyền `read`, `view_index_metadata` trên `datn-windows-*`. Secret nằm trong `/opt/datn-t1059/t1059.env` quyền 0600, thuộc user chạy detector. Tạo mới bằng `scripts/t1059-create-api-key.py` sau khi cung cấp các biến `T1059_ES_URL`, `T1059_ES_CA`, `T1059_BOOTSTRAP_USER`, `T1059_BOOTSTRAP_PASSWORD`, `T1059_SHUFFLE_WEBHOOK` trong môi trường phiên thực thi. URL/CA thực tế là `https://127.0.0.1:9200` và `/opt/elk/elasticsearch/certs/ca/ca.crt`. Không ghi secret vào Git hay báo cáo.

`scripts/t1059-evidence.py` truy vấn bằng key trên và in số event theo channel/code mà không in nội dung script. Dùng dữ liệu thật để xác nhận mapping trước khi thay đổi quy tắc.

## 4. Detector và Shuffle

Detector `scripts/t1059_powershell_detector.py` được cài tại `/opt/datn-t1059/`. Nó đọc các event trong 5 phút gần nhất, lấy tối đa 5.000 document, chọn Sysmon Operational Event 1 với image `powershell.exe` hoặc `pwsh.exe` và command line có `-e`, `-enc`, hoặc `-encodedcommand`. Nó gửi host, user, đường dẫn process/parent, thời gian, ID document và mức medium; không gửi command line hoặc script body qua Telegram. Không suy luận tên Atomic hay GUID từ telemetry tự quan sát.

Cài các unit `scripts/datn-t1059.service` và `scripts/datn-t1059.timer` vào `/etc/systemd/system/`, sau đó:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now datn-t1059.timer
systemctl is-active datn-t1059.timer
systemctl show datn-t1059.service -p Result -p ExecMainStatus
journalctl -u datn-t1059.service --no-pager -n 30
```

Timer chạy khoảng mỗi 60 giây. Detector ghi state tại `/opt/datn-t1059/state.json`, dùng index/document ID để không gửi lại cùng event; state cũ được giữ tối đa 24 giờ. Nếu webhook không được chấp nhận, state của event đó không được đánh dấu đã gửi. Việc có webhook HTTP 200 chỉ chứng minh Shuffle nhận, cần xem execution để xác minh Telegram.

Workflow `T1059.001 PowerShell Investigation - Notify Only` có ID `a8496afc-6f60-43ba-87b0-bde5792d6486`, webhook trigger `22b8b433-e06c-4c11-91fa-41b4288da974`. `scripts/create-t1059-shuffle-workflow.ps1` tạo/cập nhật workflow từ Telegram action PB01; ID được lưu tại `D:\DATN\private\t1059-shuffle-workflow-id.txt`. Action kế thừa token Telegram từ workflow gốc, vì vậy không công bố bản export chứa token.

Rule Sigma `sigma/rules/t1059_001_powershell_encoded_command.yml` là bản thử nghiệm mô tả detection; runtime đã nghiệm thu là detector Python, **chưa tạo Elastic Detection Rule từ Sigma**. Rule không có allowlist và không bao phủ tất cả biến thể của tham số PowerShell.

## 5. Cài và chạy Atomic Red Team

Test dùng upstream `T1059.001-17`, GUID `a538de64-1c74-46ed-aa60-b995ed302598`, chạy PowerShell với payload mã hóa chỉ in thông điệp. Trên host đã dùng `Save-Module Invoke-AtomicRedTeam` để tải module cùng `powershell-yaml`, nén hai thư mục vào `modules.zip`. Tải YAML upstream từ `https://raw.githubusercontent.com/redcanaryco/atomic-red-team/master/atomics/T1059.001/T1059.001.yaml`; bản đã dùng có SHA256 `54EBDBCCFD6D5435A52BB048B3E8B9DE541D8F0BD6C86F97FF982A15F1A76945`.

Chép `modules.zip`, YAML đổi tên `T1059.001.yaml` và `scripts/t1059-run-atomic-windows.ps1` đổi tên `atomic.ps1` vào `C:\Windows\Temp\datn-t1059`. Trong Windows guest:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\datn-t1059\atomic.ps1
Get-Content C:\Windows\Temp\datn-t1059\atomic-run.log
```

Wrapper giải nén module, nạp Invoke-AtomicRedTeam, kiểm tra prerequisites rồi thực thi đúng GUID. Kiểm tra cả dòng `Exit code: 0` của Atomic, output Hello và log nguồn; `WRAPPER_STATUS=COMPLETED` một mình không chứng minh test con thành công.

## 6. Bằng chứng kiểm thử 04/11/2026

Thời gian bên dưới là UTC; cộng 7 giờ để ra giờ Việt Nam.

| Kiểm thử | Bằng chứng |
|---|---|
| Fixture logic | Dữ liệu tổng hợp có PowerShell `-e` tạo finding; PowerShell `-Command Get-Date` không tạo finding. Đây là kiểm tra đơn giản, chưa phải đánh giá false positive/false negative toàn diện. |
| Shuffle độc lập | Dữ liệu tổng hợp `T1059-SYNTHETIC-WORKFLOW`, execution `9f6c1b65-c3b6-4dc9-9714-862ce1456f0e`, `FINISHED`, action `SUCCESS`, Telegram `ok=true`; tin gắn `TEST_ONLY`. |
| Atomic lần 1 | Start `01:19:09.771Z`, end `01:19:20.579Z`, prerequisite đạt, exit 0. Event `01:19:18.907Z`, document `1J8jpKEB5OJCB0FcnGkt`, index `datn-windows-2026.11.04`; parent `cmd.exe`. Timer gửi 1 finding; Shuffle execution `07e93e2b-fa2e-47ef-8e67-664bd98634cd`, `FINISHED`, Telegram `ok=true`. |
| Atomic lần 2 | Start `01:20:23.231Z`, end `01:20:37.670Z`, prerequisite đạt, exit 0. Event `01:20:36.270Z`, document `658kpKEB5OJCB0FcvWrH`; timer đọc cả hai finding cũ/mới nhưng chỉ gửi 1 notification mới. Shuffle execution `df6c873f-d98e-477c-bc4f-5dd6b432ee01`, `FINISHED`, Telegram `SUCCESS`, `ok=true`. |
| Định dạng tin | Tin lượt đầu mất dấu backslash do nội suy JSON. Detector đã chuyển backslash thành dấu `/` cho trường user và đường dẫn trước khi gửi; tin lượt hai hiển thị đầy đủ `DESKTOP-2FV6M9C/thanh_49v34lz` và `C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe`. Dữ liệu gốc trong Elasticsearch không bị thay đổi. |

Log cài và hai lượt Atomic của lần thử được lưu trên host tại `D:\DATN\work\t1059-install.log`, `t1059-atomic-run.log`, `t1059-atomic-run-second.log`. Để đối chiếu Shuffle có thể dùng `scripts/pb01-check-shuffle-execution.ps1` với `-WorkflowId a8496afc-6f60-43ba-87b0-bde5792d6486 -TestId T1059-AUTO -InspectMessage`.

## 7. Giới hạn và khôi phục

- Encoded command có thể được quản trị và phần mềm hợp lệ dùng; rule cần baseline và allowlist trước khi dùng ngoài lab. Nó không bao phủ PowerShell chạy qua .NET, các tên switch/chuỗi bị biến thể hay mọi kỹ thuật con T1059.
- Tối đa 5.000 event trong 5 phút có thể khiến event bị bỏ sót khi tải lớn; cần phân trang hoặc truy vấn lọc phía Elasticsearch. Nếu timer dừng quá 5 phút, dữ liệu cũ ngoài cửa sổ không được xử lý. Chưa kiểm thử độ bền qua reboot, mất mạng dài hoặc tải cao.
- Script Block Logging có thể ghi nội dung nhạy cảm; hạn chế quyền đọc và thời gian lưu giữ. Webhook lab hiện dùng HTTP; token bot được kế thừa trong action Shuffle. Khi chuyển môi trường khác cần quản lý secret và giới hạn truy cập phù hợp.
- Để dừng detector: `sudo systemctl disable --now datn-t1059.timer`. Để khôi phục cấu hình Windows, chỉ sau khi kiểm tra phụ thuộc khác: dừng/gỡ Winlogbeat theo hướng dẫn Elastic, gỡ Sysmon bằng lệnh gỡ của Microsoft và hoàn nguyên giá trị `EnableScriptBlockLogging` đã tạo. Không xóa chỉ mục, state hay workflow khi còn cần bằng chứng.

## Nguồn chính thức

- [MITRE ATT&CK T1059.001](https://attack.mitre.org/techniques/T1059/001/)
- [Atomic Red Team T1059.001](https://github.com/redcanaryco/atomic-red-team/blob/master/atomics/T1059.001/T1059.001.md)
- [Microsoft Sysmon](https://learn.microsoft.com/sysinternals/downloads/sysmon)
- [Elastic Winlogbeat event logs](https://www.elastic.co/docs/reference/beats/winlogbeat/configuration-winlogbeat-options)
