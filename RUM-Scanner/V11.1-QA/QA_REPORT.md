# RUM V11.1 — QA FIX 1

## Phạm vi
Sửa lỗi tại chỗ trong `RUM_V11.1_UNIFIED.lua`. Không viết lại SCAN, REC, V7/V8/V9, Master DB hay cơ chế phân tích. Bản QA đã được đóng gói thử nghiệm lên GitHub trong thư mục riêng; không thay loader ổn định V10.9.

## Lỗi đã sửa
- **Ghi/xác minh file**: che dữ liệu lỗi thì báo FAILED thay vì xuất dữ liệu thô; hash của từng file dùng đúng nội dung đã được ghi và đọc lại sau che.
- **Bài test file**: thay việc ghi đè tạm `writefile`, `appendfile`, `readfile`, `isfile` toàn cục bằng backend giả cô lập để không can thiệp runtime.
- **Regression**: bỏ tự chạy toàn bộ suite sau 20 giây; trạng thái `startup_ready` KHÔNG có nghĩa bài kiểm thử đã PASS. Bộ test chỉ chạy khi người dùng bấm nút tự kiểm tra, khi không có SCAN/REC/EXPORT.
- **Chế độ tương thích V10.9**: không tắt đường ghi nhận Remote trực tiếp đã có trong V10.9.
- **Session ID**: thêm `scanId` cho bản ghi Remote ra/vào; loại bản ghi không thuộc phiên khỏi Raw Export và đầu vào Script Behavior. Ghi số bản ghi bị loại. Timeline lọc Remote theo phiên, state theo đồng hồ bắt đầu phiên.
- **Đồng bộ tác vụ**: ngăn EXPORT khi SCAN, REC đang ghi hoặc đang xác minh/phân tích; ngăn REC mới khi phiên trước đang kết thúc; không cho hai EXPORT V11 chạy chồng nhau.
- **Hiển thị và nhãn**: sửa thông báo test 'tự chạy sau 20 giây', đồng bộ version `11.1-qa-fix1` và tên mục xuất đúng 8 tệp.

## Kiểm thử đã thực hiện ngoài Roblox
- Cú pháp Lua: **PASS** (texlua/loadfile, không chạy mã Roblox).
- Bài test cô lập che dữ liệu: **PASS** với môi trường mô phỏng JSON.
- Bài test cô lập ghi file và readback: **PASS** 8 kịch bản A–H dùng bộ nhớ giả.
- Khác biệt mã nguồn: rà theo đúng các phần thay đổi, giữ mã nguồn gốc nguyên trạng.

## Chưa thể xác nhận
- Bộ kiểm thử tích hợp toàn hệ thống và độ tương thích executor/Roblox: **CHƯA CHẠY**.
- Khả năng ghi nhận 100% lời gọi Remote hoặc hiểu mọi tính năng script ngoài: **KHÔNG BẢO ĐẢM**. Bộ lọc `checkcaller()` của engine vẫn còn; bản QA này không thay đổi chính sách thu thập.
- Dữ liệu phân tích cũ trong Master DB/Intel có thể gộp nhiều phiên theo thiết kế; chỉ nhóm raw/timeline/behavior mới được siết phiên.
- Nhật ký raw tự ghi xuống đĩa trước EXPORT không được che tự động; KHÔNG chia sẻ khi có thông tin riêng tư.

## Nghiệm thu đề xuất trên game của bạn
1. Mở script trong môi trường kiểm thử được cấp phép; chờ SCAN xong.
2. Bật REC, thử các hành động thông thường, dừng REC. Đảm bảo đã kết thúc xác minh/phân tích.
3. EXPORT V11; đối chiếu 8 tệp và kiểm tra `status=VERIFIED`, hash, số bản ghi và Coverage.
4. Trong Debug, bấm chạy bài tự kiểm tra khi không có tác vụ; chỉ xem PASS/FAIL/SKIP thực tế.
5. Thử mở lại sau khi kết thúc và kiểm tra việc phục hồi trạng thái.

Lưu ý: `VERIFIED` ở cấp file nghĩa là nội dung được ghi và đọc lại khớp, không phải chứng nhận mọi sự kiện gameplay đều đã được ghi.