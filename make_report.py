#!/usr/bin/env python3
"""Đọc kết quả THẬT trong runs/*/final/metrics.json, vẽ biểu đồ và điền vào README.

Chạy trong thư mục uart (đã kích hoạt .venv):
    pip install matplotlib        # chỉ cần lần đầu
    python3 make_report.py
Kết quả: images/sweep_tradeoff.png, README.md (sinh từ README.template.md)
"""
import glob
import json
import pathlib
import sys

PERIODS = sys.argv[1:] or ["20", "10", "8", "7", "6", "5", "4"]
ROOT = pathlib.Path(".")


def load(path):
    p = pathlib.Path(path)
    return json.loads(p.read_text()) if p.exists() else None


def row_from(m):
    if m is None:
        return None
    pw = m.get("power__total")
    return {
        "area": m.get("design__instance__area"),
        "power_uw": None if pw is None else pw * 1e6,
        "setup": m.get("timing__setup__ws"),
        "hold": m.get("timing__hold__ws"),
    }


def ok(r):
    return r["setup"] is not None and r["hold"] is not None and r["setup"] >= 0 and r["hold"] >= 0


def f(v, nd):
    return "—" if v is None else f"{v:.{nd}f}"


# ---------- 1. Bảng ba cột: SDC mặc định / v1 / v2 ----------
defaults = sorted(glob.glob("runs/RUN_*"))
cols = [
    ("SDC mặc định của OpenLane", defaults[0] if defaults else None),
    ("SDC v1 (thiếu môi trường)", "runs/with_sdc"),
    ("SDC v2 (đầy đủ)", "runs/with_sdc_v2"),
]
data = [(name, row_from(load(f"{d}/final/metrics.json")) if d else None) for name, d in cols]

lines = ["| Chỉ số | " + " | ".join(n for n, _ in data) + " |", "|---|" + "---|" * len(data)]
spec = [("Diện tích (µm²)", "area", 1), ("Công suất (µW)", "power_uw", 1),
        ("Setup WS (ns)", "setup", 3), ("Hold WS (ns)", "hold", 3)]
for label, key, nd in spec:
    lines.append(f"| {label} | " + " | ".join(f(r[key], nd) if r else "—" for _, r in data) + " |")
compare_table = "\n".join(lines)

# ---------- 2. Bảng sweep ----------
rows = []
for p in sorted(PERIODS, key=float, reverse=True):
    r = row_from(load(f"runs/p{p}ns/final/metrics.json"))
    if r:
        r.update(p=float(p), freq=1000.0 / float(p), ok=ok(r))
        rows.append(r)

hdr = ["Chu kỳ (ns)", "Tần số (MHz)", "Diện tích (µm²)", "Công suất (µW)",
       "Setup WS (ns)", "Hold WS (ns)", "Kết quả"]
sl = ["| " + " | ".join(hdr) + " |", "|" + "---|" * len(hdr)]
for r in rows:
    sl.append("| " + " | ".join([
        f"{r['p']:g}", f"{r['freq']:.0f}", f(r["area"], 1), f(r["power_uw"], 1),
        f(r["setup"], 3), f(r["hold"], 3), "đạt timing" if r["ok"] else "**VI PHẠM**"]) + " |")
sweep_table = "\n".join(sl)

passing = [r for r in rows if r["ok"]]
if passing:
    best = max(passing, key=lambda r: r["freq"])
    fmax_sentence = (f"Chu kỳ nhỏ nhất vẫn đạt timing trong thí nghiệm này là **{best['p']:g} ns "
                     f"(~{best['freq']:.0f} MHz)**.")
else:
    fmax_sentence = "Chưa có chu kỳ nào đạt timing."
failing = [r for r in rows if not r["ok"]]
if failing:
    fmax_sentence += (" Các chu kỳ " + ", ".join(f"{r['p']:g} ns" for r in sorted(failing, key=lambda r: -r["p"]))
                      + " vi phạm timing dù flow vẫn chạy xong và sinh ra GDS.")

# ---------- 3. Biểu đồ ----------
try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.lines import Line2D

    SURF, INK, INK2, GRID, BLUE = "#fcfcfb", "#0b0b0b", "#52514e", "#e1e0d9", "#2a78d6"
    fig, axes = plt.subplots(1, 3, figsize=(13, 3.9), dpi=160, facecolor=SURF)
    panels = [("power_uw", "Công suất ước tính (µW)"), ("area", "Diện tích cell (µm²)"),
              ("setup", "Setup WS (ns)  —  dương = đạt")]
    for ax, (key, ylabel) in zip(axes, panels):
        ax.set_facecolor(SURF)
        xs = [r["freq"] for r in rows]
        ys = [r[key] for r in rows]
        ax.plot(xs, ys, color=BLUE, linewidth=2, zorder=2)
        for r in rows:
            ax.plot(r["freq"], r[key], "o", markersize=9, markeredgewidth=2, markeredgecolor=BLUE,
                    markerfacecolor=BLUE if r["ok"] else SURF, zorder=3)
            ax.annotate(f"{r['p']:g} ns", (r["freq"], r[key]), textcoords="offset points",
                        xytext=(0, 10), ha="center", fontsize=8, color=INK2,
                        bbox=dict(boxstyle="square,pad=0.15", fc=SURF, ec="none"), zorder=4)
        if key == "setup":
            ax.axhline(0, color=INK2, linewidth=1, linestyle=(0, (4, 3)), zorder=1)
        ax.set_xlabel("Tần số clock (MHz)", color=INK2, fontsize=9)
        ax.set_ylabel(ylabel, color=INK, fontsize=9)
        ax.grid(True, color=GRID, linewidth=0.6, zorder=0)
        ax.set_axisbelow(True)
        for s in ("top", "right"):
            ax.spines[s].set_visible(False)
        for s in ("left", "bottom"):
            ax.spines[s].set_color(GRID)
        ax.tick_params(colors=INK2, labelsize=8)
        ax.margins(x=0.08, y=0.18)
    handles = [Line2D([], [], marker="o", linestyle="", markersize=9, markeredgewidth=2,
                      markeredgecolor=BLUE, markerfacecolor=BLUE, label="đạt timing (đặc)"),
               Line2D([], [], marker="o", linestyle="", markersize=9, markeredgewidth=2,
                      markeredgecolor=BLUE, markerfacecolor=SURF, label="vi phạm timing (rỗng)")]
    fig.legend(handles=handles, loc="lower center", ncol=2, frameon=False, fontsize=9,
               labelcolor=INK2, bbox_to_anchor=(0.5, -0.01))
    fig.suptitle("UART trên Sky130 — đánh đổi tốc độ / diện tích / công suất",
                 color=INK, fontsize=12, x=0.01, ha="left")
    fig.tight_layout(rect=(0, 0.06, 1, 0.94))
    pathlib.Path("images").mkdir(exist_ok=True)
    fig.savefig("images/sweep_tradeoff.png", facecolor=SURF)
    print("Đã vẽ images/sweep_tradeoff.png")
except ImportError:
    print("Chưa có matplotlib -> bỏ qua biểu đồ. Cài bằng: pip install matplotlib")

# ---------- 4. Điền README ----------
tpl = pathlib.Path("README.template.md")
if tpl.exists():
    txt = tpl.read_text(encoding="utf-8")
    txt = (txt.replace("{{COMPARE_TABLE}}", compare_table)
              .replace("{{SWEEP_TABLE}}", sweep_table)
              .replace("{{FMAX_SENTENCE}}", fmax_sentence))
    pathlib.Path("README.md").write_text(txt, encoding="utf-8")
    print("Đã sinh README.md từ README.template.md")
else:
    print("Không thấy README.template.md")

print("\n" + compare_table + "\n\n" + sweep_table + "\n\n" + fmax_sentence)
