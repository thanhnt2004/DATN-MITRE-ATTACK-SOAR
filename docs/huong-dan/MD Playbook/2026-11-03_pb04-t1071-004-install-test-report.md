# PB04 — T1071.004 Suspicious DNS Communication: cài đặt và nghiệm thu

Ngày kiểm thử: **03/11/2026** (ICT, UTC+7). Môi trường: DATN lab trên VMware Workstation và EC2 `18.139.50.205`. Bài tấn công dùng **Invoke-AtomicTest trên Kali** với Atomic mở rộng riêng cho lab, GUID `7ff17b4b-7cbf-48b7-97ab-0704d7c8d486`. Đây không phải bài Linux có sẵn trong upstream Atomic Red Team. Chỉ truy vấn các tên miền dưới `.test`; không truyền dữ liệu ra ngoài.

## Kết luận nghiệm thu

| Chặng | Bằng chứng và kết quả |
|---|---|
| VMware | pfSense WAN NAT, LAN VMnet10; Kali và Ubuntu cùng VMnet10. Ba VM chạy. |
| Atomic → DNS | Kali `192.168.10.102` gửi 30 truy vấn TXT tên dài, duy nhất qua pfSense `192.168.10.1`; bài Atomic exit 0. |
| Packetbeat → Logstash → Elasticsearch | Packetbeat 9.5.4 trên Kali `active`, kiểm tra config OK, TLSv1.3 tới `18.139.50.205:5044` và `talk to server... OK`. Có 30 DNS document của lượt Atomic trong `datn-dns-2026.11.03`. |
| Detector | 30 truy vấn/30 tên duy nhất trong 2 phút, tỷ lệ tên dài/TXT/NXDOMAIN đều 1, điểm rủi ro 100; một finding `REVIEW_DOMAIN_BLOCK`. Fixture, dưới ngưỡng và allowlist đã kiểm thử. |
| Shuffle → Telegram | Webhook HTTP 200; execution `31e4d55e-dd60-410d-9718-0185beef021d` `FINISHED`, action `SUCCESS`, Telegram `ok=true`. Trường `Hosts: kali` và các chỉ số là chuỗi hiển thị đầy đủ. |
| Chạy tự động | `datn-pb04.timer` `active`, service `Result=success`, `ExecMainStatus=0`. Lượt Atomic thứ hai tạo execution `bc3a18d4-5460-4a05-a233-b14216353f77`, Telegram `SUCCESS`. |
| pfSense DNS log → Ubuntu relay → Elasticsearch | Đã bật Unbound query logging và mục remote `DNS Events`. Tên thử `pb04-applied-20261103.pb04-probe.test` có trong Resolver log và document `pJ6XoaEB5OJCB0Fco3Vt` ở `datn-pfsense-2026.11.03`. |
| Phản ứng | **Phát hiện, đánh giá, thông báo**. `REVIEW_DOMAIN_BLOCK` là đề xuất để người quản trị quyết định; chưa thi hành chặn DNS/IP tự động. Trạng thái thực tế `DETECTED_NOTIFY_ONLY`. |

## Sơ đồ và cấu hình mạng

```text
Kali (VMnet10, 192.168.10.102)
  ├─ dig/Invoke-AtomicTest ──DNS/53──> pfSense LAN (192.168.10.1)
  └─ Packetbeat (eth0) ──Beats TLS/5044──> EC2 Logstash
pfSense Resolver ──remote syslog──> Ubuntu relay (VMnet10, 192.168.10.103)
Ubuntu Filebeat ──Beats TLS/5044──> EC2 Logstash
Logstash ──TLS──> Elasticsearch: datn-dns-*, datn-pfsense-*
EC2 datn-pb04.timer ──query/API key──> Elasticsearch
EC2 detector ──webhook──> Shuffle ──Telegram──> SOC bot
```

| Máy | Tệp VMX trên host | NIC đã kiểm tra | Vai trò |
|---|---|---|---|
| pfSense | `C:\Users\taola\OneDrive\Documents\Virtual Machines\FreeBSD version 10 and earlier 64-bit\FreeBSD version 10 and earlier 64-bit.vmx` | `ethernet0=nat` (WAN), `ethernet1=custom/VMnet10` (LAN) | Resolver và remote syslog |
| Kali 2025.4 | `D:\tool\Kali Linux\kali-linux-2025.4-vmware-amd64\kali-linux-2025.4-vmware-amd64.vmwarevm\kali-linux-2025.4-vmware-amd64.vmx` | `ethernet0=custom/VMnet10` | Atomic và Packetbeat |
| Ubuntu Server | `D:\tool\Ubutu server\Ubuntu Server.vmx` | `ethernet0=custom/VMnet10` | Nhận pfSense syslog tại UDP 5514; Filebeat relay |

Kali dùng gateway/DNS `192.168.10.1`; Ubuntu có hostname `prod-web-01`. EC2 chạy ELK, Shuffle và detector. Máy Windows host không truy cập trực tiếp WebGUI `192.168.10.1:80`; thao tác pfSense được chạy từ Kali trên VMnet10. Cấu hình Ubuntu relay/Filebeat đã tồn tại trước PB04; lượt kiểm thử này **xác minh** nhánh log pfSense đến Elasticsearch bằng document thật, không cài lại Ubuntu hay đổi mật khẩu VM.

## Thành phần được lưu trong repository

| Thành phần | Tệp |
|---|---|
| Bài Atomic Linux, script tạo DNS | [`T1071.004.yaml`](../atomic-red-team/test-cases/T1071.004/T1071.004.yaml), [`pb04-dns-burst.sh`](../atomic-red-team/test-cases/T1071.004/src/pb04-dns-burst.sh) |
| Script chạy Invoke-AtomicTest | [`pb04-kali-run-atomic.ps1`](../scripts/pb04-kali-run-atomic.ps1) |
| Cấu hình Packetbeat live và script cài | [`packetbeat-pb04-logstash.yml`](../agents/kali/packetbeat-pb04-logstash.yml), [`pb04-kali-configure-logstash.sh`](../scripts/pb04-kali-configure-logstash.sh) |
| Capture cục bộ để tạo fixture | [`packetbeat-pb04-local.yml`](../agents/kali/packetbeat-pb04-local.yml), [`pb04-kali-configure-local.sh`](../scripts/pb04-kali-configure-local.sh), [`pb04-extract-fixture.py`](../scripts/pb04-extract-fixture.py), [`pb04-dns-fixture.jsonl`](../atomic-red-team/test-cases/pb04-dns-fixture.jsonl) |
| Logstash route, index template, API key | [`pb04-patch-live-logstash.py`](../scripts/pb04-patch-live-logstash.py), [`pb04-create-index-template.py`](../scripts/pb04-create-index-template.py), [`pb04-ec2-api-key.py`](../scripts/pb04-ec2-api-key.py) |
| Detector, chạy định kỳ, kiểm tra ES | [`pb04_dns_detector.py`](../scripts/pb04_dns_detector.py), [`datn-pb04.service`](../scripts/datn-pb04.service), [`datn-pb04.timer`](../scripts/datn-pb04.timer), [`pb04-ec2-evidence.py`](../scripts/pb04-ec2-evidence.py) |
| Shuffle workflow, pfSense query logging, relay check | [`create-pb04-shuffle-workflow.ps1`](../scripts/create-pb04-shuffle-workflow.ps1), [`pb04-pfsense-enable-dns-logging.py`](../scripts/pb04-pfsense-enable-dns-logging.py), [`pb04-check-pfsense-relay.py`](../scripts/pb04-check-pfsense-relay.py) |

## Cài đặt lại từng chặng

### 1. Khởi động và kiểm tra VMware

Trong PowerShell của host, khai báo các đường dẫn VMX trong bảng trên và chạy `vmrun start` cho pfSense, Ubuntu, Kali. Kiểm tra `vmrun list` và `vmrun getGuestIPAddress <vmx>`. Trên Kali chạy `ip -4 addr show eth0`, `ip route`, `dig @192.168.10.1 pb04-preflight.test TXT +time=2 +tries=1`. Truy vấn `.test` trả NXDOMAIN vẫn chứng minh resolver nhận và trả lời. Cần giữ NIC Kali/Ubuntu trên VMnet10 và pfSense LAN trên VMnet10; cấu hình WAN pfSense đang là NAT.

### 2. Cài Packetbeat trên Kali

1. Tải `packetbeat-9.5.4-amd64.deb` và file `.sha512` cùng phiên bản từ Elastic. Gói đã dùng có kích thước **45,483,826 byte**, SHA512:

   ```text
   30E61C4B888C7D0D001CA6B41E9A221FA28A3E4E5EC342291C8A6D4B5FC71D65B50508450CADA3C941C04A0FE862E42D69AEEC54591BF1CCB14AB75F65ECD590
   ```

   So sánh `Get-FileHash -Algorithm SHA512` với file checksum trước khi chép vào Kali. Trong lượt cài này, host tải gói vì Kali không phân giải được `artifacts.elastic.co` qua pfSense ở thời điểm đó.
2. Dùng `vmrun -T ws -gu kali -gp kali CopyFileFromHostToGuest <Kali.vmx> <gói.deb> /tmp/packetbeat-9.5.4-amd64.deb`; trong Kali chạy `sudo dpkg -i /tmp/packetbeat-9.5.4-amd64.deb`.
3. Lấy CA Logstash đang chạy từ EC2 `/opt/elk/logstash/certs/ca.crt`, chép vào Kali `/tmp/pb04-logstash-ca.crt`. Chép cấu hình repo [`packetbeat-pb04-logstash.yml`](../agents/kali/packetbeat-pb04-logstash.yml) vào `/tmp/packetbeat-pb04-logstash.yml` và script cài vào `/tmp/pb04-kali-configure-logstash.sh`.
4. Trong Kali chạy `PB04_SUDO_PASSWORD=<mật khẩu sudo Kali> bash /tmp/pb04-kali-configure-logstash.sh`. Script đặt CA ở `/etc/packetbeat/certs/ca.crt`, config ở `/etc/packetbeat/packetbeat.yml`, kiểm tra config và khởi động lại dịch vụ. Cấp biến mật khẩu qua môi trường phiên shell, không lưu vào repo. Kiểm tra:

   ```bash
   systemctl is-active packetbeat
   sudo packetbeat test config -c /etc/packetbeat/packetbeat.yml
   sudo packetbeat test output -c /etc/packetbeat/packetbeat.yml
   ```

   Kết quả cuối: `active`, `Config OK`, xác thực certificate chain bật, TLSv1.3 handshake và `talk to server... OK`. Cấu hình bắt DNS/53 trên `eth0`, gắn `fields.log_source: pb04-dns`, gửi đến EC2 `18.139.50.205:5044`.

### 3. Logstash và Elasticsearch trên EC2

1. Pipeline live là `/opt/elk/logstash/pipeline/logstash.conf`. Script [`pb04-patch-live-logstash.py`](../scripts/pb04-patch-live-logstash.py) chỉ chèn nhánh `fields.log_source == "pb04-dns"` → `[@metadata][target_index] = datn-dns` trước nhánh Ubuntu, giữ nguyên các nhánh khác. Chép script lên EC2 và chạy với quyền sửa pipeline; bản sao lưu nằm tại `/opt/elk/logstash/logstash.conf.pre-pb04` **ngoài** thư mục pipeline. Khởi động lại Logstash, kiểm tra `curl -f http://127.0.0.1:9600/_node/pipelines` và nhật ký `Pipeline started`.
2. Đặt biến `PB04_ES_URL=https://127.0.0.1:9200`, `PB04_ES_CA=/opt/elk/elasticsearch/certs/ca/ca.crt`, `PB04_BOOTSTRAP_USER`, `PB04_BOOTSTRAP_PASSWORD` từ kho bí mật của máy, rồi chạy [`pb04-create-index-template.py`](../scripts/pb04-create-index-template.py). Template `datn-dns-pb04`, pattern `datn-dns-*`, priority 250, đã trả `template_acknowledged=True`.
3. Tạo workflow Shuffle ở bước 4 trước để có webhook. Đặt thêm `PB04_SHUFFLE_WEBHOOK`, chạy [`pb04-ec2-api-key.py`](../scripts/pb04-ec2-api-key.py). API key ID `7Z6LoaEB5OJCB0FcEEut` chỉ có `read` và `view_index_metadata` trên `datn-dns-*`. Giá trị key và webhook nằm trong `/opt/datn-pb04/pb04.env`, quyền `0600`; tài liệu không chứa secret.
4. Chép [`pb04_dns_detector.py`](../scripts/pb04_dns_detector.py) vào `/opt/datn-pb04/`; chép hai systemd unit vào `/etc/systemd/system/`, sau đó chạy:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now datn-pb04.timer
   systemctl is-active datn-pb04.timer
   systemctl show datn-pb04.service -p Result -p ExecMainStatus
   ```

   Timer gọi detector khoảng mỗi 60 giây. Detector truy vấn `datn-dns-*` trong 3 phút gần nhất bằng API key, gom theo IP nguồn và registered domain theo cửa sổ trượt 2 phút. Điều kiện: ít nhất **20 truy vấn**, **20 qname khác nhau**, **80% tên dài từ 60 ký tự**, điểm từ 80. Điểm cộng cho tỷ lệ NXDOMAIN/TXT; điểm 90 trở lên gắn `REVIEW_DOMAIN_BLOCK`. Có `--allow-ip`, `--allow-domain`, chống gửi lặp 5 phút theo IP/domain. Webhook chỉ được gửi khi `--send` và có state file.

### 4. Shuffle và Telegram

Chạy [`create-pb04-shuffle-workflow.ps1`](../scripts/create-pb04-shuffle-workflow.ps1) trên host. Script đọc credential Shuffle từ `D:\DATN\private\2026-10-15_credentials-ec2-elk-shuffle-report.md`, tạo workflow từ action Telegram PB01, lưu ID vào `D:\DATN\private\pb04-shuffle-workflow-id.txt`. Workflow hiện tại `b2619cff-1982-4699-8c1f-e00595f10104`; trigger `beecb830-5912-4532-b667-f74c2d8ca0da`. Chạy lại script sẽ cập nhật workflow theo ID, tránh tạo bản trùng.

Webhook nhận các trường vô hướng như `source_ip`, `registered_domain`, `query_count`, `distinct_qname_count`, các tỷ lệ, `risk_score`, `decision`, `hosts_text`, `test_id`, `status`. Telegram dùng mẫu ASCII `[PB04] ...`, và dùng `hosts_text` thay cho mảng `hosts` để không gặp lỗi cắt tin ở dấu `[`. Template không có emoji nên tránh lỗi ký tự `�` từng gặp ở PB01. Bot token được kế thừa từ action PB01 và nằm trong Shuffle; không export workflow hoặc đưa token vào tài liệu công khai.

### 5. Bật và kiểm tra log DNS pfSense

Từ Kali, chạy [`pb04-pfsense-enable-dns-logging.py`](../scripts/pb04-pfsense-enable-dns-logging.py) với `PFSENSE_USER` và `PFSENSE_PASSWORD` trong môi trường phiên shell. Script đăng nhập WebGUI `http://192.168.10.1`, giữ các trường cấu hình hiện hữu, thêm Unbound Custom Options:

```text
server:
log-queries: yes
```

Script nhấn **Apply Changes** thực sự trên form riêng của pfSense và bật `DNS Events` ở remote syslog. Kết quả sau sửa: `unbound_query_logging=true`, `unbound_apply_pending=false`, `remote_dns_events=true`. Tạo tên thử bằng `dig @192.168.10.1 pb04-applied-20261103.pb04-probe.test TXT`. Log `Status > System Logs > DNS Resolver` có tên thử. Trên EC2, [`pb04-check-pfsense-relay.py`](../scripts/pb04-check-pfsense-relay.py) truy vấn `datn-pfsense-*` cho marker này; kết quả 1 document `pJ6XoaEB5OJCB0Fco3Vt`, lúc `2026-11-03T13:27:16.027Z`, `log_source=pfsense`. Ubuntu `192.168.10.103` là relay hiện có; chưa thay đổi cấu hình nó trong lượt này.

### 6. Cài Atomic và chạy thử

Trên Kali cần `pwsh`, module `Invoke-AtomicRedTeam` và `dig` (`dnsutils`). Lượt PB01 trước đã cài PowerShell và module; PB04 đã kiểm tra và dùng lại. Chép `T1071.004.yaml` và `src/pb04-dns-burst.sh` vào `/home/kali/AtomicRedTeam/atomics/T1071.004/`. Chạy script repo [`pb04-kali-run-atomic.ps1`](../scripts/pb04-kali-run-atomic.ps1) bằng `pwsh -NoProfile -File ...`; script kiểm tra prerequisite rồi chạy đúng GUID. Lệnh tương đương:

```powershell
Import-Module Invoke-AtomicRedTeam
Invoke-AtomicTest T1071.004 -TestGuids 7ff17b4b-7cbf-48b7-97ab-0704d7c8d486 -PathToAtomicsFolder /home/kali/AtomicRedTeam/atomics -CheckPrereqs -Confirm:$false
Invoke-AtomicTest T1071.004 -TestGuids 7ff17b4b-7cbf-48b7-97ab-0704d7c8d486 -PathToAtomicsFolder /home/kali/AtomicRedTeam/atomics -Confirm:$false
```

Lệnh tạo mặc định 30 tên dài TXT dưới `pb04-datn.test`, trả lời NXDOMAIN. Script giới hạn 1–100 truy vấn và bắt buộc hậu tố `.test`. Có thể truyền `-Domain pb04-auto.test` vào wrapper để tạo lượt riêng cho timer.

## Bằng chứng nghiệm thu ngày 03/11/2026

| Kiểm thử | Kết quả |
|---|---|
| Capture cục bộ ban đầu | 30 sự kiện DNS thật trong 670 sự kiện Packetbeat cục bộ. Từ đó trích fixture 30 dòng đã lọc, không tự dựng sự kiện giả cho ca dương tính. |
| Fixture detector | 30 dòng → 1 finding; chỉ 10 dòng → 0; allowlist IP hoặc domain → 0. |
| Atomic live | Bắt đầu `13:18:30Z`; 30 DNS document trong `datn-dns-2026.11.03`, từ `13:18:30.387Z` đến `13:18:36.810Z`. `source.ip=192.168.10.102`, `host.name=kali`, `dns.question.etld_plus_one=pb04-datn.test`, `dns.response_code=NXDOMAIN`, `dns.question.type=TXT`. Sample document IDs `HJ6PoaEB5OJCB0Fcp1-W`, `G56PoaEB5OJCB0Fcp1-W`, `GJ6PoaEB5OJCB0Fcp1-W`. |
| Phát hiện và gửi thủ công từ log live | 30/30 qname, `risk_score=100`, 1 finding, `http_status=200`, `accepted=true`, `notifications_sent=1`; test ID `PB04-ATOMIC-20261103-131830Z`. Shuffle execution `31e4d55e-dd60-410d-9718-0185beef021d` `FINISHED`, Telegram `SUCCESS`, `ok=true`. |
| Lượt tự động | Atomic thứ hai dưới `pb04-auto.test`: 30 truy vấn. Timer lúc `13:19:59Z` tạo 1 finding, webhook HTTP 200, `notifications_sent=1`; execution `bc3a18d4-5460-4a05-a233-b14216353f77` `FINISHED`, Telegram `SUCCESS`, `ok=true`, test ID `PB04-AUTO`. |
| Chống lặp | Cùng IP/domain trong 5 phút tiếp theo ghi `notification_suppressed=duplicate_window`; tên miền thứ hai vẫn tạo cảnh báo riêng. |
| pfSense relay | Resolver log có marker `pb04-applied-20261103`; Elasticsearch `datn-pfsense-2026.11.03` trả 1 document đúng marker, ID `pJ6XoaEB5OJCB0Fco3Vt`. |
| Kiểm tra vận hành cuối | Kali Packetbeat `active`, `Config OK`, TLSv1.3/talk to server OK; EC2 Logstash API 200; `datn-pb04.timer=active`, service `Result=success`, `ExecMainStatus=0`. |

## Sự cố trong lúc cấu hình và cách khắc phục

- Lần sửa Logstash đầu đặt bản sao `logstash.conf.pre-pb04` **trong** `/opt/elk/logstash/pipeline/`. Logstash tải cả hai file cấu hình, trùng input ID `datn-beats-tls`, nên pipeline không khởi động. Đã chuyển bản sao ra `/opt/elk/logstash/logstash.conf.pre-pb04`, cập nhật script và khởi động lại. API pipeline HTTP 200, nhật ký `Pipeline started` lúc `13:16:36Z`, Packetbeat test output sau đó OK. Không để file backup/temporary có đuôi `.conf` trong thư mục pipeline.
- Ban đầu Unbound đã lưu `log-queries: yes` nhưng banner **Apply Changes** còn hiện, nên tên thử không xuất hiện ở Resolver log hoặc Elasticsearch. Script đã sửa để lấy CSRF của nút Apply riêng, POST apply và kiểm tra hết pending. Truy vấn mới sau đó vào cả log pfSense lẫn `datn-pfsense-*`.
- Một lượt Atomic được chạy khi Logstash còn backlog do sự cố trên, nên không dùng lượt đó làm bằng chứng end-to-end. Lượt `13:18:30Z` sau khi pipeline ổn định là lượt nghiệm thu live.

## Giới hạn và vận hành

- Playbook này phát hiện mẫu **burst DNS tên dài, nhiều tên khác nhau** phù hợp kênh DNS bất thường; nó không chứng minh dữ liệu đã bị đánh cắp. `NXDOMAIN` dưới `.test` được dùng để kiểm thử an toàn. Ngưỡng 20/2 phút và điểm 80 là ngưỡng lab, cần baseline trước môi trường thật.
- `REVIEW_DOMAIN_BLOCK` chỉ là quyết định đề xuất. Chưa có nhánh Shuffle gọi pfSense để chặn; không ghi nhận khả năng chặn tự động là đã nghiệm thu. Chặn IP đích DNS `192.168.10.1` sẽ cắt resolver chung của lab, nên không được làm cho bài thử này.
- Detector lấy tối đa 5.000 event DNS gần nhất trong 3 phút. Nếu tải thực vượt mức này, cần phân trang hoặc Elasticsearch aggregation để không bỏ sót cửa sổ cũ. Đường webhook Shuffle hiện dùng HTTP trên mạng lab; bot token còn trong action Shuffle gốc. Cần HTTPS, bí mật quản lý riêng và giới hạn Security Group theo IP nguồn trước khi mở ra ngoài lab.
- Security Group trong ảnh cung cấp cho phiên này cho phép `22`, `3001`, `5044`, `5601` từ `0.0.0.0/0`. Lượt triển khai này không sửa Security Group; nên giới hạn nguồn theo IP lab/quản trị sau khi xác nhận đường truy cập vận hành.

## Tham khảo kỹ thuật

- [MITRE ATT&CK T1071.004 — DNS](https://attack.mitre.org/techniques/T1071/004/)
- [Atomic Red Team upstream T1071.004](https://github.com/redcanaryco/atomic-red-team/blob/master/atomics/T1071.004/T1071.004.md)
- [Invoke-AtomicRedTeam: chạy theo GUID và custom atomics folder](https://github.com/redcanaryco/invoke-atomicredteam/wiki/Execute-Atomic-Tests-%28Local%29)
- [Elastic Packetbeat DNS protocol](https://www.elastic.co/docs/reference/beats/packetbeat/packetbeat-dns-options)
- [Elastic Packetbeat TLS với Logstash](https://www.elastic.co/docs/reference/beats/packetbeat/configuring-ssl-logstash)
- [Netgate: ghi log truy vấn DNS Resolver](https://docs.netgate.com/pfsense/en/latest/troubleshooting/dns-queries.html)
- [Netgate: remote syslog DNS Events](https://docs.netgate.com/pfsense/en/latest/monitoring/logs/remote.html)
