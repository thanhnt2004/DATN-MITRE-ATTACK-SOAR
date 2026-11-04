# T1105 — Tải công cụ: cài đặt, cách ly và kiểm thử lab

Ngày kiểm thử: **04/11/2026**, múi giờ Việt Nam UTC+7. Trạng thái: **đã kiểm thử đầu cuối cho đúng tệp thử và topology lab**. Bài này không khẳng định phát hiện hoặc cách ly mọi trường hợp T1105.

## 1. Kết quả

| Chặng | Kết quả thực tế |
|---|---|
| Nguồn thử | Kali `192.168.10.102:8088` phục vụ một tệp văn bản vô hại; Windows `192.168.10.101` tải tệp bằng Invoke-AtomicRedTeam. |
| Telemetry | Sysmon Event 3 và Event 11 trên Windows có cùng ProcessGuid; Winlogbeat gửi TLS tới Logstash và Elasticsearch `datn-windows-2026.11.04`. |
| Detection | Timer EC2 tương quan host, ProcessGuid và thời gian giữa kết nối tới Kali và tạo đúng tệp thử; gửi finding vào Shuffle. |
| Phản ứng | Shuffle execution hoàn tất; responder trên **Windows host** đọc execution thành công, xác minh các điều kiện cho phép rồi gọi script trong Windows guest. Guest kiểm tra SHA-256 và chuyển đúng tệp vào quarantine. |
| Kiểm tra kết quả | Guest báo `source_exists=false`, `quarantine_exists=true`, hash không đổi. Responder gửi webhook kết quả; Shuffle gửi Telegram `QUARANTINE_VERIFIED`, `QUARANTINED`. |
| Khôi phục | Gọi script guest với `-Action Restore`: tệp trở lại đường dẫn ban đầu, tệp quarantine không còn, SHA-256 không đổi. Đây là thao tác khôi phục được gọi thủ công trong kiểm thử. |
| Kiểm tra âm tính | Khi nội dung tệp thử bị thay đổi, script từ chối cách ly do SHA-256 không khớp; sau thử nghiệm tệp gốc được phục hồi. |

**Phê duyệt:** người dùng đã yêu cầu cách ly tệp thử này. Nhánh tự động chỉ cho phép tệp, IP, host và hash cố định của lab; không có giao diện phê duyệt analyst cho tệp tùy ý. Hai tin Telegram phân biệt `DETECTED_PENDING_QUARANTINE` và `QUARANTINED`; tin đầu không đồng nghĩa xử lý đã thành công.

```text
Kali HTTP server:8088 → Atomic Windows download
  → Sysmon 3 + 11 → Winlogbeat → pfSense → EC2 Logstash/Elastic
  → datn-t1105.timer → Shuffle execution + Telegram pending
  → host responder kiểm tra execution + điều kiện lab
  → VMware Tools → Windows guest kiểm tra hash → quarantine
  → host responder kiểm tra kết quả → Shuffle + Telegram QUARANTINED
  → Restore được gọi thủ công khi cần
```

## 2. Máy ảo, file và địa chỉ

| Thành phần | Cấu hình đã dùng |
|---|---|
| pfSense | WAN NAT, LAN VMnet10 `192.168.10.1` |
| Kali | VMnet10 `192.168.10.102`, Python HTTP server bind IP này cổng 8088 |
| Windows 10 Client | VMnet10 `192.168.10.101`, hostname `DESKTOP-2FV6M9C`, Sysmon và Winlogbeat |
| EC2 | `18.139.50.205`; ELK và Shuffle hiện có, Logstash TLS `5044`, Shuffle `3001` |
| Windows host | `D:\DATN`, VMware Workstation; responder dùng `vmrun.exe` để gọi đúng guest |
| Tệp thử | `C:\DATN-T1105\incoming\t1105-lab-sample.txt`, nội dung văn bản vô hại, không chạy được |
| Quarantine | `C:\ProgramData\DATN-T1105\Quarantine\t1105-lab-sample.txt.quarantined` |

SHA-256 tệp thử: `613DBDF3F2E76FF5773E8A5C6D09D6278A907F985108E33DB7C62E772635A754`. Detector gửi hash **dự kiến** của tệp lab; hash thực tế được kiểm tra tại guest trước và sau khi chuyển. IP Kali và Windows cùng VMnet10 nên luồng HTTP có thể đi trực tiếp, không coi rule pfSense là biện pháp cách ly endpoint.

Repository: `D:\DATN\github\DATN-MITRE-ATTACK-SOAR-update`. Tài khoản và mật khẩu được tổng hợp riêng trong `D:\DATN\private\2026-11-04_credentials-master-private.md`, không được đưa vào tài liệu playbook hoặc Git.

## 3. Cấu hình và cài đặt

### 3.1. Khởi động máy và phục vụ tệp trên Kali

Các VMX đã có trong thư mục VMware của dự án. Bật pfSense, Windows 10 Client và Kali bằng VMware Workstation hoặc `vmrun.exe -T ws start <VMX> nogui`; xác minh IP Windows/Kali và gateway. Kali dùng 2048 MiB theo VMX. Lượt này Kali đang ở trạng thái suspended, nên khi thử thay đổi xuống 1024 MiB VMware từ chối resume; VMX đã được khôi phục về 2048 MiB và trạng thái suspended được giữ nguyên trước khi bật.

Chép `atomic-red-team/test-cases/T1105/t1105-lab-sample.txt` vào Kali `/home/kali/t1105-http/t1105-lab-sample.txt`, và `scripts/t1105-kali-server.sh` vào Kali. Chạy script bằng Bash trong Kali:

```bash
bash /tmp/t1105-kali-server.sh
```

Script chạy `python3 -m http.server 8088 --bind 192.168.10.102` từ `/home/kali/t1105-http`. Khi chạy bằng `vmrun runProgramInGuest` có thể dùng `-noWait`; sau đó xác nhận process và thử HTTP từ Windows. Server này phục vụ marker lab, không cần công bố ra Internet.

### 3.2. Sysmon và Winlogbeat trên Windows

Trước lượt T1105, Sysmon64 và Winlogbeat 9.5.4 đã cài theo báo cáo T1059. Kiểm tra trạng thái trước khi sửa. Chép hai tệp vào `C:\Windows\Temp\datn-t1105`:

| Tệp guest | Tệp repository |
|---|---|
| `sysmon-t1105-lab.xml` | `agents/windows/sysmon-t1105-lab.xml` |
| `configure.ps1` | `scripts/t1105-configure-telemetry.ps1` |

Chạy PowerShell administrator trong guest:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\datn-t1105\configure.ps1
Get-Service Sysmon64,winlogbeat
& 'C:\Program Files\Winlogbeat\winlogbeat.exe' test config -c 'C:\Program Files\Winlogbeat\winlogbeat.yml'
```

Script ghi cấu hình Sysmon trước thay đổi vào `sysmon-before.txt`, sao lưu Winlogbeat vào `winlogbeat-before.yml`, nạp Sysmon XML và thêm Event 11 vào danh sách Sysmon Event 1/3 của Winlogbeat; cấu hình khác được giữ. XML thu Event 3 đến IP Kali và Event 11 dưới `C:\DATN-T1105\incoming\`. Sysmon schema 4.90 được service 4.91 xác nhận hợp lệ; log `telemetry-install.log` ghi `TELEMETRY_CONFIG=SUCCESS`, hai dịch vụ Running. Sau thay đổi, Elasticsearch vẫn ghi nhận Sysmon 1 và PowerShell 4104; **không chạy lại toàn bộ bài T1059** trong lượt này.

File `sysmon-before.txt` là bản hiển thị trạng thái, không phải bản XML có thể nạp trực tiếp. Nếu trước đó có cấu hình Sysmon khác, cần giữ file XML gốc để rollback chính xác. Cấu hình thực tế trước lượt này là Sysmon mặc định của T1059.

### 3.3. Atomic Red Team

Trong Windows guest đã có module Invoke-AtomicRedTeam và `powershell-yaml` tại `C:\Windows\Temp\datn-t1059\modules` từ lượt T1059. Chép `scripts/t1105-run-atomic-windows.ps1` thành `C:\Windows\Temp\datn-t1105\atomic.ps1`, và YAML lab `atomic-red-team/test-cases/T1105/T1105.yaml` thành `C:\Windows\Temp\datn-t1105\T1105.yaml`. Script tạo folder `C:\DATN-T1105\incoming` và dùng đúng URL/tệp lab. Nếu tệp đích đã có, script chỉ xóa tệp đó sau khi hash khớp mẫu thử; từ chối nếu hash khác.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\datn-t1105\atomic.ps1
Get-Content C:\Windows\Temp\datn-t1105\atomic-run.log
```

Bài đang dùng là Atomic **mở rộng riêng DATN**, GUID `1a4cb27d-4834-4c6a-86e0-01f8b0f6cbe7`. Nó tải marker và giữ process sống thêm 12 giây để Sysmon ghi kết nối có ProcessGuid. Bài upstream PowerShell Download GUID `42dc4460-9aa6-45d3-b1a6-3955d34e1fe8` cũng đã tải thành công; một lượt sau khi VM resume ghi Event 3 với ProcessGuid rỗng, nên không thỏa rule ghép GUID. Không gắn nhãn bài mở rộng là upstream.

YAML upstream được tải từ [Atomic Red Team T1105](https://github.com/redcanaryco/atomic-red-team/blob/master/atomics/T1105/T1105.yaml), SHA-256 bản dùng `D640BEAA6B6544F452D0F3DBF957F3138ADB4A148B9D51DF746197A781E519AA`. Bài upstream `certutil` GUID `dd3b61dd-7bbc-48cd-ab51-49ad1a776df0` ban đầu bị `Access is denied` khi tạo process; không tắt bảo vệ để ép chạy, sau đó dùng PowerShell Download.

### 3.4. Detector trên EC2 và Shuffle

ELK/Logstash route `fields.log_source=windows` đã có. Chép `scripts/t1105_detector.py`, `scripts/t1105-create-api-key.py`, `scripts/datn-t1105.service`, `scripts/datn-t1105.timer` lên `/opt/datn-t1105/` trên EC2; thư mục thuộc user `ubuntu`. Tạo API key bằng script sau khi đặt `T1105_ES_URL`, `T1105_ES_CA`, `T1105_BOOTSTRAP_USER`, `T1105_BOOTSTRAP_PASSWORD`, `T1105_SHUFFLE_WEBHOOK` trong môi trường. API key ID `gJ83pKEB5OJCB0FcVXBE` chỉ có `read` và `view_index_metadata` trên `datn-windows-*`; secret và webhook lưu trong `/opt/datn-t1105/t1105.env` quyền 0600. Không ghi secret vào Git.

```bash
sudo install -m 0644 /opt/datn-t1105/datn-t1105.service /opt/datn-t1105/datn-t1105.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now datn-t1105.timer
systemctl is-active datn-t1105.timer
systemctl show datn-t1105.service -p Result -p ExecMainStatus
journalctl -u datn-t1105.service --no-pager -n 30
```

Timer chạy khoảng mỗi 60 giây, đọc tối đa 5.000 sự kiện Windows trong 10 phút, ghép Event 3 và 11 theo cùng host/ProcessGuid và cách nhau tối đa 60 giây. Rule chỉ khớp IP Kali `192.168.10.102`, cổng 8088 và đường dẫn tệp lab cố định. State `/opt/datn-t1105/state.json` chống gửi lặp cùng document; chỉ lưu sau khi Shuffle nhận webhook.

`scripts/create-t1105-shuffle-workflow.ps1` dùng action Telegram PB01 đã có để tạo workflow; ID được lưu tại `D:\DATN\private\t1105-shuffle-workflow-id.txt`. Workflow `c6af5a23-ec06-4792-bffa-b96661e3e4c0`, trigger `42b7915c-a4c0-4a6f-b9dc-14642d70a1b9`. Action Shuffle gửi Telegram; **quarantine không chạy bên trong action Shuffle**: responder trên Windows host đọc các execution đã `FINISHED`/`SUCCESS` rồi gọi VMware Tools. Shuffle lưu execution; responder lưu kết quả riêng, không có hệ thống incident chuyên dụng.

### 3.5. Host responder và quarantine guest

Chép `scripts/t1105-quarantine-lab.ps1` vào guest `C:\Windows\Temp\datn-t1105\quarantine.ps1`. Script chỉ xử lý tệp lab cố định, kiểm tra SHA-256 và từ chối symlink/reparse point, từ chối ghi đè tệp đích; di chuyển cùng volume tới quarantine, giới hạn ACL thư mục/tệp cho Administrators và SYSTEM. Metadata trong quarantine lưu SDDL ban đầu để phục hồi. Sau khi khôi phục, script kiểm tra hash và báo trạng thái. Tệp này là marker văn bản, không phải mẫu malware.

Trên Windows host, `scripts/t1105-host-responder.ps1` đăng nhập Shuffle bằng credential riêng của dự án và đọc execution khoảng 15 giây/lần. Nó chỉ chạy với workflow và các điều kiện lab cố định; từ chối event quá 10 phút và chống xử lý lại execution đã thành công. Credential guest lưu bằng DPAPI cho Windows user host trong `D:\DATN\private\t1105-windows-guest-credential.xml`; responder state ở `D:\DATN\private\t1105-responder-state.json`. Giá trị password không nằm trong script/repository. `vmrun` nhận credential khi gọi guest, nên quyền trên host và quyền đọc process phải được quản lý phù hợp.

Để tạo credential cho user host đang đăng nhập, dùng `Get-Credential`, sau đó `Export-Clixml` vào đúng đường dẫn trên và giới hạn ACL cho user đó. DPAPI file chỉ giải mã được dưới cùng user/máy. Task Scheduler host `DATN-T1105-Responder` đã đăng ký `AtLogOn`, `Interactive`, `Limited`, `IgnoreNew`; script có mutex chống hai instance cùng session. Task đã được khởi chạy thủ công, báo Running và thực hiện thành công lượt Atomic `06:24`; **chưa kiểm thử trigger khi đăng xuất/khởi động lại host**. Host, Windows guest và EC2 cần hoạt động để action chạy. Kiểm tra:

```powershell
$credential = Get-Credential -Message 'Windows 10 guest account'
$credential | Export-Clixml -LiteralPath 'D:\DATN\private\t1105-windows-guest-credential.xml'
# Giới hạn ACL của file này cho Windows user đang đăng nhập trước khi tiếp tục.
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$exe = (Get-Command pwsh).Source
$argument = '-NoProfile -File "D:\DATN\github\DATN-MITRE-ATTACK-SOAR-update\scripts\t1105-host-responder.ps1"'
$action = New-ScheduledTaskAction -Execute $exe -Argument $argument
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName 'DATN-T1105-Responder' -Action $action -Trigger $trigger -Principal $principal -Settings $settings
Start-ScheduledTask -TaskName 'DATN-T1105-Responder'
Get-ScheduledTask -TaskName 'DATN-T1105-Responder' | Select-Object TaskName,State
Get-Content 'D:\DATN\work\t1105-responder.log' -Tail 20
```

Chỉ đăng ký task khi tên trên chưa tồn tại; nếu đã tồn tại, kiểm tra action và principal trước khi cập nhật. Trên host hiện tại task đã được tạo, không chạy lại `Register-ScheduledTask` để tạo bản trùng.

Khôi phục tệp lab từ Windows guest bằng PowerShell administrator:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\datn-t1105\quarantine.ps1 -Action Restore
Get-Content C:\Windows\Temp\datn-t1105\response.json
```

Nếu đường dẫn gốc đã tồn tại, script từ chối ghi đè. Khôi phục ở lượt nghiệm thu được gọi thủ công và không tự gửi Telegram.

## 4. Bằng chứng kiểm thử

Tất cả timestamp trong bảng là UTC; cộng 7 giờ để được giờ Việt Nam.

| Kiểm thử | Kết quả và bằng chứng |
|---|---|
| Atomic upstream PowerShell | `T1105-10`, prerequisite đạt, exit 0; tải marker hash đúng. Log `D:\DATN\work\t1105-atomic-final.log`. Lượt sau VM resume có Event 3 ProcessGuid rỗng, nên không được detector ghép. |
| Atomic DATN mở rộng | Bắt đầu `06:19:07.973Z`, kết thúc `06:19:23.469Z`, prerequisite đạt, exit 0; hash tải khớp. Log `D:\DATN\work\t1105-atomic-auto-final.log`. |
| Elasticsearch | Event 11 lúc `06:19:10.455Z`, document `Pzk2paEBjq1c1Lt1JhV_`; Event 3 document `eDk2paEBjq1c1Lt1KBWP`; cùng ProcessGuid `{0EEBFC29-CE5E-6AEA-8D04-000000000D00}`. |
| Timer + Shuffle | Timer lúc `13:19:52–13:19:54` ICT đọc 2 finding trong cửa sổ, gửi 1 event mới, không gửi lại event cũ. Execution `91733961-1d04-4352-bcb3-32e0e9853155` FINISHED, action SUCCESS, Telegram `ok=true`. |
| Cách ly tự động | Responder đang chạy nền xử lý execution trên lúc `13:20:22` ICT; guest báo `06:20:21.080Z`, `Quarantine/SUCCESS`, nguồn không còn, tệp quarantine tồn tại, hash khớp. Bằng chứng thời điểm này nằm trong `D:\DATN\work\t1105-responder.log`. File `t1105-quarantine-result.json` là kết quả mới nhất và sẽ bị ghi đè ở lần xử lý sau. |
| Kết quả Telegram | Execution `78f26c52-de3b-4ed6-9a5c-c0f7321be00e` FINISHED, action SUCCESS, Telegram `ok=true`, `QUARANTINE_VERIFIED`, `QUARANTINED`. |
| Restore | `06:20:42.401Z`, `Restore/SUCCESS`, nguồn tồn tại, quarantine không còn, SHA-256 khớp; `D:\DATN\work\t1105-restore-auto-final.json`. |
| Hash sai | `D:\DATN\work\t1105-hash-guard-test.json`: PASS, guest exit 1, từ chối do hash không khớp; tệp gốc được khôi phục. |
| Task Scheduler host | Atomic mở rộng bắt đầu `06:24:44.648Z`, kết thúc `06:24:59.995Z`, exit 0. Event 11 `8Tk7paEBjq1c1Lt1TxbR` và Event 3 `yjk7paEBjq1c1Lt1TxbB` có cùng ProcessGuid `{0EEBFC29-CFAE-6AEA-9F04-000000000D00}`. Timer gửi 1 finding mới; responder chạy dưới task `DATN-T1105-Responder` cách ly lúc `06:25:35.907Z`; execution phát hiện `ad252c18-7389-46b5-93de-dd6aecdb6c81`; execution kết quả `04659685-ece8-41cb-bbf9-34e7d048b202` FINISHED, Telegram `ok=true`. Restore thủ công `06:25:59.425Z`, hash khớp. Bằng chứng: `t1105-atomic-task-final.log`, `t1105-quarantine-task-final.json`, `t1105-restore-task-final.json` trong `D:\DATN\work`. |

Một lượt trước có execution `ddd5870d-06cb-4216-ba0f-0e1f9fc635ba` đã cách ly và restore thành công nhưng responder được chạy `-Once` thủ công để sửa lỗi xử lý thời gian; lượt `91733961-...` trên là lượt responder nền được khởi động trước Atomic, không gọi cách ly thủ công.

## 5. Sự cố và giới hạn

- Khi EC2 khởi động lại, SSH/Shuffle/Logstash có thời gian timeout hoặc HTTP 502; timer T1105 ghi HTTP 401 lúc Elastic chưa sẵn sàng, sau đó tự chạy thành công. Responder được bổ sung retry đăng nhập sau lỗi 502. Không nên xem một lượt thất bại trong thời gian khởi động là bằng chứng hệ thống ổn định qua mọi gián đoạn.
- PowerShell `ConvertFrom-Json` chuyển timestamp ISO thành `DateTime` UTC. Chuyển nó lần nữa bằng `DateTimeOffset.Parse` khiến PowerShell dùng giờ địa phương và tính lệch 7 giờ. Đã sửa thành ép kiểu `DateTimeOffset` khi giá trị đã là `DateTime`; vẫn giữ điều kiện event không quá 10 phút.
- Kết nối Sysmon có thể mang GUID rỗng hoặc bị mất khi process thoát nhanh; detector yêu cầu GUID thực khớp, nên bỏ sót trường hợp đó. Bài DATN giữ process sống thêm để chứng minh đường đi; đây không phải lời giải tổng quát.
- Rule chỉ bao phủ marker, IP và port lab cố định; hash được xác minh bởi guest. Không suy rộng thành detector/quarantine malware đa dụng. Rule bỏ qua các hành vi ngoài scope, hơn 5.000 event trong 10 phút hoặc sự kiện đến trễ quá 10 phút có thể bị bỏ sót.
- Webhook Shuffle dùng HTTP và không có xác thực riêng; actor có thể gửi payload giả. Chặn theo host/IP/path/hash chỉ giảm tác động trong lab, không thay thế xác thực, mã hóa, phân quyền và phê duyệt cho hệ thống thật. Token Telegram được kế thừa từ workflow cũ; không export workflow thô có secret.
- Nếu host ngủ, user host chưa đăng nhập, Kali/guest tắt, EC2 gián đoạn hoặc Shuffle lỗi thì phản ứng có thể không chạy. Khi khởi động lại chưa được nghiệm thu; cần vận hành và giám sát từng service. Một notification `pending` không chứng minh quarantine.
- Thao tác chỉ di chuyển đúng marker, không ngăn tiến trình đã chạy hay cô lập endpoint. Restore sau thử nghiệm là thủ công. Chức năng incident là Shuffle execution + nhật ký, không có case management chuyên dụng.

## 6. Khôi phục cấu hình

1. Dừng automation: trên EC2 `sudo systemctl disable --now datn-t1105.timer`; trên host `Stop-ScheduledTask -TaskName DATN-T1105-Responder` rồi `Disable-ScheduledTask -TaskName DATN-T1105-Responder` để không tự chạy lại lúc đăng nhập. Không xóa state hoặc log khi còn cần bằng chứng.
2. Nếu marker còn trong quarantine, dùng `-Action Restore` như trên và kiểm tra hash; không ghi đè file gốc đã tồn tại.
3. Trên Windows guest có thể phục hồi `winlogbeat-before.yml` từ `C:\Windows\Temp\datn-t1105` rồi restart Winlogbeat. Khôi phục Sysmon theo XML gốc đã lưu từ trước; lượt này trước đó là cấu hình mặc định T1059, có thể dùng `Sysmon64.exe -c --` để về mặc định. Kiểm tra lại T1059 sau khi đổi, tránh tắt logging chung.
4. Dừng HTTP server Kali khi không cần. Không xóa khóa, workflow hoặc dữ liệu tài khoản nếu chưa xác định ảnh hưởng đến các playbook khác.

## Nguồn

- [MITRE ATT&CK T1105](https://attack.mitre.org/techniques/T1105/)
- [Atomic Red Team T1105](https://github.com/redcanaryco/atomic-red-team/blob/master/atomics/T1105/T1105.md)
- [Microsoft Sysmon](https://learn.microsoft.com/en-us/sysinternals/downloads/sysmon)
- [Elastic Winlogbeat event logs](https://www.elastic.co/docs/reference/beats/winlogbeat/configuration-winlogbeat-options)
