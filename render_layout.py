#!/usr/bin/env python3
"""Vẽ ảnh layout gọn từ file GDS: chỉ giữ khung biên + met1..met4, không hiện chữ.

Cách dùng (trong thư mục uart, đã kích hoạt .venv):
    python3 render_layout.py results/uart.gds images/layout.png [duong-dan/sky130A.lyp]
"""
import sys

import klayout.lay as lay

gds = sys.argv[1] if len(sys.argv) > 1 else "results/uart.gds"
out = sys.argv[2] if len(sys.argv) > 2 else "images/layout.png"
lyp = sys.argv[3] if len(sys.argv) > 3 else None

# (layer, datatype) cần giữ lại theo bảng layer của Sky130
KEEP = {
    (235, 4): "prBoundary",
    (68, 20): "met1",
    (69, 20): "met2",
    (70, 20): "met3",
    (71, 20): "met4",
}

lv = lay.LayoutView()
lv.load_layout(gds, True)
if lyp:
    lv.load_layer_props(lyp)
    lv.add_missing_layers()

shown = []
for node in lv.each_layer():
    key = (node.source_layer, node.source_datatype)
    node.visible = key in KEEP
    if key in KEEP:
        shown.append(KEEP[key])

lv.set_config("text-visible", "false")
lv.set_config("grid-visible", "false")
lv.set_config("background-color", "#ffffff")
lv.max_hier()
lv.zoom_fit()
lv.save_image(out, 1800, 1800)
print("Đã vẽ", out, "- các lớp được bật:", sorted(set(shown)))
