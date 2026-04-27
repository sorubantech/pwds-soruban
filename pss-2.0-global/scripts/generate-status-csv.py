"""Generate a management-friendly CSV of all PSS 2.0 screen statuses.

Reads .claude/screen-tracker/REGISTRY.md, dedupes by registry ID (preferring
COMPLETED rows when duplicates exist), and writes a CSV with five user-friendly
columns: Module / Screen Name / Development Status / Dev Testing Status / QA Testing Status,
plus context columns (ID, Type, Priority, Notes).
"""
from __future__ import annotations

import csv
import re
from pathlib import Path

import os

REGISTRY = Path(".claude/screen-tracker/REGISTRY.md")

# When SUFFIX env var is set, append it to filenames (used to dodge file locks).
_SUFFIX = os.environ.get("SUFFIX", "")
OUT_CSV = Path(f".claude/screen-tracker/SCREEN-STATUS-OVERVIEW{_SUFFIX}.csv")
OUT_HTML = Path(f".claude/screen-tracker/SCREEN-STATUS-OVERVIEW{_SUFFIX}.html")
OUT_XLSX = Path(f".claude/screen-tracker/SCREEN-STATUS-OVERVIEW{_SUFFIX}.xlsx")

TEAM_MEMBERS = ["Karthick", "Saranya", "Kavin", "Sangeetha"]

DEV_STATUS_OPTIONS = [
    "Completed",
    "Completed - Needs Fix",
    "Ready to Build",
    "In Progress (Partial)",
    "Not Started",
    "Upcoming (Dashboard)",
    "Upcoming (Config)",
    "Upcoming (Mobile)",
    "Upcoming",
]

TESTING_STATUS_OPTIONS = [
    "Not Started",
    "Pending",
    "In Testing",
    "Passed",
    "Failed",
    "Issues Found",
    "Blocked - Awaiting Fix",
    "N/A (Upcoming)",
]


def dev_done_by(dev_status: str) -> str:
    """Pre-fill 'Development Done By' for any screen whose dev work is finished."""
    if dev_status in {"COMPLETED", "NEEDS_FIX"}:
        return "Karthick"
    return ""


# Status priority for dedup (higher = preferred when same ID appears twice)
STATUS_PRIORITY = {
    "COMPLETED": 100,
    "NEEDS_FIX": 90,
    "IN_PROGRESS": 85,
    "PARTIALLY_COMPLETED": 84,
    "PROMPT_READY": 70,
    "PARTIAL": 50,
    "NEW": 40,
    "SKIP_DASHBOARD": 10,
    "SKIP_CONFIG": 10,
    "SKIP_MOBILE": 10,
    "SKIP": 10,
}

# Friendly labels for management
DEV_STATUS_LABEL = {
    "COMPLETED": "Completed",
    "NEEDS_FIX": "Completed - Needs Fix",
    "IN_PROGRESS": "In Progress",
    "PARTIALLY_COMPLETED": "Partially Completed",
    "PROMPT_READY": "Ready to Build",
    "PARTIAL": "In Progress (Partial)",
    "NEW": "Not Started",
    "SKIP_DASHBOARD": "Upcoming (Dashboard)",
    "SKIP_CONFIG": "Upcoming (Config)",
    "SKIP_MOBILE": "Upcoming (Mobile)",
    "SKIP": "Upcoming",
}

MODULE_HEADER = re.compile(r"^## (.+?)\s*$")
SUB_HEADER = re.compile(r"^### ")
DATA_ROW = re.compile(r"^\|")

# Module sections that contain real screen rows
INCLUDE_SECTIONS = {
    "FUNDRAISING MODULE",
    "CONTACTS MODULE",
    "COMMUNICATION MODULE",
    "ORGANIZATION MODULE",
    "CASE MANAGEMENT MODULE",
    "VOLUNTEER MODULE",
    "MEMBERSHIP MODULE",
    "GRANTS MODULE",
    "FIELD COLLECTION MODULE",
    "ADMINISTRATION MODULE",
    "SETTINGS MODULE",
    "AI INTELLIGENCE MODULE",
    "REPORTS MODULE",
    "MOBILE MODULE",
    "ROOT / LAYOUT",
}


MODULE_DISPLAY = {
    "FUNDRAISING": "Fundraising",
    "CONTACTS": "Contacts",
    "COMMUNICATION": "Communication",
    "ORGANIZATION": "Organization",
    "CASE MANAGEMENT": "Case Management",
    "VOLUNTEER": "Volunteer",
    "MEMBERSHIP": "Membership",
    "GRANTS": "Grants",
    "FIELD COLLECTION": "Field Collection",
    "ADMINISTRATION": "Administration",
    "SETTINGS": "Settings",
    "AI INTELLIGENCE": "AI Intelligence",
    "REPORTS": "Reports",
    "MOBILE": "Mobile",
    "ROOT / LAYOUT": "Root / Layout",
}


def clean_module(raw: str) -> str:
    name = raw.strip()
    if name.endswith(" MODULE"):
        name = name[: -len(" MODULE")]
    return MODULE_DISPLAY.get(name, name.title())


def parse_row(line: str) -> list[str] | None:
    parts = [p.strip() for p in line.strip().strip("|").split("|")]
    if len(parts) < 9:
        return None
    if parts[0] in {"#", ""} or set(parts[0]) <= {"-", " "}:
        return None
    return parts


def dev_testing_status(dev_status: str) -> str:
    if dev_status == "COMPLETED":
        return "Pending"
    if dev_status == "NEEDS_FIX":
        return "Blocked - Awaiting Fix"
    if dev_status.startswith("SKIP"):
        return "N/A (Upcoming)"
    return "Not Started"


def qa_testing_status(dev_status: str) -> str:
    if dev_status.startswith("SKIP"):
        return "N/A (Upcoming)"
    return "Not Started"


def short_notes(notes: str, limit: int = 250) -> str:
    notes = notes.replace("\n", " ").replace("\r", " ").strip()
    if len(notes) > limit:
        notes = notes[: limit - 3].rstrip() + "..."
    return notes


def main() -> None:
    rows_by_id: dict[str, dict] = {}
    current_module: str | None = None

    with REGISTRY.open(encoding="utf-8") as f:
        for line in f:
            m = MODULE_HEADER.match(line)
            if m:
                section_name = m.group(1).strip()
                if section_name in INCLUDE_SECTIONS:
                    current_module = clean_module(section_name)
                else:
                    current_module = None
                continue
            if SUB_HEADER.match(line):
                current_module = None
                continue
            if not current_module or not DATA_ROW.match(line):
                continue
            parts = parse_row(line)
            if parts is None:
                continue
            screen_id, screen_name, _, _, screen_type, priority, status, _, notes = parts[:9]
            if not screen_id:
                continue
            existing = rows_by_id.get(screen_id)
            new_priority = STATUS_PRIORITY.get(status, 0)
            if existing and STATUS_PRIORITY.get(existing["status"], 0) >= new_priority:
                continue
            rows_by_id[screen_id] = {
                "id": screen_id,
                "module": current_module,
                "screen": screen_name,
                "type": screen_type,
                "priority": priority,
                "status": status,
                "notes": notes,
            }

    sorted_rows = sorted(
        rows_by_id.values(),
        key=lambda r: _id_sort(r["id"]),
    )

    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with OUT_CSV.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
        writer.writerow([
            "Screen #",
            "Module",
            "Screen Name",
            "Type",
            "Priority",
            "Development Status",
            "Development Done By",
            "Dev Testing Status",
            "Dev Tested By",
            "QA Testing Status",
            "QA Tested By",
        ])
        for r in sorted_rows:
            writer.writerow([
                r["id"],
                r["module"],
                r["screen"],
                r["type"],
                r["priority"],
                DEV_STATUS_LABEL.get(r["status"], r["status"]),
                dev_done_by(r["status"]),
                dev_testing_status(r["status"]),
                "",  # Dev Tested By — pick from dropdown after testing
                qa_testing_status(r["status"]),
                "",  # QA Tested By — pick from dropdown after testing
            ])

    # Roll-up summary
    by_status: dict[str, int] = {}
    for r in sorted_rows:
        label = DEV_STATUS_LABEL.get(r["status"], r["status"])
        by_status[label] = by_status.get(label, 0) + 1

    write_html(sorted_rows, by_status)
    write_xlsx(sorted_rows)

    print(f"Wrote {len(sorted_rows)} rows -> {OUT_CSV}")
    print(f"Wrote HTML view -> {OUT_HTML}")
    print(f"Wrote XLSX view -> {OUT_XLSX}")
    print("\nBy Development Status:")
    for label, count in sorted(by_status.items(), key=lambda x: -x[1]):
        print(f"  {label:35s} {count:3d}")


def html_class(label: str) -> str:
    if label.startswith("Completed - Needs"):
        return "needs-fix"
    if label.startswith("Completed"):
        return "completed"
    if label.startswith("Ready"):
        return "ready"
    if label.startswith("In Progress"):
        return "partial"
    if label.startswith("Not Started"):
        return "not-started"
    if label.startswith("Upcoming") or label.startswith("N/A (Upcoming"):
        return "upcoming"
    if label.startswith("Pending"):
        return "pending"
    if label.startswith("Blocked"):
        return "blocked"
    return ""


# Status → (fill ARGB hex, font ARGB hex). ARGB has 'FF' alpha prefix.
XLSX_FILL = {
    "completed":   ("FFDCFCE7", "FF166534"),  # green
    "needs-fix":   ("FFFEF3C7", "FF92400E"),  # amber
    "ready":       ("FFDBEAFE", "FF1E40AF"),  # blue
    "partial":     ("FFFEF9C3", "FF854D0E"),  # yellow
    "not-started": ("FFF3F4F6", "FF4B5563"),  # gray
    "upcoming":    ("FFE0E7FF", "FF3730A3"),  # indigo (distinct from gray)
    "pending":     ("FFEDE9FE", "FF6B21A8"),  # purple
    "in-testing":  ("FFCFFAFE", "FF155E75"),  # cyan (distinct from pending purple)
    "blocked":     ("FFFEE2E2", "FF991B1B"),  # red
}

# Each picklist value -> the color klass it should paint when chosen.
STATUS_COLOR_BY_LABEL = {
    "Completed": "completed",
    "Completed - Needs Fix": "needs-fix",
    "Ready to Build": "ready",
    "In Progress (Partial)": "partial",
    "Not Started": "not-started",
    "Upcoming (Dashboard)": "upcoming",
    "Upcoming (Config)": "upcoming",
    "Upcoming (Mobile)": "upcoming",
    "Upcoming": "upcoming",
    "Pending": "pending",
    "In Testing": "in-testing",
    "Passed": "completed",
    "Failed": "blocked",
    "Issues Found": "needs-fix",
    "Blocked - Awaiting Fix": "blocked",
    "N/A (Upcoming)": "upcoming",
}


def write_html(rows: list[dict], by_status: dict[str, int]) -> None:
    from html import escape

    today = __import__("datetime").date.today().isoformat()
    total = len(rows)

    summary_cards = "".join(
        f"<div class='card {html_class(label)}'><span class='count'>{count}</span><span class='label'>{escape(label)}</span></div>"
        for label, count in sorted(by_status.items(), key=lambda x: -x[1])
    )

    table_rows = []
    for r in rows:
        dev_label = DEV_STATUS_LABEL.get(r["status"], r["status"])
        dev_test = dev_testing_status(r["status"])
        qa_test = qa_testing_status(r["status"])
        dev_by = dev_done_by(r["status"])
        dev_by_cell = f"<span class='person'>{escape(dev_by)}</span>" if dev_by else "—"
        table_rows.append(
            "<tr>"
            f"<td class='id'>#{escape(r['id'])}</td>"
            f"<td>{escape(r['module'])}</td>"
            f"<td class='screen'>{escape(r['screen'])}</td>"
            f"<td>{escape(r['type'])}</td>"
            f"<td>{escape(r['priority'])}</td>"
            f"<td><span class='badge {html_class(dev_label)}'>{escape(dev_label)}</span></td>"
            f"<td class='by'>{dev_by_cell}</td>"
            f"<td><span class='badge {html_class(dev_test)}'>{escape(dev_test)}</span></td>"
            f"<td class='by'>—</td>"
            f"<td><span class='badge {html_class(qa_test)}'>{escape(qa_test)}</span></td>"
            f"<td class='by'>—</td>"
            "</tr>"
        )

    html = f"""<!DOCTYPE html>
<html lang='en'>
<head>
<meta charset='UTF-8'>
<title>PSS 2.0 — Screen Status Overview</title>
<style>
:root {{
  --c-completed:  #16a34a;
  --c-needs-fix:  #d97706;
  --c-ready:      #2563eb;
  --c-partial:    #ca8a04;
  --c-not-started:#6b7280;
  --c-upcoming:   #6366f1;
  --c-pending:    #7c3aed;
  --c-blocked:    #dc2626;
  --bg:           #f9fafb;
  --fg:           #111827;
  --muted:        #6b7280;
  --border:       #e5e7eb;
  --card-bg:      #ffffff;
}}
* {{ box-sizing: border-box; }}
body {{
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: var(--bg); color: var(--fg);
  margin: 0; padding: 24px;
}}
h1 {{ margin: 0 0 4px; font-size: 22px; }}
.meta {{ color: var(--muted); font-size: 13px; margin-bottom: 24px; }}
.summary {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; margin-bottom: 28px; }}
.card {{
  background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px;
  padding: 14px 16px; display: flex; flex-direction: column; gap: 4px;
  border-left: 4px solid var(--muted);
}}
.card.completed   {{ border-left-color: var(--c-completed); }}
.card.needs-fix   {{ border-left-color: var(--c-needs-fix); }}
.card.ready       {{ border-left-color: var(--c-ready); }}
.card.partial     {{ border-left-color: var(--c-partial); }}
.card.not-started {{ border-left-color: var(--c-not-started); }}
.card.upcoming    {{ border-left-color: var(--c-upcoming); }}
.count {{ font-size: 28px; font-weight: 700; }}
.label {{ font-size: 12px; color: var(--muted); }}
table {{
  width: 100%; border-collapse: collapse; background: var(--card-bg);
  font-size: 13px; border: 1px solid var(--border); border-radius: 8px; overflow: hidden;
}}
th, td {{ padding: 10px 12px; text-align: left; border-bottom: 1px solid var(--border); vertical-align: top; }}
th {{ background: #f3f4f6; font-weight: 600; font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em; color: var(--muted); }}
tr.module-divider td {{
  background: #eef2ff; color: #1e3a8a; font-weight: 700; font-size: 13px;
  letter-spacing: 0.04em; text-transform: uppercase; padding: 8px 12px;
}}
td.id {{ color: var(--muted); white-space: nowrap; font-variant-numeric: tabular-nums; }}
td.screen {{ font-weight: 500; }}
td.by {{ color: var(--muted); font-size: 12px; text-align: center; }}
.person {{ color: var(--fg); font-weight: 500; }}
.badge {{
  display: inline-block; padding: 3px 10px; border-radius: 999px;
  font-size: 11px; font-weight: 600; white-space: nowrap;
  background: #e5e7eb; color: #374151;
}}
.badge.completed   {{ background: #dcfce7; color: #166534; }}
.badge.needs-fix   {{ background: #fef3c7; color: #92400e; }}
.badge.ready       {{ background: #dbeafe; color: #1e40af; }}
.badge.partial     {{ background: #fef9c3; color: #854d0e; }}
.badge.not-started {{ background: #f3f4f6; color: #4b5563; }}
.badge.upcoming    {{ background: #e0e7ff; color: #3730a3; }}
.badge.pending     {{ background: #ede9fe; color: #6b21a8; }}
.badge.blocked     {{ background: #fee2e2; color: #991b1b; }}
.legend {{ font-size: 12px; color: var(--muted); margin-top: 16px; line-height: 1.7; }}
.legend code {{ background: #f3f4f6; padding: 2px 6px; border-radius: 4px; }}
</style>
</head>
<body>
<h1>PSS 2.0 — Screen Status Overview</h1>
<p class='meta'>Total screens: {total} &nbsp;·&nbsp; Generated: {today} &nbsp;·&nbsp; Source: <code>.claude/screen-tracker/REGISTRY.md</code></p>

<div class='summary'>{summary_cards}</div>

<table>
<thead>
<tr>
  <th>#</th><th>Module</th><th>Screen</th><th>Type</th><th>Priority</th>
  <th>Development Status</th><th>Dev By</th>
  <th>Dev Testing</th><th>Dev Tested By</th>
  <th>QA Testing</th><th>QA Tested By</th>
</tr>
</thead>
<tbody>
{''.join(table_rows)}
</tbody>
</table>

<p class='legend'>
<strong>Development Status:</strong>
<span class='badge completed'>Completed</span> built &amp; verified ·
<span class='badge needs-fix'>Completed - Needs Fix</span> built but open ISSUEs ·
<span class='badge ready'>Ready to Build</span> prompt ready, awaiting build ·
<span class='badge partial'>In Progress (Partial)</span> partial code, needs alignment ·
<span class='badge not-started'>Not Started</span> nothing exists yet ·
<span class='badge upcoming'>Upcoming</span> deferred to a later phase (dashboards / mobile / config).<br>
<strong>Dev Testing:</strong>
<span class='badge pending'>Pending</span> ready for developer self-test ·
<span class='badge not-started'>Not Started</span> blocked on Dev completion ·
<span class='badge blocked'>Blocked - Awaiting Fix</span> dev raised, fix pending.<br>
<strong>QA Testing:</strong>
<span class='badge not-started'>Not Started</span> awaiting Dev Testing pass first.
</p>
</body>
</html>
"""

    OUT_HTML.parent.mkdir(parents=True, exist_ok=True)
    OUT_HTML.write_text(html, encoding="utf-8")


def write_xlsx(rows: list[dict]) -> None:
    from openpyxl import Workbook
    from openpyxl.styles import Alignment, Font, PatternFill, Border, Side
    from openpyxl.utils import get_column_letter
    from openpyxl.worksheet.datavalidation import DataValidation
    from openpyxl.formatting.rule import CellIsRule

    wb = Workbook()
    ws = wb.active
    ws.title = "Screen Status"

    headers = [
        "Screen #",
        "Module",
        "Screen Name",
        "Type",
        "Priority",
        "Development Status",
        "Development Done By",
        "Dev Testing Status",
        "Dev Tested By",
        "QA Testing Status",
        "QA Tested By",
    ]
    ws.append(headers)

    header_fill = PatternFill("solid", fgColor="FF1F2937")
    header_font = Font(bold=True, color="FFFFFFFF", size=11)
    thin_border = Border(
        left=Side(style="thin", color="FFE5E7EB"),
        right=Side(style="thin", color="FFE5E7EB"),
        top=Side(style="thin", color="FFE5E7EB"),
        bottom=Side(style="thin", color="FFE5E7EB"),
    )
    for col_idx, _ in enumerate(headers, start=1):
        cell = ws.cell(row=1, column=col_idx)
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = Alignment(horizontal="left", vertical="center")
        cell.border = thin_border
    ws.row_dimensions[1].height = 28

    for r in rows:
        dev_label = DEV_STATUS_LABEL.get(r["status"], r["status"])
        dev_test = dev_testing_status(r["status"])
        qa_test = qa_testing_status(r["status"])
        ws.append([
            int(r["id"]) if r["id"].isdigit() else r["id"],
            r["module"],
            r["screen"],
            r["type"],
            r["priority"],
            dev_label,
            dev_done_by(r["status"]),
            dev_test,
            "",
            qa_test,
            "",
        ])

    # Apply colors per row
    for row_idx, r in enumerate(rows, start=2):
        dev_label = DEV_STATUS_LABEL.get(r["status"], r["status"])
        dev_test = dev_testing_status(r["status"])
        qa_test = qa_testing_status(r["status"])

        # Status cells: column 6 (Dev Status), column 8 (Dev Testing), column 10 (QA Testing)
        for col_idx, label in [(6, dev_label), (8, dev_test), (10, qa_test)]:
            klass = html_class(label)
            fill_argb, font_argb = XLSX_FILL.get(klass, ("FFFFFFFF", "FF111827"))
            cell = ws.cell(row=row_idx, column=col_idx)
            cell.fill = PatternFill("solid", fgColor=fill_argb)
            cell.font = Font(color=font_argb, bold=True, size=10)
            cell.alignment = Alignment(horizontal="center", vertical="center")

        # Apply border + alignment to all cells in row
        for col_idx in range(1, len(headers) + 1):
            cell = ws.cell(row=row_idx, column=col_idx)
            cell.border = thin_border
            if col_idx not in (6, 8, 10):
                cell.alignment = Alignment(horizontal="left", vertical="center", wrap_text=False)

    # Column widths tuned for readability
    widths = [10, 18, 32, 16, 14, 26, 22, 22, 22, 22, 22]
    for col_idx, width in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(col_idx)].width = width

    # Freeze header + first column
    ws.freeze_panes = "B2"

    # Filter dropdowns on header row
    last_row = len(rows) + 1
    ws.auto_filter.ref = f"A1:{get_column_letter(len(headers))}{last_row}"

    # ── Hidden lookup sheet for dropdown sources ──
    lookup = wb.create_sheet("Lookups")
    lookup["A1"] = "Development Status"
    lookup["B1"] = "Testing Status"
    lookup["C1"] = "Team Members"
    for i, val in enumerate(DEV_STATUS_OPTIONS, start=2):
        lookup.cell(row=i, column=1, value=val)
    for i, val in enumerate(TESTING_STATUS_OPTIONS, start=2):
        lookup.cell(row=i, column=2, value=val)
    for i, val in enumerate(TEAM_MEMBERS, start=2):
        lookup.cell(row=i, column=3, value=val)
    lookup.column_dimensions["A"].width = 24
    lookup.column_dimensions["B"].width = 24
    lookup.column_dimensions["C"].width = 16
    lookup.sheet_state = "hidden"  # hide from end-users; visible via Format > Sheet > Unhide

    def _add_dv(col_letter: str, source_range: str, prompt: str, title: str, error: str) -> None:
        dv = DataValidation(
            type="list",
            formula1=f"=Lookups!{source_range}",
            allow_blank=True,
            showDropDown=False,  # openpyxl quirk: False = SHOW the dropdown arrow
        )
        dv.error = error
        dv.errorTitle = "Invalid value"
        dv.prompt = prompt
        dv.promptTitle = title
        dv.add(f"{col_letter}2:{col_letter}{last_row}")
        ws.add_data_validation(dv)

    # Status column dropdowns
    _add_dv(
        "F",
        f"$A$2:$A${len(DEV_STATUS_OPTIONS) + 1}",
        "Pick a development status from the list.",
        "Development Status",
        "Choose one of the predefined development statuses.",
    )
    _add_dv(
        "H",
        f"$B$2:$B${len(TESTING_STATUS_OPTIONS) + 1}",
        "Pick the developer testing status.",
        "Dev Testing Status",
        "Choose one of the predefined testing statuses.",
    )
    _add_dv(
        "J",
        f"$B$2:$B${len(TESTING_STATUS_OPTIONS) + 1}",
        "Pick the QA testing status.",
        "QA Testing Status",
        "Choose one of the predefined testing statuses.",
    )

    # "By" column dropdowns (team members)
    for col_letter in ("G", "I", "K"):
        _add_dv(
            col_letter,
            f"$C$2:$C${len(TEAM_MEMBERS) + 1}",
            "Pick: " + ", ".join(TEAM_MEMBERS),
            "Team member",
            "Please select a team member from the list.",
        )

    # ── Conditional formatting: cell color updates when dropdown value changes ──
    # Apply to the three status columns. Static fills set during write are
    # overridden by these rules at runtime, so picking a different value
    # immediately re-colors the cell.
    status_columns = [
        ("F", DEV_STATUS_OPTIONS),
        ("H", TESTING_STATUS_OPTIONS),
        ("J", TESTING_STATUS_OPTIONS),
    ]
    for col_letter, options in status_columns:
        cell_range = f"{col_letter}2:{col_letter}{last_row}"
        for label in options:
            klass = STATUS_COLOR_BY_LABEL.get(label, "not-started")
            fill_argb, font_argb = XLSX_FILL[klass]
            rule = CellIsRule(
                operator="equal",
                formula=[f'"{label}"'],
                fill=PatternFill("solid", fgColor=fill_argb),
                font=Font(color=font_argb, bold=True, size=10),
            )
            ws.conditional_formatting.add(cell_range, rule)

    OUT_XLSX.parent.mkdir(parents=True, exist_ok=True)
    wb.save(OUT_XLSX)


def _id_sort(id_str: str) -> tuple[int, str]:
    try:
        return (int(id_str), "")
    except ValueError:
        m = re.match(r"^(\d+)", id_str)
        return (int(m.group(1)) if m else 9999, id_str)


if __name__ == "__main__":
    main()
