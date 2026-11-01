#!/usr/bin/env python3
"""週報テキストから、コピーボタン付きHTMLを生成するスクリプト。

使い方の例です。

    # 今週（月〜金）と翌週の期間を自動計算してHTMLを生成し、ブラウザで開く
    python3 scripts/build_report.py -i examples/weekly-report-sample.txt -o 週報.html --open

    # 期間を明示する場合
    python3 scripts/build_report.py -i report.txt -o 週報.html \
        --period "作業内容: 2026/5/11（月）〜5/15（金） ／ 今後の作業予定: 5/18（月）〜5/22（金）"
"""

import argparse
import datetime
import html
import pathlib
import subprocess
import sys

TEMPLATE = pathlib.Path(__file__).resolve().parent.parent / "templates" / "report.html.tpl"
WEEKDAY_JA = ["月", "火", "水", "木", "金", "土", "日"]


def week_range(base: datetime.date) -> tuple[datetime.date, datetime.date]:
    """base を含む週の月曜と金曜を返す。"""
    monday = base - datetime.timedelta(days=base.weekday())
    return monday, monday + datetime.timedelta(days=4)


def fmt(d: datetime.date, with_year: bool = False) -> str:
    head = f"{d.year}/" if with_year else ""
    return f"{head}{d.month}/{d.day}（{WEEKDAY_JA[d.weekday()]}）"


def auto_period(base: datetime.date) -> str:
    this_mon, this_fri = week_range(base)
    next_mon = this_mon + datetime.timedelta(days=7)
    next_fri = next_mon + datetime.timedelta(days=4)
    return (
        f"作業内容: {fmt(this_mon, with_year=True)}〜{fmt(this_fri)}"
        f" ／ 今後の作業予定: {fmt(next_mon)}〜{fmt(next_fri)}"
    )


def build(body: str, period: str) -> str:
    template = TEMPLATE.read_text(encoding="utf-8")
    return template.replace("{{PERIOD}}", html.escape(period)).replace(
        "{{BODY}}", html.escape(body.rstrip("\n"))
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="週報HTMLを生成する")
    parser.add_argument(
        "-i", "--input", required=True, help="週報本文のテキストファイル（- で標準入力）"
    )
    parser.add_argument("-o", "--output", required=True, help="出力するHTMLファイル")
    parser.add_argument(
        "--period", help="ヘッダに表示する対象期間。省略時は今日の日付から自動計算"
    )
    parser.add_argument(
        "--date", help="自動計算の基準日（YYYY-MM-DD）。省略時は今日"
    )
    parser.add_argument(
        "--open", action="store_true", help="生成後にブラウザで開く（macOSのopenコマンド）"
    )
    args = parser.parse_args()

    if args.input == "-":
        body = sys.stdin.read()
    else:
        src = pathlib.Path(args.input)
        if not src.exists():
            print(f"入力ファイルが見つかりません: {src}", file=sys.stderr)
            return 1
        body = src.read_text(encoding="utf-8")

    base = (
        datetime.date.fromisoformat(args.date) if args.date else datetime.date.today()
    )
    period = args.period or auto_period(base)

    out = pathlib.Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(build(body, period), encoding="utf-8")
    print(f"生成しました: {out}")
    print(f"対象期間: {period}")

    if args.open:
        subprocess.run(["open", str(out)], check=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
