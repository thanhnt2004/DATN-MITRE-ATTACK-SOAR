# Kế hoạch đồ án – 12 tuần / 2 người

## Stack
ELK SIEM + Sigma + Atomic Red Team + Shuffle SOAR.

## Mục tiêu cốt lõi
Xây dựng pipeline có thể kiểm thử lặp lại:
```text
Attack → Detect → Alert → Automate → Respond → Measure
```

## Phạm vi
- 8–10 MITRE ATT&CK techniques.
- 15–20 Sigma/Elastic Detection Rules.
- 15–20 Atomic Red Team test cases.
- 6–8 Shuffle playbooks.
- Đo Detection Rate, FP/FN, MTTD, MTTR, Automation Rate, Playbook Success Rate và ATT&CK Coverage.

## Phân công
### Người 1 – SIEM & Detection
ELK, log pipeline, Sigma, ATT&CK mapping, Atomic validation.

### Người 2 – SOAR & Automation
Shuffle, webhook/API, playbook, response và đo chỉ số.

Cả hai cùng chịu trách nhiệm kiến trúc, ATT&CK scope, test matrix, thực nghiệm, báo cáo và demo.

## Workstreams
1. Infrastructure & Logging.
2. Detection Engineering.
3. Attack Simulation.
4. SIEM → SOAR Integration.
5. SOAR Playbook.
6. Evaluation.

## Mốc 12 tuần
- Tuần 1: kiến trúc, ATT&CK shortlist, backlog.
- Tuần 2: ELK + Shuffle chạy độc lập.
- Tuần 3: log pipeline và alert schema v1.
- Tuần 4: demo Atomic → ELK → Alert → Shuffle.
- Tuần 5–6: hoàn thiện detection và integration.
- Tuần 7–8: hoàn thiện 6–8 playbook.
- Tuần 9: hardening, xử lý FP/FN, timeout/API failure.
- Tuần 10: end-to-end test.
- Tuần 11: evaluation manual vs SOAR.
- Tuần 12: tối ưu, đóng gói, demo và báo cáo.

## ATT&CK shortlist đề xuất
T1059.001 PowerShell, T1053.005 Scheduled Task/Job, T1547.001 Registry Run Keys, T1087 Account Discovery, T1018 Remote System Discovery, T1047 WMI, T1105 Ingress Tool Transfer, T1110 Brute Force, T1003 Credential Dumping (lab-safe), T1036 Masquerading (optional).

## Playbook dự kiến
PB01 PowerShell Investigation  
PB02 Brute Force  
PB03 Scheduled Task Persistence  
PB04 Registry Persistence  
PB05 Discovery Activity  
PB06 WMI Investigation  
PB07 Ingress Tool Transfer / IOC Triage  
PB08 Credential Access Triage

Response rủi ro phải có analyst approval.

## Ưu tiên
- P0: ELK + log → Atomic → Detection → ELK/Shuffle integration → 6 playbook → Evaluation.
- P1: FP tuning, ATT&CK dashboard, enrichment đơn giản, analyst approval.
- P2: MISP/TheHive, advanced correlation, CI/CD detection-as-code khi còn thời gian.

Feature freeze cuối tuần 9; tuần 10–12 tập trung test, measure, fix và chuẩn bị bảo vệ.
