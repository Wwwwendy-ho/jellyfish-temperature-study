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

# 3. Per-year adjusted difference (heatwave month minus other months, Jun-Oct), primary analysis
y = pd.read_csv(ROOT/"outputs"/"heatwave_vs_normal_by_year.csv"); s = pd.read_csv(ROOT/"outputs"/"heatwave_vs_normal_summary.csv").set_index("analysis_id")
pooled = s.loc["primary_JunOct_5d", "adj_difference"] * 100
fig, ax = plt.subplots(figsize=(7, 3.8))
ax.axhline(0, color=INK2, lw=1)
ax.axhline(pooled, color=BLUE, lw=1, ls="--"); ax.text(len(y) - 0.55, pooled - 0.4, f"Pooled: {pooled:+.2f}", color=INK2, fontsize=8.5, ha="right", va="top"); ax.set_xlim(-0.5, len(y) - 0.5)
x = range(len(y)); ax.scatter(x, y.season_adjusted_difference * 100, s=70, color=BLUE, zorder=3, edgecolor=SURF, linewidth=1.5)
for i, r in y.iterrows(): ax.annotate(f"{r.season_adjusted_difference*100:+.1f}", (i, r.season_adjusted_difference*100), textcoords="offset points", xytext=(0, 9), ha="center", fontsize=8.5, color=INK2)
ax.set_xticks(list(x)); ax.set_xticklabels([f"{int(v)}\n({int(h)} heatwave mo.)" for v, h in zip(y.year, y.n_hw_months)], fontsize=8.5)
ax.set_ylabel("Share difference (percentage points)"); ax.grid(axis="y", color=GRID, lw=0.6); ax.set_axisbelow(True); ax.set_ylim(-9.5, 7)
ax.set_title("Heatwave minus other months, Jun-Oct, season-adjusted, by year", loc="left", color=INK, fontsize=11)
fig.tight_layout(); fig.savefig(OUT/"fig3_heatwave_vs_normal_by_year.png", dpi=200); plt.close(fig)
print("charts written:", sorted(p.name for p in OUT.glob("*.png")))
