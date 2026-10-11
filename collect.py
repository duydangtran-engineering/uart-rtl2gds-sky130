#!/usr/bin/env python3
"""Gom kết quả các lần chạy sweep thành bảng Markdown + CSV."""
import csv
import json
import pathlib
import sys

periods = sys.argv[1:] or ["20", "10", "8", "6", "5", "4"]
periods = sorted(periods, key=float, reverse=True)

rows = []
for p in periods:
    f = pathlib.Path(f"runs/p{p}ns/final/metrics.json")
    freq = 1000.0 / float(p)
    if not f.exists():
        rows.append({"p": p, "freq": freq, "status": "FLOW LỖI (không có kết quả cuối)"})
        continue
    m = json.loads(f.read_text())
    setup = m.get("timing__setup__ws")
    hold = m.get("timing__hold__ws")
    power = m.get("power__total")
    area = m.get("design__instance__area")
    ok = (setup is not None and setup >= 0) and (hold is not None and hold >= 0)
    rows.append({
        "p": p, "freq": freq, "area": area,
        "power_uw": None if power is None else power * 1e6,
        "setup": setup, "hold": hold,
        "status": "đạt timing" if ok else "VI PHẠM timing",
    })


def fmt(v, nd):
    return "—" if v is None else f"{v:.{nd}f}"


header = ["Chu kỳ (ns)", "Tần số (MHz)", "Diện tích (µm²)", "Công suất (µW)",
          "Setup WS (ns)", "Hold WS (ns)", "Kết quả"]
lines = ["| " + " | ".join(header) + " |", "|" + "|".join(["---"] * len(header)) + "|"]
for r in rows:
    lines.append("| " + " | ".join([
        str(r["p"]), f"{r['freq']:.0f}", fmt(r.get("area"), 1), fmt(r.get("power_uw"), 1),
        fmt(r.get("setup"), 3), fmt(r.get("hold"), 3), r["status"],
    ]) + " |")

table = "\n".join(lines)
print("\n" + table + "\n")
pathlib.Path("sweep_results.md").write_text(table + "\n", encoding="utf-8")

with open("sweep_results.csv", "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh)
    w.writerow(["period_ns", "freq_mhz", "area_um2", "power_uw", "setup_ws_ns", "hold_ws_ns", "status"])
    for r in rows:
        w.writerow([r["p"], f"{r['freq']:.1f}", r.get("area"), r.get("power_uw"),
                    r.get("setup"), r.get("hold"), r["status"]])
print("Đã lưu: sweep_results.md và sweep_results.csv")
