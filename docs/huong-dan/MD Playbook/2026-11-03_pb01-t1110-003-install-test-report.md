# PB01 — MITRE ATT&CK T1110.003 Password Spraying

> **Bản cũ tại thời điểm chưa có credential.** Xem [báo cáo nghiệm thu đầu-cuối đã cập nhật](../../2026-11-03_pb01-t1110-003-install-test-report.md). Nội dung bên dưới chỉ giữ lại lịch sử kiểm thử ban đầu.

Ngày: 03/11/2026. Trạng thái: **workflow Shuffle đã cài và kiểm thử bằng fixture; bài Atomic trên Kali và chuỗi Elastic → Shuffle chưa nghiệm thu**.

## 1. Kết quả hiện tại

| Thành phần | Kết quả |
|---|---|
| Rule cơ sở Windows/Linux | Đã tạo trong repository; chọn sự kiện thất bại, không tự kết luận spraying |
| Detector correlation | Đã tạo; ≥5 username khác nhau từ cùng IP trong 5 phút |
| Allowlist và chống lặp | Fixture cho 0 finding khi IP allowlist; lần gửi thứ hai trong 5 phút bị chặn |
| Shuffle PB01 | Workflow `2c92993a-4901-479c-a677-44bf2851186f`, trigger `b1b0832f-e1d8-43b8-b329-120addde42dd` |
| Telegram | Hai execution fixture `FINISHED`, action `SUCCESS`, API HTTP 200 và `ok=true` |
| Atomic Red Team | Đã tạo Atomic test mở rộng cho lab; **chưa chạy trên Kali** vì chưa xác minh được Invoke-AtomicTest/sshpass trong guest và chưa có guest login để thực thi |
| Elastic search/detection | Đã xác minh index bằng tài khoản `viewer` tạm: Ubuntu 7.004 document, chưa có “Failed password”; Windows có 6 event code 4625. Tài khoản tạm đã gỡ; chưa có reader credential bền vững để chạy detector và chưa cài rule tự động |
| Triển khai script trên EC2 | Script và fixture đã sao chép vào `/opt/datn-pb01`; Python 3.12 trên EC2 kiểm thử fixture cho 1 finding và allowlist cho 0 |

> Hai execution là kiểm thử kỹ thuật `synthetic-fixture`, không phải bằng chứng đã phát hiện một lượt password spraying thật. Workflow hiện chỉ cảnh báo, chưa chặn IP.

## 2. Tệp cài đặt

- Detector: [`../github/DATN-MITRE-ATTACK-SOAR-update/scripts/pb01_password_spraying.py`](../github/DATN-MITRE-ATTACK-SOAR-update/scripts/pb01_password_spraying.py)
- Script tạo/cập nhật workflow: [`../github/DATN-MITRE-ATTACK-SOAR-update/scripts/create-pb01-shuffle-workflow.ps1`](../github/DATN-MITRE-ATTACK-SOAR-update/scripts/create-pb01-shuffle-workflow.ps1)
- Atomic test mở rộng: [`../github/DATN-MITRE-ATTACK-SOAR-update/atomic-red-team/test-cases/T1110.003/T1110.003.yaml`](../github/DATN-MITRE-ATTACK-SOAR-update/atomic-red-team/test-cases/T1110.003/T1110.003.yaml)
- Danh sách năm username lab: [`../github/DATN-MITRE-ATTACK-SOAR-update/atomic-red-team/test-cases/T1110.003/src/lab_users.txt`](../github/DATN-MITRE-ATTACK-SOAR-update/atomic-red-team/test-cases/T1110.003/src/lab_users.txt)
- Rule cơ sở: [`../github/DATN-MITRE-ATTACK-SOAR-update/sigma/rules/pb01_password_spraying_windows.yml`](../github/DATN-MITRE-ATTACK-SOAR-update/sigma/rules/pb01_password_spraying_windows.yml) và [`../github/DATN-MITRE-ATTACK-SOAR-update/sigma/rules/pb01_password_spraying_linux.yml`](../github/DATN-MITRE-ATTACK-SOAR-update/sigma/rules/pb01_password_spraying_linux.yml)
- Fixture dùng riêng cho unit/integration test: [`../github/DATN-MITRE-ATTACK-SOAR-update/atomic-red-team/test-cases/pb01-password-spraying-fixture.jsonl`](../github/DATN-MITRE-ATTACK-SOAR-update/atomic-red-team/test-cases/pb01-password-spraying-fixture.jsonl)

Trong tổ chức Shuffle hiện tại, chạy `create-pb01-shuffle-workflow.ps1` sẽ cập nhật đúng ID `2c92993a-4901-479c-a677-44bf2851186f` và trả `existing=true`. Khi cài ở tổ chức mới, truyền `-TargetWorkflowId ''` **một lần** để tạo mới, lưu ID trả về rồi truyền ID đó cho những lần cập nhật sau. Script không còn tạo workflow mới khi một ID đã khai báo không tìm thấy.

## 3. Thiết kế phát hiện

```text
Atomic Red Team trên Kali
  → một mật khẩu sai / năm username lab / Ubuntu SSH
  → sshd auth.log
  → Filebeat → Logstash → datn-ubuntu-*
  → PB01 detector: source IP + distinct usernames + 5 phút
  → Shuffle webhook → Telegram
```

Detector cũng hỗ trợ Windows Event 4625 khi `source.ip`/`user.name` hoặc các trường Winlogbeat tương ứng có mặt. Một IP trong allowlist sẽ bị loại trước khi gửi. IP loopback/unspecified và sự kiện thiếu IP, user hoặc timestamp bị bỏ qua. Mỗi IP được giới hạn một thông báo trong năm phút nếu dùng `--state-file`.

Mẫu 4625 hiện đọc được từ `datn-windows-*` có `winlog.event_data` chỉ gồm `param1`, `param2`, `param3`, chưa chứng minh có IP và username đủ để correlate. Nhánh Windows cần kiểm tra Security channel và field mapping trước khi nghiệm thu. Nhánh Linux đọc được `message` thô từ Ubuntu và phù hợp với định dạng `sshd` mà Atomic mở rộng sẽ tạo.

**Ngưỡng đang dùng:** `distinct(user.name) >= 5` trong 5 phút theo `source.ip`. Đây là ngưỡng lab cần được điều chỉnh từ benign baseline trước khi dùng ngoài lab. Không ghi password trong log, alert hay Telegram.

## 4. Cài và chạy Atomic trên lab

Tệp test được viết theo cấu trúc Atomic Red Team/Invoke-AtomicTest, có GUID `9d3c97df-01f6-44b8-b28e-4a56e2d781eb`. Đây là **Atomic mở rộng riêng của DATN**, không phải bài test upstream của Red Canary. Các test upstream T1110.003 hiện nhắm AD, Azure hoặc AWS; lab DATN chưa xác nhận có AD. Xem [T1110.003 upstream](https://github.com/redcanaryco/atomic-red-team/blob/master/atomics/T1110.003/T1110.003.md) và [cách chỉ định custom atomics folder](https://github.com/redcanaryco/invoke-atomicredteam/wiki/Execute-Atomic-Tests-%28Local%29).

Trên Kali, đặt thư mục `test-cases` từ repository thành `/opt/datn/atomics`, cài `pwsh`/Invoke-AtomicRedTeam và `sshpass`. Trước khi thực thi, xác nhận Kali là `192.168.10.102`, Ubuntu là `192.168.10.103`, SSH chỉ mở trong VMnet10 và năm username trong `lab_users.txt` không thuộc tài khoản thật. Chạy:

```powershell
Import-Module Invoke-AtomicRedTeam
Invoke-AtomicTest T1110.003 -TestGuids 9d3c97df-01f6-44b8-b28e-4a56e2d781eb -PathToAtomicsFolder /opt/datn/atomics -CheckPrereqs
Invoke-AtomicTest T1110.003 -TestGuids 9d3c97df-01f6-44b8-b28e-4a56e2d781eb -PathToAtomicsFolder /opt/datn/atomics
```

Test chỉ thử một mật khẩu cố ý sai trên năm username không tồn tại, giãn cách hai giây. Không dùng danh sách tài khoản thật. Ghi thời gian UTC lúc bắt đầu/kết thúc và `test_id` của buổi chạy để đối chiếu với log.

## 5. Kiểm thử detector và Shuffle đã thực hiện

Từ thư mục repository trên Windows:

```powershell
py scripts/pb01_password_spraying.py --fixture atomic-red-team/test-cases/pb01-password-spraying-fixture.jsonl --attack-source synthetic-fixture --test-id PB01-FIXTURE
py scripts/pb01_password_spraying.py --fixture atomic-red-team/test-cases/pb01-password-spraying-fixture.jsonl --allow-ip 192.168.10.102 --test-id PB01-ALLOWLIST
```

Kết quả: tám event fixture sinh đúng một finding cho IP `192.168.10.102`, năm username khác nhau; allowlist sinh không finding. Gửi cùng fixture vào Shuffle hai lần với `--state-file`: lần đầu một notification, lần sau `notification_suppressed=duplicate_window`.

| Execution ID | Workflow | Action | Telegram |
|---|---|---|---|
| `e3cafd09-5e81-4074-9e2d-7e0745dfd190` | FINISHED | SUCCESS | HTTP 200, `ok=true` |
| `029eac0a-647e-4978-8948-bcf52a208acf` | FINISHED | SUCCESS | HTTP 200, `ok=true` |

Workflow sao chép Telegram action từ T1046. Bot token cũ vẫn nằm trong action và raw execution result có thể chứa URL nhạy cảm; cần xoay token và chuyển sang Shuffle Authentication trước khi đưa ra ngoài lab. Không export workflow thô lên Git.

Trong lúc cập nhật script, một workflow PB01 trùng tên chưa có execution được tạo nhầm do API danh sách không trả về workflow cũ. Webhook `830e1490-ddfe-4a92-a044-280d5740f78b` và workflow `d98ab45f-62e7-4b3c-9ca4-9f7b62e0a608` đã được xóa thành công. Script hiện tìm theo workflow ID `2c92993a-4901-479c-a677-44bf2851186f` và lượt chạy lại trả `existing=true`, không tạo bản trùng.

## 6. Cấu hình kết nối Elastic còn thiếu

Detector live cần tài khoản chỉ đọc trên `datn-ubuntu-*` và `datn-windows-*`. Tài khoản `kibana_system` chỉ thấy danh sách index; `_search` trả `0` shard vì không có quyền đọc document. Tài khoản ingest không được nâng quyền đọc. Chưa tìm thấy credential analyst/admin trong phụ lục dự án, `/opt/elk/.env` hoặc cấu hình container hiện tại; các file này chỉ chứa mật khẩu dịch vụ Kibana/Logstash. Một tài khoản file-realm `viewer` được tạo **tạm thời chỉ để đọc schema**, sau đó gỡ thành công (`No users found`). Không dùng tài khoản tạm này làm cấu hình vận hành.

Khi đã có reader credential, đặt các biến môi trường trong nơi lưu secret có quyền hạn chế (không ghi vào Git):

```text
PB01_ES_URL=https://127.0.0.1:9200
PB01_ES_USER=<reader user>
PB01_ES_PASSWORD=<reader password>
PB01_ES_CA=/opt/elk/elasticsearch/certs/ca/ca.crt
PB01_SHUFFLE_WEBHOOK=<PB01 webhook URL>
```

Sau đó chạy detector trên EC2 hoặc một host có đường mạng tới Elasticsearch và Shuffle:

```bash
python3 pb01_password_spraying.py --index 'datn-ubuntu-*,datn-windows-*' --test-id DATN_PB01_ATOMIC_20261103 --attack-source 'Atomic Red Team' --atomic-guid 9d3c97df-01f6-44b8-b28e-4a56e2d781eb --state-file /var/lib/datn-pb01/state.json --send
```

Lệnh này chỉ hợp lệ **sau khi Atomic đã chạy và log xác thực thật xuất hiện**. Không gắn nhãn Atomic cho fixture. Detector hiện là lệnh một lần, chưa được cài thành timer/service; không gọi đó là hệ thống giám sát liên tục.

## 7. Evidence → Finding → Path

| ID | Evidence |
|---|---|
| E-001 | Elasticsearch có index Ubuntu/Windows, nhưng truy vấn bằng tài khoản dịch vụ trả 0 searchable shard. |
| E-002 | Fixture 8 event cho một finding 5 username/5 phút; allowlist cho 0 finding. |
| E-003 | Hai lượt fixture → Shuffle kết thúc FINISHED, Telegram HTTP 200/`ok=true`. |
| E-004 | Atomic YAML và danh sách năm user đã tạo, nhưng chưa có execution trên Kali hoặc log sshd tương ứng. |
| E-005 | SCP tới EC2 bị đóng; kiểm tra kế tiếp cho thấy port 22 và 3001 đều timeout trong khi kết nối Internet chung vẫn có. |
| E-006 | Sau boot mới, SCP thành công; `python3 /opt/datn-pb01/pb01_password_spraying.py --fixture ...` trả 1 finding, chạy allowlist trả 0. SHA-256 script trên EC2: `344b1666b24a00bb9309e2a5744de56dd553be892abc3b4d04df52008d45bd22`. |
| E-007 | Truy vấn read-only bằng `viewer` tạm: `datn-ubuntu-*` 7.004 document, 0 match “Failed password”; `datn-windows-*` 6 match `event.code=4625`, mẫu `winlog.event_data` chỉ có `param1/2/3`. Tài khoản tạm đã gỡ. |

**F-001:** logic correlation, allowlist, chống lặp và đường Shuffle → Telegram đã được kiểm chứng bằng fixture (E-002, E-003).

**F-002:** chưa nghiệm thu attack → log → Elastic search → Shuffle; thiếu lượt Atomic thật và reader credential (E-001, E-004).

**F-003:** EC2 bị ngắt giữa lần SCP đầu, sau đó hồi phục. Journal cho thấy shutdown có trình tự lúc 10:11:48 ICT và boot mới lúc 13:59 ICT; không thấy OOM/panic trong các dòng kernel đã lọc. Lần SCP thứ hai thành công và detector chạy được trên EC2. Nguyên nhân shutdown chưa được xác định từ bằng chứng hiện có (E-005).

```text
P-001 đã xác minh: fixture auth failures → PB01 detector → Shuffle → Telegram
P-002 cần nghiệm thu: Atomic Kali → Ubuntu sshd → Filebeat/Logstash → Elastic → PB01 detector → Shuffle
```

## 8. Tiêu chí nghiệm thu đầu-cuối

1. `Invoke-AtomicTest` trên Kali thực hiện đúng GUID và tạo năm thất bại SSH trong tối đa năm phút.
2. Năm event trong `datn-ubuntu-*` có cùng `source.ip`, năm username khác nhau và thời gian đúng buổi test.
3. Detector tìm đúng một finding và gửi một webhook; chạy lại trong năm phút không tạo thêm execution.
4. Shuffle execution `FINISHED`, Telegram action `SUCCESS`, HTTP 200/`ok=true`.
5. Một test benign dưới ngưỡng và một test allowlist không tạo notification.
6. Có timestamp/ID để tính MTTD, MTTR và liên kết Atomic execution → log document → Shuffle execution.

Chỉ sau khi sáu điều kiện này đạt mới ghi PB01 là “hoạt động ổn định”.
