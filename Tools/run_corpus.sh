#!/usr/bin/env bash
# run_corpus.sh — 遍历 指针/** 全量 pack，汇总每个包的光标数与失败。
#
# 用法: bash Tools/run_corpus.sh <输出目录>
# 流程: make build → 对每个含 .ani 直接子文件的目录（find 指针 -mindepth 1 -maxdepth 2）跑 CLI pack，
#        逐包打印光标数，末尾打印「成功 ani / 总 ani」汇总。
set -u

OUT_DIR="${1:?用法: bash Tools/run_corpus.sh <输出目录>}"
BIN=".build/release/anicap"

echo "== make build =="
make build || { echo "❌ make build 失败"; exit 1; }

mkdir -p "$OUT_DIR"

total_ani=0
success_ani=0
pack_ok=0
pack_fail=0

echo
echo "== 全量 pack =="
while IFS= read -r d; do
    n_ani=$(find "$d" -maxdepth 1 -name '*.ani' -type f | wc -l | tr -d ' ')
    [ "${n_ani:-0}" -gt 0 ] || continue

    total_ani=$((total_ani + n_ani))
    # 输出名取目录路径（去 指针/ 前缀，斜杠转 __）避免同名目录覆盖
    slug=$(printf '%s' "$d" | sed 's|^指针/||; s|/|__|g')
    out="$OUT_DIR/$slug.cape"

    echo "--- pack $d ($n_ani 个 ani) ---"
    "$BIN" pack "$d" -o "$out"
    rc=$?

    if [ -f "$out" ]; then
        n_cur=$(python3 -c "import plistlib,sys; print(len(plistlib.load(open(sys.argv[1],'rb')).get('Cursors',{})))" "$out")
    else
        n_cur=0
    fi
    success_ani=$((success_ani + n_cur))

    if [ "$rc" -eq 0 ]; then
        pack_ok=$((pack_ok + 1))
    else
        pack_fail=$((pack_fail + 1))
        echo "   ❌ CLI 退出码 $rc"
    fi
    echo "   → $n_cur 个光标"
done < <(find 指针 -mindepth 1 -maxdepth 2 -type d | sort)

echo
echo "== 汇总 =="
echo "成功 ani / 总 ani = $success_ani / $total_ani"
echo "包：成功 ${pack_ok}，失败 ${pack_fail}"
echo "说明：4 个无 macOS 槽的中文角色（个人选择/位置选择/候选/手写，及英文 Handwriting/Alternate/Pin/Person）按设计跳过；"
echo "      编号命名的帧（如 宝钟玛琳/安装文件/1..17.ani）无角色映射，亦按设计跳过。"
