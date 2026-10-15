# Kiểm tra ELK và Shuffle ngày 15/10/2026

Chiều 15/10, mình vào EC2 kiểm tra lại ELK và Shuffle, sau đó bật các máy ảo trong lab để xem log có về thật không. Kết quả ngắn gọn: **ELK nhận log Ubuntu bình thường; Shuffle đăng nhập được nhưng chưa chạy được workflow.** Log Windows và pfSense vẫn cần kiểm tra tiếp.

## ELK và log Ubuntu

Elasticsearch trả lời API tìm kiếm, Kibana báo `available`, còn pipeline `main` của Logstash ở trạng thái `green`. Cluster Elasticsearch hiện `yellow` vì chỉ có một node và các replica chưa được gán; không có primary shard nào bị mất. Phần nhận và tra cứu log vẫn hoạt động, nhưng chưa kiểm thử trọn vẹn một detection rule tạo alert.

Sau khi bật Ubuntu Server, mình theo dõi index `datn-ubuntu-2026.10.15`: số bản ghi từ 164 tăng lên 2.225 lúc 14:26:02, rồi 2.227 lúc 14:26:55. Cùng thời điểm, thống kê Logstash ghi nhận 2.227 sự kiện vào/ra và một kết nối Beats còn mở. Như vậy đường **Filebeat trên Ubuntu → Logstash qua TLS → Elasticsearch** đã chạy trong buổi thử. Để kiểm lại, có thể xem `_count` của index trên Elasticsearch và `/_node/stats/pipelines/main` trên Logstash.

Kibana đã có data view cho Winlogbeat/Auditbeat, nhưng chưa có data view Ubuntu phù hợp để kiểm tra trực quan luồng mới. Đây là việc cần làm trước khi dựng dashboard và rule cho nguồn Ubuntu.

## Hai nguồn log chưa về như mong đợi

pfSense đã được bật, nhưng index `datn-pfsense-*` vẫn chỉ có hai bản ghi cũ. Đó là marker gửi thử từ Ubuntu relay, **chưa phải syslog thật từ pfSense**. Cần kiểm tra lại cấu hình Remote Logging trên pfSense, đường UDP tới rsyslog Ubuntu, rồi mới theo tiếp Filebeat và Logstash. [Hướng dẫn ingest hiện tại](2026-10-13-ubuntu-pfsense-log-ingestion.md) có sơ đồ và cấu hình liên quan.

Windows 10 được bật thử khoảng bốn phút. Trong khoảng đó, số bản ghi Winlogbeat/Auditbeat không tăng và Logstash cũng không thấy kết nối Beats mới từ máy Windows. Chưa đủ căn cứ để nói lỗi nằm ở agent hay mạng; bước tiếp theo là vào chính máy Windows xem dịch vụ Beats, cấu hình output/TLS và tạo một sự kiện thử để đối chiếu trên Elasticsearch. Dữ liệu Windows có từ ngày trước không chứng minh máy vẫn gửi log hôm nay.

Mình không để Windows chạy tiếp vì RAM máy host xuống còn khoảng 1 GiB khi chạy nhiều VM. Windows đã được tắt mềm; lúc kết thúc buổi thử, pfSense và Ubuntu Server vẫn bật. Các VM còn lại không được bật trong lần này.

## Shuffle: vào được giao diện, chưa chạy được playbook

Mình đăng nhập được Shuffle và vào dashboard. Backend và OpenSearch cũng trả lời, nhưng bài self-test của Shuffle báo `workflows.run=false`. Thông báo lỗi cụ thể là OpenSearch không cho đổi kiểu trường `workflow.actions.parameters.value` từ `date` sang `keyword`. Trong log Orborus còn có lỗi không tìm thấy network `shuffle_swarm_executions`, trong khi Docker Swarm đang inactive. Dashboard lúc kiểm tra chưa có workflow nào để chạy thử.

Vì vậy, hiện chỉ có thể nói **Shuffle đã lên giao diện và đăng nhập được**, chưa thể ghi là hệ thống SOAR hoạt động ổn định. Cần xử lý mapping/index và network dùng cho execution, sau đó tạo một workflow nhỏ, chạy thử và xem kết quả thực thi. Đường alert từ Elastic sang Shuffle cũng chưa được kiểm chứng.

## Việc nên làm tiếp

1. Ưu tiên sửa hai lỗi Shuffle, rồi chạy một workflow thử từ đầu đến cuối.
2. Vào Windows guest kiểm tra Beats và gửi một log mới; xác nhận bộ đếm index tăng.
3. Bật Remote Logging pfSense và xác nhận có log pfSense thật, không chỉ marker thử relay.
4. Tạo data view Ubuntu, kiểm thử rule → alert → Shuffle và rà soát quyền truy cập các UI/API.

Các số liệu trên được ghi trong khoảng 14:08–14:27 (giờ Việt Nam) ngày 15/10/2026, bằng API nội bộ trên EC2, Docker/Logstash metrics, VMware `vmrun` và giao diện Shuffle qua SSH tunnel. Đây là kết quả tại thời điểm thử, không phải cam kết hệ thống sẽ luôn ổn định. Không thay đổi cấu hình EC2 trong buổi kiểm tra. Repo này công khai nên thông tin đăng nhập, khóa SSH và địa chỉ truy cập cụ thể được giữ ngoài Git.
