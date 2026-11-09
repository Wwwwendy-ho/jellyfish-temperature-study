"""Draw the three README charts from the DuckDB tables / outputs CSVs into outputs/charts/. Charts only."""
import duckdb, pandas as pd, pathlib, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt, matplotlib.dates as mdates
ROOT = pathlib.Path(__file__).resolve().parents[1]; OUT = ROOT/"outputs"/"charts"; OUT.mkdir(parents=True, exist_ok=True)
BLUE, ORANGE, INK, INK2, GRID, SURF = "#2a78d6", "#eb6834", "#0b0b0b", "#52514e", "#e3e2de", "#fcfcfb"
plt.rcParams.update({"figure.facecolor": SURF, "axes.facecolor": SURF, "savefig.facecolor": SURF, "text.color": INK,
    "axes.labelcolor": INK2, "xtick.color": INK2, "ytick.color": INK2, "axes.edgecolor": GRID, "font.size": 10,
    "axes.spines.top": False, "axes.spines.right": False})
con = duckdb.connect(str(ROOT/"data"/"jelly.duckdb"), read_only=True)

# 1. Tacoma daily temperature vs 90th-percentile threshold, heatwave days marked (2019-2025)
t = con.execute("""SELECT a.d, a.mean_c, a.p90_c, h.d IS NOT NULL AS hw FROM tacoma_daily_anom a LEFT JOIN heatwave_days h ON h.d = a.d
                   WHERE a.baseline='excl_2007_2017' AND year(a.d) BETWEEN 2019 AND 2025 ORDER BY a.d""").df()
fig, ax = plt.subplots(figsize=(10, 4.6))
ax.plot(t.d, t.mean_c, color=BLUE, lw=1.2, label="Daily mean temperature")
ax.plot(t.d, t.p90_c, color=INK2, lw=1.2, ls="--", label="90th-percentile threshold (baseline 1998-2025 excl. 2007-2017)")
hw = t[t.hw]; ax.scatter(hw.d, hw.mean_c, s=14, color=ORANGE, zorder=3, edgecolor=SURF, linewidth=0.5, label=f"Heatwave days ({len(hw)})")
ax.set_ylabel("Water temperature (°C)"); ax.set_title("Tacoma water temperature and detected heatwave days, 2019-2025", loc="left", color=INK, fontsize=11)
ax.grid(axis="y", color=GRID, lw=0.6); ax.xaxis.set_major_locator(mdates.YearLocator()); ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y"))
ax.legend(frameon=False, loc="upper center", bbox_to_anchor=(0.5, -0.1), fontsize=8.5, ncol=3)
fig.tight_layout(); fig.savefig(OUT/"fig1_tacoma_heatwaves.png", dpi=200); plt.close(fig)

# 2. Monthly effort-corrected jellyfish share, heatwave months highlighted
m = pd.read_csv(ROOT/"outputs"/"monthly_heatwave_effort.csv", parse_dates=["month_start"])
m["hw_month"] = m.hw_days >= 5
fig, ax = plt.subplots(figsize=(10, 4.6))
for flag, col, lab in [(False, BLUE, "Month with fewer than 5 heatwave days"), (True, ORANGE, "Heatwave month (5+ heatwave days)")]:
    s = m[m.hw_month == flag]; ax.bar(s.month_start, s.jelly_share * 100, width=24, color=col, label=lab)
ax.set_ylabel("Jellyfish share of records (%)"); ax.grid(axis="y", color=GRID, lw=0.6); ax.set_axisbelow(True)
ax.set_title("Jellyfish share of iNaturalist records (jellyfish / (jellyfish + comparison panel)), by month", loc="left", color=INK, fontsize=11)
ax.xaxis.set_major_locator(mdates.YearLocator()); ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y"))
ax.legend(frameon=False, loc="upper center", bbox_to_anchor=(0.5, -0.1), fontsize=8.5, ncol=2); ax.set_ylim(0, m.jelly_share.max() * 100 * 1.08)
fig.tight_layout(); fig.savefig(OUT/"fig2_monthly_share.png", dpi=200); plt.close(fig)

# 3. Robustness: two-way fixed-effects estimate of (heatwave month - other months) in jellyfish share, with +/-1.96 unclustered SE
r = pd.read_csv(ROOT/"outputs"/"robustness_fe_estimates.csv")
def label(v):
    if v == "primary_5d": return "Primary (>=5 heatwave days)"
    if v == "threshold_10d": return ">=10 heatwave days"
    if v == "any_heatwave_day": return "Any heatwave day"
    if v == "full_baseline_5d": return "Full-record baseline"
    if v.startswith("drop_year_"): return "Drop " + v[-4:]
    return "Panel = " + v.replace("panel_only_", "")
r["label"] = r.variant.map(label)
r = r.iloc[::-1].reset_index(drop=True)
fig, ax = plt.subplots(figsize=(8, 6.2))
ax.axvline(0, color=INK2, lw=1)
yy = range(len(r))
ax.errorbar(r.fe_estimate * 100, list(yy), xerr=1.96 * r.se_unclustered * 100, fmt="none", ecolor=GRID if False else "#9a9994", elinewidth=1.2, capsize=0, zorder=1)
ax.scatter(r.fe_estimate * 100, list(yy), s=46, color=BLUE, zorder=3, edgecolor=SURF, linewidth=1)
prim = r.index[r.variant == "primary_5d"][0]
ax.scatter([r.fe_estimate[prim] * 100], [prim], s=70, color=ORANGE, zorder=4, edgecolor=SURF, linewidth=1)
ax.set_yticks(list(yy)); ax.set_yticklabels(r.label, fontsize=8.5)
ax.set_xlabel("Heatwave minus other months, jellyfish share (percentage points)\nBars: +/-1.96 x unclustered SE (probably too narrow)")
ax.grid(axis="x", color=GRID, lw=0.6); ax.set_axisbelow(True)
ax.set_title("Heatwave effect on jellyfish share: estimates under alternative choices", loc="left", color=INK, fontsize=11)
fig.tight_layout(); fig.savefig(OUT/"fig3_robustness.png", dpi=200); plt.close(fig)
print("charts written:", sorted(p.name for p in OUT.glob("*.png")))
