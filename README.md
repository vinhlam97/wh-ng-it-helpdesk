# Quản lý sửa chữa thiết bị — bản Supabase (dùng chung, có đăng nhập)

Web tĩnh (1 file `index.html`) chạy trên **GitHub Pages**, dữ liệu + đăng nhập nằm trên **Supabase**.
Nhiều người dùng cùng lúc thấy thay đổi của nhau ngay lập tức (realtime). Người chưa đăng nhập không đọc được dữ liệu.

```
index.html           ← ứng dụng
config.js            ← điền URL + key của Supabase (file duy nhất bạn phải sửa)
supabase/schema.sql  ← chạy 1 lần trong Supabase để tạo bảng, phân quyền, kho ảnh
README.md
```

## Bước 1 — Tạo project Supabase
1. Vào https://supabase.com → đăng nhập → **New project**.
2. Đặt tên, đặt **Database Password** (lưu lại), chọn region gần Việt Nam (ví dụ Singapore) → **Create new project**, chờ 1–2 phút.

## Bước 2 — Tạo bảng dữ liệu
1. Trong project: menu trái **SQL Editor** → **New query**.
2. Mở file `supabase/schema.sql`, copy toàn bộ → dán vào → **Run**. Thấy "Success" là xong.
   (Chạy lại nhiều lần cũng không sao.)

Script này tạo: bảng `profiles` (quyền người dùng), 4 bảng dữ liệu (`groups`, `stocks`, `skus`, `devices`), bật realtime, tạo kho ảnh riêng tư `device-images`, và bật chính sách bảo mật (RLS): chỉ người đăng nhập mới đọc/ghi được.

## Bước 3 — Tạo tài khoản đăng nhập
1. Menu trái **Authentication** → **Users** → **Add user** → **Create new user**.
2. Nhập email + mật khẩu, **tick "Auto Confirm User"** → Create.
3. **Người tạo đầu tiên sẽ tự động là `admin`** → hãy tạo tài khoản của chính bạn trước. Các tài khoản sau mặc định là `editor`.
4. Tắt đăng ký tự do để người lạ không tự tạo tài khoản: **Authentication** → mục cài đặt đăng nhập (Sign In / Providers) → tắt **"Allow new users to sign up"** (tên mục có thể hơi khác tuỳ phiên bản giao diện).

## Bước 4 — Lấy URL và key, điền vào `config.js`
1. **Project Settings** → **API** (hoặc **API Keys**).
2. Copy **Project URL** (dạng `https://xxxx.supabase.co`) và key loại **anon public** (hoặc **publishable**).
3. Sửa `config.js`:
```js
window.APP_CONFIG = {
  SUPABASE_URL: 'https://xxxx.supabase.co',
  SUPABASE_ANON_KEY: 'eyJ...hoặc sb_publishable_...'
};
```
> Key `anon/publishable` được thiết kế để công khai trong web — an toàn nhờ RLS ở bước 2.
> **Tuyệt đối không dán `service_role` / `secret` key** vào đây hay lên GitHub.

## Bước 5 — Đưa lên GitHub
Repo của bạn cần có `index.html` và `config.js` **ở thư mục gốc** (cùng `supabase/schema.sql`, `README.md` nếu muốn lưu kèm). Commit & push như bình thường.

## Bước 6 — Bật GitHub Pages
1. Repo → **Settings** → **Pages**.
2. **Source**: *Deploy from a branch* → Branch `main`, thư mục `/ (root)` → **Save**.
3. Chờ 1–2 phút, GitHub hiện địa chỉ dạng `https://<tên-bạn>.github.io/<tên-repo>/`. Đó là link gửi cho mọi người.

(Repo private thì GitHub Pages có thể cần gói trả phí; repo public không sao vì dữ liệu nằm ở Supabase và được khoá bằng đăng nhập.)

## Bước 7 — Báo Supabase biết địa chỉ web
**Authentication** → **URL Configuration** → **Site URL** = link GitHub Pages ở bước 6 → Save.

## Bước 8 — Đăng nhập và nạp dữ liệu cũ
1. Mở link GitHub Pages → đăng nhập bằng tài khoản admin. Lần đầu, hệ thống tự nạp danh mục nhóm/hạng mục mẫu nếu database còn trống.
2. Dữ liệu cũ (bản chạy trong claude.ai) không tự chuyển sang. Từ bản cũ bấm **Xuất Excel** ở các tab (Thiết bị sửa chữa, Thiết bị SKU, Danh mục dịch vụ, Kho) rồi vào bản mới dùng **Import Excel** ở từng tab. Thứ tự nên làm: **Kho → Danh mục dịch vụ → Thiết bị (SKU) → Thiết bị sửa chữa**.
3. Hình ảnh không nằm trong Excel nên cần tải lại hình (nếu cần).

## Phân quyền

| Quyền | Xem | Thêm/sửa/xóa dữ liệu, tải ảnh | Quản lý quyền người khác |
|---|---|---|---|
| `viewer` | ✓ | ✗ (nút bị ẩn) | ✗ |
| `editor` | ✓ | ✓ | ✗ |
| `admin`  | ✓ | ✓ | ✓ |

Đổi quyền: **SQL Editor** → chạy, ví dụ:
```sql
update public.profiles set role = 'viewer' where email = 'nguoi-do@congty.com';
```
(hoặc **Table Editor** → bảng `profiles` → sửa cột `role`). Người đó đăng nhập lại để áp dụng.
Muốn chỉ admin được xóa dữ liệu: sửa policy `del` của 4 bảng thành `public.my_role() = 'admin'`.

## Thêm / xoá người dùng
- Thêm: **Authentication → Users → Add user** (như bước 3). Quên mật khẩu: vào user đó → đặt lại mật khẩu.
- Xoá: xoá user trong cùng màn hình; profile tự bị xoá theo.

## Cập nhật tính năng sau này
Sửa `index.html` (nhờ Claude chỉnh) → commit lên GitHub → Pages tự cập nhật sau ~1 phút. Dữ liệu trên Supabase giữ nguyên. Mỗi dòng dữ liệu lưu dạng JSON nên **thêm trường mới thường không cần sửa database**.

## Lưu ý vận hành
- **Backup**: bấm *Xuất Excel* định kỳ ở các tab. Kiểm tra mục Database → Backups của gói Supabase bạn đang dùng.
- Gói Free của Supabase có thể tự **tạm dừng project** nếu lâu không có hoạt động — kiểm tra chính sách hiện hành; có thể khôi phục từ dashboard.
- Hai người sửa **cùng một thiết bị cùng lúc**: lần lưu sau ghi đè lần trước. Thay đổi của người khác tự hiện lên bảng.
- Ảnh được nén còn tối đa ~900px; lưu ở kho riêng tư, link xem tự hết hạn sau 1 giờ và được tạo lại khi cần.

## Xử lý sự cố
| Hiện tượng | Cách xử lý |
|---|---|
| "Chưa cấu hình Supabase" | `config.js` chưa điền đúng URL/key, hoặc file chưa được đẩy lên GitHub cùng thư mục với `index.html`. |
| "Đăng nhập thất bại: Invalid login credentials" | Sai email/mật khẩu, hoặc user chưa tick Auto Confirm. |
| Đăng nhập được nhưng không sửa được, hiện "chỉ có quyền xem" | Bảng `profiles` đang để `viewer` hoặc chưa có dòng của bạn → chạy lại `schema.sql` rồi đặt `role`. |
| "Lưu thất bại: new row violates row-level security" | Tài khoản không có quyền ghi (xem bảng phân quyền). |
| Không thấy thay đổi của người khác ngay | Kiểm tra `schema.sql` đã chạy hết (mục realtime); tải lại trang. |
| Ảnh không hiện / không tải lên được | Kho `device-images` chưa tạo (chạy lại `schema.sql`) hoặc tài khoản là `viewer`. |
