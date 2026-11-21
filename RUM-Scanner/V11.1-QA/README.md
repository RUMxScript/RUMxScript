# RUM V11.1 — QA FIX 1

**Trạng thái:** Đã kiểm tra cú pháp, test cô lập; **chưa nghiệm thu runtime Roblox**.

Bản phân phối riêng để thử nghiệm. Loader V10.9 ổn định tại `RUM-Scanner/Loader.lua` **không thay đổi**.

- Chạy `Loader.lua` trong môi trường kiểm thử Roblox mà bạn có quyền truy cập.
- Mở RUM → chờ SCAN xong → REC → kết thúc → EXPORT.
- Chỉ chạy bộ tự kiểm tra thủ công ở trạng thái rảnh.
- Không khẳng định ghi nhận 100% Remote hoặc logic script bên ngoài.
- Định dạng: 12 phần **LZW16 + Base64 (có thể giải ngược, không phải mã hóa an toàn)**.
- Dữ liệu file xác minh không đồng nghĩa toàn bộ hành động game đã được ghi.
- Không chia sẻ nhật ký thô khi có thông tin nhạy cảm.
- File nguồn: SHA-256 `405ebe041ea51ece38bd468ea60fc4b6b0022eadffdedbc49d843d069fd2348b`, 1,296,515 byte.

Xem `QA_REPORT.md` để biết những lỗi đã sửa và phần còn cần nghiệm thu.
