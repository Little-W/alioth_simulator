#!/usr/bin/env python3
"""
mem2bin.py  -  从 .mem 到带函数/调用图注释的反汇编文本

用法:
    python3 mem2bin.py <input.mem> [base_addr] [rv32|rv64]

输出:
    <input>_disasm_annotated.txt
"""
import sys, re, subprocess, os, textwrap
# ----------------------------------------------------------------------
def mem_to_bin(mem_path: str, bin_path: str):
    with open(mem_path, "r") as fin, open(bin_path, "wb") as fout:
        for line in fin:
            word = line.strip()
            if word:
                fout.write(bytes.fromhex(word)[::-1])       # RV 小端

# ----------------------------------------------------------------------
def objdump(bin_path: str, arch: str, vma: int) -> list[str]:
    arch_map = {"rv32": "riscv:rv32", "rv64": "riscv:rv64"}
    cmd = [
        "riscv64-unknown-elf-objdump",
        "-D", "-b", "binary",
        "--architecture", arch_map[arch],
        f"--adjust-vma={hex(vma)}",
        bin_path,
    ]
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT).decode()
        return out.splitlines()
    except subprocess.CalledProcessError as e:
        sys.exit("[objdump 错误]\n" + e.output.decode())

# ----------------------------------------------------------------------
def collect_function_entries(lines: list[str]) -> list[str]:
    """通过<符号>及 jal 目标地址收集入口"""
    entries = set()
    for ln in lines:
        if m := re.match(r'^([0-9a-f]+) <', ln):
            entries.add(m.group(1))
        if m := re.search(r'\bjal[ \t]+\w*,?[ \t]*0x([0-9a-f]+)', ln):
            entries.add(m.group(1))
    return sorted(entries, key=lambda x: int(x, 16))

# ----------------------------------------------------------------------
def annotate(lines: list[str], func_addrs: list[str]):
    func_set = set(func_addrs)
    call_graph: dict[str, set[str]] = {a: set() for a in func_addrs}
    exits: list[tuple[str, str]] = []                               # (addr, line)

    out, in_func, cur = [], False, None
    for ln in lines:
        addr_match = re.match(r'^([0-9a-f]+)(?=[: ])', ln.strip())
        addr = addr_match.group(1) if addr_match else None

        # ------ 函数入口 ------
        if addr and addr in func_set:
            if in_func:
                out.append(f"### FUNC_END   {cur} ###\n")
            cur, in_func = addr, True
            out.append(f"\n### FUNC_START {cur} ###\n")

        # ------ 收集调用关系 ------
        if in_func:
            if m := re.search(r'\bjal[ \t]+\w*,?[ \t]*0x([0-9a-f]+)', ln):
                callee = m.group(1)
                if callee in func_set:
                    call_graph[cur].add(callee)

        # ------ 探测退出点 ------
        if addr and (
            re.search(r'\becall\b', ln) or
            re.search(r'\bwfi\b', ln) or
            re.match(rf'\bjal\b[ \t]+\w*,?[ \t]*0x{addr}', ln)      # jal 自跳 = 死循环
        ):
            exits.append((addr, ln.strip()))

        out.append(ln if ln.endswith("\n") else ln + "\n")

        # 函数尾简单启发式: ret / jr ra / jalr x0
        if in_func and re.search(r'\bret\b|\bjr\s+ra\b|\bjalr\s+x0', ln):
            out.append(f"### FUNC_END   {cur} ###\n")
            in_func = False

    if in_func:                                                     # 文件尾
        out.append(f"### FUNC_END   {cur} ###\n")

    return out, call_graph, exits

# ----------------------------------------------------------------------
def call_graph_text(call_graph: dict[str, set[str]]) -> str:
    lines = ["\n===== CALL GRAPH ====="]
    for caller in sorted(call_graph, key=lambda x: int(x, 16)):
        callees = ", ".join(f"0x{c}" for c in sorted(call_graph[caller], key=lambda x: int(x, 16)))
        lines.append(f"0x{caller} -> {callees if callees else '(none)'}")
    return "\n".join(lines)

def exits_text(exits: list[tuple[str, str]]) -> str:
    if not exits:
        return "\n===== EXIT POINTS =====\n(未检测到 ecall / wfi / 死循环)"
    tbl = ["\n===== EXIT POINTS ====="]
    for addr, context in exits:
        tbl.append(f"0x{addr} : {context}")
    return "\n".join(tbl)

# ----------------------------------------------------------------------
def main():
    if len(sys.argv) < 2:
        sys.exit("用法: python3 mem2bin.py <input.mem> [base_addr] [rv32|rv64]")
    mem      = sys.argv[1]
    base     = int(sys.argv[2], 16) if len(sys.argv) > 2 else 0x80000000
    arch     = sys.argv[3] if len(sys.argv) > 3 else "rv32"

    binfile  = mem.replace(".mem", ".bin")
    txtfile  = mem.replace(".mem", "_disasm_annotated.asm")

    print(f"[+] 转换 {mem} → {binfile}")
    mem_to_bin(mem, binfile)

    print(f"[+] 反汇编并收集函数入口 …")
    disasm_lines   = objdump(binfile, arch, base)
    func_entries   = collect_function_entries(disasm_lines)
    annotated, cg, exits = annotate(disasm_lines, func_entries)

    print(f"[+] 共识别 {len(func_entries)} 个函数，生成调用图")
    with open(txtfile, "w") as fout:
        fout.writelines(annotated)
        fout.write(call_graph_text(cg))
        fout.write(exits_text(exits))
        fout.write("\n")
    print(f"[✓] 完成！结果已保存：{txtfile}")

if __name__ == "__main__":
    main()
