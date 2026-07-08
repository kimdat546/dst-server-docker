name = "Fairy Tales - Đừng Chết Đói :)"
description = [[Bản Việt hoá (không chính thức) cho mod 童话世界 Fairy Tales của tác giả 谢十三.

➤ Mod gốc (BẮT BUỘC phải có): https://steamcommunity.com/sharedfiles/filedetails/?id=3288149713

Mình tạo bản dịch tiếng Việt cho mod Fairy Tales. Mod này KHÔNG thay thế mod gốc — bạn vẫn cần subscribe mod gốc ở trên; bản dịch chạy chồng lên và đổi chữ tiếng Trung sang tiếng Việt.

★ CÁCH DÙNG: Đây là mod phía client — chỉ cần BẬT mod này trong mục Mods là xong. Không cần thêm vào server, không ảnh hưởng tới server hay người chơi khác. (Bạn bè muốn xem tiếng Việt thì mỗi người tự bật mod này.)

★ ĐÃ DỊCH: tên vật phẩm, mô tả khi kiểm tra, công thức chế tạo, hành động (chuột phải), nhãn tab chế tạo, cửa hàng và màn chọn nhân vật.
★ CHƯA DỊCH (sẽ cập nhật sau): thoại nhân vật và bảng nhiệm vụ.

Cách hoạt động: mod load sau mod gốc và ghi đè chuỗi chữ sang tiếng Việt, không sửa file mod gốc nên vẫn chạy bình thường qua các bản cập nhật của mod gốc.

Mọi quyền với nội dung gốc thuộc về tác giả mod Fairy Tales (谢十三). Đây chỉ là bản dịch của người hâm mộ. Nếu tác giả gốc không muốn, mình sẽ gỡ.]]
author = "kimdat546"
version = "1.0.0"

api_version = 10
dst_compatible = true

-- Client-only: each player just enables it; the server does not need it.
all_clients_require_mod = false
client_only_mod = true

-- Load late so the Fairy Tales mod's strings already exist when we override them.
priority = -100

-- modicon: drop a 256x256 modicon.png in this folder; DST autocompiles it to
-- modicon.tex + modicon.xml on game launch. These two lines reference the result.
icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "tiếng việt", "vietnamese", "fairy tales" }

configuration_options = {}
