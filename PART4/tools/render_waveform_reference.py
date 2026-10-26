#!/usr/bin/env python3
"""Render the actual Part 4 exception VCD as a static study reference.

This is a plot of recorded signal changes, not a simulated waveform drawing.
It is deliberately labelled as a Verilator reference, not a Verdi screenshot.
The APB CSV records values immediately before each rising completion edge,
so same-edge nonblocking CSR updates cannot contaminate read samples.

Run from anywhere: python3 tools/render_waveform_reference.py
Requires matplotlib.  The VCD and output directory may be overridden.
"""

from __future__ import annotations

import argparse
from bisect import bisect_left, bisect_right
import csv
from dataclasses import dataclass
from pathlib import Path
import os
import re

os.environ.setdefault("MPLCONFIGDIR", "/tmp/lab3_mpl")
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon
from matplotlib.ticker import MultipleLocator


TOP = "TOP.tb_matmul_apb."
DUT = TOP + "dut."
REGISTERS = {
    0x0000: "CONTROL", 0x0002: "STATUS", 0x0004: "FLAGS",
    0x0010: "ADDR_A", 0x0012: "ADDR_B", 0x0014: "ADDR_C",
    0x0016: "STRIDE_A", 0x0018: "STRIDE_B", 0x001A: "STRIDE_C",
}


@dataclass
class Vcd:
    symbols: dict[str, str]
    widths: dict[str, int]
    histories: dict[str, list[tuple[float, int | None]]]
    apb: list[dict[str, object]]
    scale_ns: float

    def history(self, path: str) -> list[tuple[float, int | None]]:
        if path not in self.symbols:
            raise KeyError(f"Required signal missing from VCD: {path}")
        return self.histories[self.symbols[path]]

    def value(self, path: str, time: float) -> int | None:
        history = self.history(path)
        index = bisect_right([t for t, _ in history], time) - 1
        return history[index][1] if index >= 0 else None

    def before(self, path: str, time: float) -> int | None:
        """Value strictly before an edge, excluding same-edge NBA changes."""
        history = self.history(path)
        index = bisect_left([t for t, _ in history], time) - 1
        return history[index][1] if index >= 0 else None


@dataclass
class RecordedEvents:
    config_writes: list[dict[str, object]]
    start_write: float
    run_start: float
    raw_done: float
    sticky_done: float
    status_read: dict[str, object]
    flags_read: dict[str, object]
    c_writes: list[dict[str, object]]
    clock_period: float

    @property
    def first_c_write(self) -> float:
        return min(float(row["time_ns"]) for row in self.c_writes)

    @property
    def final_c_write(self) -> float:
        return max(float(row["time_ns"]) for row in self.c_writes)


def rising_edges(vcd: Vcd, path: str) -> list[float]:
    edges = []
    previous = None
    for time, value in vcd.history(path):
        if previous == 0 and value == 1:
            edges.append(time)
        previous = value
    return edges


def recorded_events(vcd: Vcd) -> RecordedEvents:
    """Derive annotations from this trace; never assume a particular run time."""
    starts = [row for row in vcd.apb if row["direction"] == "WRITE"
              and row["address_hex"] == "0x0000"
              and int(str(row["data_hex"]), 16) & 1]
    if len(starts) != 1:
        raise ValueError("The exception reference requires exactly one START command")
    start_write = float(starts[0]["time_ns"])

    def first_rise(path: str, after: float) -> float:
        edges = [time for time in rising_edges(vcd, path) if time >= after]
        if not edges:
            raise ValueError(f"No rising transition on {path} after {after:g} ns")
        return edges[0]

    run_start = first_rise(DUT + "core_start", start_write)
    raw_done = first_rise(DUT + "core_done", run_start)
    sticky_done = first_rise(DUT + "done_sticky", run_start)
    reads = [row for row in vcd.apb if row["direction"] == "READ"]
    status_read = next((row for row in reads
                        if row["address_hex"] == "0x0002"
                        and float(row["time_ns"]) >= sticky_done
                        and (int(str(row["data_hex"]), 16) & 3) == 1), None)
    if status_read is None:
        raise ValueError("No completed STATUS read reported DONE=1 and BUSY=0")
    flags_read = next((row for row in reads
                       if row["address_hex"] == "0x0004"
                       and float(row["time_ns"]) > float(status_read["time_ns"])), None)
    if flags_read is None or flags_read["data_hex"] != "0x0001":
        raise ValueError("Expected a completed FLAGS read of 0x0001 after DONE")

    config_writes = [row for row in vcd.apb
                     if row["direction"] == "WRITE"
                     and 0x0010 <= int(str(row["address_hex"]), 16) <= 0x001A
                     and float(row["time_ns"]) < start_write]
    if {row["register"] for row in config_writes} != {
            "ADDR_A", "ADDR_B", "ADDR_C", "STRIDE_A", "STRIDE_B", "STRIDE_C"}:
        raise ValueError("The trace must configure all six address/stride CSRs before START")

    clock_edges = rising_edges(vcd, TOP + "PCLK")
    if len(clock_edges) < 2:
        raise ValueError("Insufficient PCLK edges")
    periods = [b - a for a, b in zip(clock_edges, clock_edges[1:])]
    clock_period = sorted(periods)[len(periods) // 2]
    c_writes = []
    for time in clock_edges:
        for bank in (0, 1):
            if vcd.before(DUT + f"u_core.c_we_{bank}", time) in (None, 0):
                continue
            c_writes.append({
                "time_ns": time,
                "bank": bank,
                "address": vcd.before(DUT + f"u_core.c_addr_{bank}", time),
                "write_enable": vcd.before(DUT + f"u_core.c_we_{bank}", time),
                "data": vcd.before(DUT + f"u_core.c_data_{bank}", time),
            })
    base = vcd.value(DUT + "address_mat_c", run_start)
    stride = vcd.value(DUT + "address_stride_c", run_start)
    if base is None or stride is None:
        raise ValueError("Unknown configured C address/stride")
    for bank in (0, 1):
        writes = [row for row in c_writes if row["bank"] == bank]
        if len(writes) != 8:
            raise ValueError(f"C{bank} has {len(writes)} writes, expected eight")
        for index, row in enumerate(writes):
            if (row["write_enable"] != 0xF or row["data"] != 0x78787878
                    or row["address"] != base + index * stride):
                raise ValueError(f"Unexpected C{bank} result write: {row}")
    events = RecordedEvents(config_writes, start_write, run_start, raw_done,
                            sticky_done, status_read, flags_read, c_writes, clock_period)
    if events.final_c_write > sticky_done:
        raise ValueError("Sticky DONE precedes the final committed result write")
    return events


def read_vcd(path: Path) -> Vcd:
    """Read scalar/vector value changes and identify APB completion edges."""
    symbols: dict[str, str] = {}
    widths: dict[str, int] = {}
    histories: dict[str, list[tuple[float, int | None]]] = {}
    values: dict[str, int | None] = {}
    scope: list[str] = []
    apb: list[dict[str, object]] = []
    scale_ns = None
    timestamp = 0
    changes: dict[str, int | None] = {}
    in_data = False

    def flush_timestamp() -> None:
        if not changes:
            return
        assert scale_ns is not None
        time_ns = timestamp * scale_ns
        clk = symbols[TOP + "PCLK"]
        if values.get(clk) == 0 and changes.get(clk) == 1:
            before = lambda name: values.get(symbols[TOP + name])
            if before("PSEL") == before("PENABLE") == before("PREADY") == 1:
                write = before("PWRITE") == 1
                address = before("PADDR")
                apb.append({
                    "time_ns": time_ns,
                    "direction": "WRITE" if write else "READ",
                    "register": REGISTERS.get(address, "UNMAPPED"),
                    "address_hex": f"0x{address:04X}",
                    "data_hex": f"0x{before('PWDATA' if write else 'PRDATA'):04X}",
                })
        for symbol, value in changes.items():
            if symbol not in values or values[symbol] != value:
                histories.setdefault(symbol, []).append((time_ns, value))
            values[symbol] = value
        changes.clear()

    with path.open() as stream:
        for raw_line in stream:
            line = raw_line.strip()
            if not line:
                continue
            if not in_data:
                parts = line.split()
                if parts[0] == "$timescale":
                    match = re.search(r"(\d+)\s*(fs|ps|ns|us|ms|s)", line)
                    if not match:
                        raise ValueError("Expected inline VCD timescale")
                    scale_ns = int(match[1]) * {
                        "fs": 1e-6, "ps": 1e-3, "ns": 1,
                        "us": 1e3, "ms": 1e6, "s": 1e9,
                    }[match[2]]
                elif parts[0] == "$scope":
                    scope.append(parts[2])
                elif parts[0] == "$upscope":
                    scope.pop()
                elif parts[0] == "$var":
                    symbols[".".join(scope + [parts[4]])] = parts[3]
                    widths[parts[3]] = int(parts[2])
                elif parts[0] == "$enddefinitions":
                    in_data = True
                continue
            if line.startswith("#"):
                flush_timestamp()
                timestamp = int(line[1:])
            elif line[0] in "01xz":
                changes[line[1:]] = int(line[0]) if line[0] in "01" else None
            elif line[0] in "bB":
                bits, symbol = line[1:].split()
                changes[symbol] = None if any(c in bits.lower() for c in "xz") else int(bits, 2)
        flush_timestamp()
    if scale_ns is None:
        raise ValueError("No VCD timescale")
    return Vcd(symbols, widths, histories, apb, scale_ns)


def clipped_segments(vcd: Vcd, path: str, left: float, right: float):
    current = vcd.value(path, left)
    start = left
    for time, value in vcd.history(path):
        if time <= left:
            continue
        if time >= right:
            break
        yield start, time, current
        start, current = time, value
    yield start, right, current


def draw_panel(ax, vcd: Vcd, rows, span, heading, subtitle):
    left, right = span
    count = len(rows)
    colors = {"apb": "#2463A4", "csr": "#087F71", "core": "#784E9B", "ram": "#BC5D1F"}
    ax.set_facecolor("#FBFCFE")
    for index, (label, path, radix, group) in enumerate(rows):
        y = count - 1 - index
        color = colors[group]
        ax.axhspan(y - .43, y + .43, color="#F0F4F8" if index % 2 == 0 else "#FFFFFF", zorder=0)
        history = list(clipped_segments(vcd, path, left, right))
        if radix == "bit":
            times = [start for start, _, _ in history] + [right]
            vals = [(y + .23 if value == 1 else y - .23) for _, _, value in history]
            ax.step(times, vals + [vals[-1]], where="post", color=color, lw=1.35, zorder=3)
            if label != "PCLK":
                for start, stop, value in history:
                    if value == 1:
                        ax.fill_between([start, stop], y - .23, y + .23, color=color, alpha=.10, zorder=2)
        else:
            for start, stop, value in history:
                bevel = min((right-left)*.0018, (stop-start)*.18)
                poly = Polygon([
                    (start,y), (start+bevel,y+.25), (stop-bevel,y+.25),
                    (stop,y), (stop-bevel,y-.25), (start+bevel,y-.25),
                ], closed=True, facecolor=color, edgecolor=color, alpha=.13, lw=.9, zorder=2)
                ax.add_patch(poly)
                ax.plot([start+bevel,stop-bevel],[y+.25,y+.25],color=color,lw=.75,zorder=3)
                ax.plot([start+bevel,stop-bevel],[y-.25,y-.25],color=color,lw=.75,zorder=3)
                if value is None:
                    text = "X"
                elif radix == "hex8":
                    text = f"{value:08X}"
                elif radix == "hex4":
                    text = f"{value:04X}"
                else:
                    text = str(value)
                # Render a bus value only when it fits its actual stable span.
                fraction = (stop-start)/(right-left)
                minimum = .038 if len(text)>4 else .022
                if fraction >= minimum and (value != 0 or fraction >= .05):
                    ax.text((start+stop)/2,y,text,ha="center",va="center",fontsize=8.3,
                            family="DejaVu Sans Mono",color=color,zorder=5)
        ax.text(-.012,y,label,transform=ax.get_yaxis_transform(),ha="right",va="center",
                fontsize=10.2,color="#192D43",weight="medium")
    ax.set_xlim(left,right)
    ax.set_ylim(-.55,count+.7)
    ax.set_yticks([])
    ax.xaxis.set_major_locator(MultipleLocator(20 if right-left<250 else 50))
    ax.xaxis.set_minor_locator(MultipleLocator(5 if right-left<250 else 10))
    ax.grid(axis="x",which="major",color="#CFD8E2",lw=.65,zorder=1)
    ax.grid(axis="x",which="minor",color="#E9EDF2",lw=.4,zorder=1)
    ax.set_xlabel("Recorded simulation time (ns)",fontsize=10.5,labelpad=7)
    ax.tick_params(axis="x",labelsize=9.5)
    for side in ["left","right","top"]:
        ax.spines[side].set_visible(False)
    ax.spines["bottom"].set_color("#B6C2CF")
    ax.set_title(heading,loc="left",fontsize=15,weight="bold",pad=34,color="#12283D")
    ax.text(0,1.035,subtitle,transform=ax.transAxes,ha="left",va="bottom",
            fontsize=10.4,color="#526378")
    return count


def render(vcd: Vcd, events: RecordedEvents, source: Path, outdir: Path) -> None:
    plt.rcParams.update({"font.family":"DejaVu Sans", "savefig.facecolor":"white"})
    fig = plt.figure(figsize=(19,17),facecolor="white")
    grid = fig.add_gridspec(2,1,height_ratios=[12,14],hspace=.34,
                           left=.16,right=.975,top=.845,bottom=.14)
    config = [
        ("PCLK",TOP+"PCLK","bit","apb"),
        ("PSEL",TOP+"PSEL","bit","apb"),
        ("PENABLE",TOP+"PENABLE","bit","apb"),
        ("PWRITE",TOP+"PWRITE","bit","apb"),
        ("PADDR [hex]",TOP+"PADDR","hex4","apb"),
        ("PWDATA [hex]",TOP+"PWDATA","hex4","apb"),
        ("address_mat_a [hex]",DUT+"address_mat_a","hex4","csr"),
        ("address_mat_b [hex]",DUT+"address_mat_b","hex4","csr"),
        ("address_mat_c [hex]",DUT+"address_mat_c","hex4","csr"),
        ("address_stride_a",DUT+"address_stride_a","dec","csr"),
        ("address_stride_b",DUT+"address_stride_b","dec","csr"),
        ("address_stride_c",DUT+"address_stride_c","dec","csr"),
    ]
    runtime = [
        ("PCLK",TOP+"PCLK","bit","apb"),
        ("PSEL",TOP+"PSEL","bit","apb"),
        ("PENABLE",TOP+"PENABLE","bit","apb"),
        ("PWRITE",TOP+"PWRITE","bit","apb"),
        ("PADDR [hex]",TOP+"PADDR","hex4","apb"),
        ("PRDATA [hex]",TOP+"PRDATA","hex4","apb"),
        ("core_start",DUT+"core_start","bit","core"),
        ("core_exception",DUT+"core_exception","bit","core"),
        ("core_done (raw)",DUT+"core_done","bit","core"),
        ("done_sticky",DUT+"done_sticky","bit","csr"),
        ("flags_sticky [hex]",DUT+"flags_sticky","hex4","csr"),
        ("C0 valid",DUT+"u_core.c_valid_0","bit","ram"),
        ("C0 address",DUT+"u_core.c_addr_0","dec","ram"),
        ("C0 data [hex]",DUT+"u_core.c_data_0","hex8","ram"),
    ]
    ax1=fig.add_subplot(grid[0]);ax2=fig.add_subplot(grid[1])
    period = events.clock_period
    config_span = (float(events.config_writes[0]["time_ns"]) - 1.5 * period,
                   float(events.config_writes[-1]["time_ns"]) + 2 * period)
    runtime_span = (events.start_write - 2.5 * period,
                    float(events.flags_read["time_ns"]) + 2 * period)
    n1=draw_panel(ax1,vcd,config,config_span,
        "1  Configure six CSRs using APB writes",
        "PREADY remains 1. Writes complete at rising PCLK edges with PSEL = PENABLE = PWRITE = 1.")
    for event in events.config_writes:
        time=float(event["time_ns"])
        ax1.axvline(time,color="#2463A4",ls=":",lw=.9,alpha=.6)
        ax1.text(time,n1+.26,f"{time:g}",ha="center",va="center",fontsize=8.5,color="#2463A4")
    n2=draw_panel(ax2,vcd,runtime,runtime_span,
        "2  Start, run the 8×8 array, then read completion and exception status",
        "Exception test: A = +infinity, B = zero. Every output is FP8 canonical NaN (0x78).")
    for time,color in [(events.start_write,"#2463A4"),(events.run_start,"#784E9B"),
                       (events.final_c_write,"#BC5D1F"),(events.raw_done,"#784E9B"),
                       (events.sticky_done,"#087F71")]:
        ax2.axvline(time,color=color,ls="--",lw=1.1,alpha=.85,zorder=6)
    ax2.annotate(f"{events.start_write:g} ns\nSTART write",
                 xy=(events.start_write,n2-.6),xytext=(runtime_span[0]+.7*period,n2+.3),
                 ha="left",va="center",fontsize=9,color="#2463A4",
                 arrowprops={"arrowstyle":"-","color":"#2463A4","lw":.9})
    ax2.annotate(f"{events.run_start:g} ns\nRUN begins",
                 xy=(events.run_start,n2-.6),xytext=(events.run_start+3*period,n2+.3),
                 ha="left",va="center",fontsize=9,color="#784E9B",
                 arrowprops={"arrowstyle":"-","color":"#784E9B","lw":.9})
    ax2.annotate(f"{events.sticky_done:g} ns\nSticky DONE",
                 xy=(events.sticky_done,n2-.6),xytext=(events.sticky_done-6*period,n2+.3),
                 ha="left",va="center",fontsize=9,color="#087F71",
                 arrowprops={"arrowstyle":"-","color":"#087F71","lw":.9})

    # Actual APB read completion values, shown separately because short bus
    # intervals in the full execution view are too narrow for eight labels.
    status = events.status_read
    flags = events.flags_read
    fig.text(.04,.967,"LAB 3 · PART 4",fontsize=12,weight="bold",color="#2463A4")
    fig.text(.04,.94,"APB exception transaction — recorded waveform reference",
             fontsize=22,weight="bold",color="#12283D")
    resolution = (f"{vcd.scale_ns * 1000:g} ps" if vcd.scale_ns < 1
                  else f"{vcd.scale_ns:g} ns")
    fig.text(.04,.916,f"Verilator simulation reference · Source signal transitions from {source.name} · {resolution} source resolution",
             fontsize=11.3,color="#526378")
    fig.text(.16,.102,
        f"Recorded reads: {status['time_ns']:g} ns  STATUS [0x0002] → {status['data_hex']}  (DONE=1, BUSY=0)"
        f"     |     {flags['time_ns']:g} ns  FLAGS [0x0004] → {flags['data_hex']}",
        fontsize=11.2,color="#12283D",weight="medium")
    fig.text(.16,.080,
        f"C0 and C1 each commit eight 0x78787878 words at {events.first_c_write:g}–{events.final_c_write:g} ns.",
        fontsize=10,color="#526378")
    fig.text(.16,.058,
        f"Distinct recorded events: final C write {events.final_c_write:g} ns (orange)"
        f"  ·  raw core DONE {events.raw_done:g} ns (purple)"
        f"  ·  sticky DONE {events.sticky_done:g} ns (green).",
        fontsize=10,color="#526378")
    fig.text(.04,.022,
        "STUDY REFERENCE ONLY — This is not a Verdi screenshot. Capture the required Verdi waveforms on Apporto and annotate them yourself.",
        fontsize=10.5,weight="bold",color="#9A4C18")
    outdir.mkdir(parents=True,exist_ok=True)
    fig.savefig(outdir/"exception_waveform.png",dpi=180)
    fig.savefig(outdir/"exception_waveform.svg")
    plt.close(fig)


def main() -> None:
    root=Path(__file__).resolve().parents[1]
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vcd",type=Path,default=root/"verification/part4_exception.vcd")
    parser.add_argument("--output-dir",type=Path,default=root/"verification")
    args=parser.parse_args()
    vcd=read_vcd(args.vcd)
    events=recorded_events(vcd)
    args.output_dir.mkdir(parents=True,exist_ok=True)
    with (args.output_dir/"apb_transactions.csv").open("w",newline="") as stream:
        writer=csv.DictWriter(stream,fieldnames=["time_ns","direction","register","address_hex","data_hex"])
        writer.writeheader();writer.writerows(vcd.apb)
    with (args.output_dir/"waveform_events.csv").open("w",newline="") as stream:
        writer=csv.DictWriter(stream,fieldnames=["time_ns","event","details"])
        writer.writeheader()
        rows=[
            {"time_ns":events.start_write,"event":"START_WRITE","details":"CONTROL=0x0001"},
            {"time_ns":events.run_start,"event":"RUN_BEGIN","details":"core_start rises"},
            {"time_ns":events.raw_done,"event":"RAW_CORE_DONE","details":"core_done rises"},
            {"time_ns":events.sticky_done,"event":"STICKY_DONE","details":"done_sticky rises"},
        ]
        for row in events.c_writes:
            rows.append({"time_ns":row["time_ns"],"event":f"C{row['bank']}_WRITE",
                         "details":f"address={row['address']} data=0x{row['data']:08X}"})
        for label,row in (("STATUS_READ",events.status_read),("FLAGS_READ",events.flags_read)):
            rows.append({"time_ns":row["time_ns"],"event":label,"details":row["data_hex"]})
        writer.writerows(sorted(rows,key=lambda row:float(row["time_ns"])))
    render(vcd,events,args.vcd,args.output_dir)
    print(f"Rendered actual VCD signal histories and {len(vcd.apb)} APB transactions to {args.output_dir}")
    print(f"Final C write={events.final_c_write:g} ns; raw DONE={events.raw_done:g} ns; sticky DONE={events.sticky_done:g} ns")
    print(f"STATUS={events.status_read['data_hex']} at {events.status_read['time_ns']:g} ns; "
          f"FLAGS={events.flags_read['data_hex']} at {events.flags_read['time_ns']:g} ns")


if __name__=="__main__":
    main()
