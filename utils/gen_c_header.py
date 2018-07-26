import sys
from collections import defaultdict

from verilog_util import Direction, dir_to_str, process_file

filename = sys.argv[1]
mod = process_file(filename)
base = sys.argv[2] if len(sys.argv) >= 3 else mod.name

def size_ty(port):
    size = int(port.range_upper) - int(port.range_lower) + 1
    if size <= 8:
        return "CData"
    elif size <= 16:
        return "SData"
    elif size <= 32:
        return "IData"
    elif size <= 64:
        return "QData"
    else:
        return "WData"

def ptr_ty(port):
    size = int(port.range_upper) - int(port.range_lower) + 1
    return size > 64

inputs = sorted((port for port in mod.ports
                 if port.direction == Direction.INPUT),
                key=lambda p: p.name)
outputs = sorted((port for port in mod.ports
                  if port.direction == Direction.OUTPUT),
                 key=lambda p: p.name)


def port_str(port):
    return "  {} *{};{}/* {}:{} */".format(
        size_ty(port),
        port.name,
        " " * (30-len(port.name)),
        port.range_upper,
        port.range_lower,
    )

print("struct {}_ports {{".format(base))
print("  /* Inputs */")
for port in inputs:
    print(port_str(port))
print("")
print("  /* Outputs */")
for port in outputs:
    print(port_str(port))
print("};")
print("")

def connect_str(port):
    return "    (str)->{} = {}((cla)->{}); \\".format(
        port.name,
        '' if ptr_ty(port) else '&',
        port.name
    )

print("#define {}_CONNECT(str, cla) \\".format(base))
print("  do { \\")
for port in inputs:
    print(connect_str(port))
print("    \\")
for port in outputs:
    print(connect_str(port))
print("  } while(0)")
