# Super hacky script to generate wrapper modules for verilog modules, for the sake
# of running synthesis to get an idea of the module's timing. Tries to ensure that
# the synthesis tool can't just optimize things out. If multiple modules are specified,
# ports with the same name will be connected (and not bubbled up as inputs/outputs
# to the wrapper module).

import sys
from collections import defaultdict

from verilog_util import Direction, dir_to_str, process_file

def process_modules(wrapper_name, modules, clocks, pll_name):
    all_ports = defaultdict(list)
    external_ports = set()
    internal_ports = set()

    # Figure out which ports need to appear as inputs/outputs to the wrapper module,
    # and which are wired up internally.
    for mod in modules:
        for port in mod.ports:
            all_ports[port.name].append(port)

    for portname, ports in all_ports.items():
        assert all(port.range_upper == ports[0].range_upper and
                   port.range_lower == ports[0].range_lower for port in ports), (
                       "Port {}: range mismatch".format(portname)
                   )
        if len(ports) == 1:
            # There's just one port with this name, so no internal connections.
            external_ports.add(ports[0])
        else:
            output_count = sum(1 for p in ports if p.direction == Direction.OUTPUT)
            assert output_count <= 1, "Port {} is driven by multiple modules".format(
                portname)
            if output_count == 0:
                external_ports.add(ports[0])
            else:
                internal_ports.add(ports[0])

    # Code generation starts here.

    def range_str(port):
        if port.empty_range():
            return ""
        else:
            return " [{}:{}]".format(port.range_upper, port.range_lower)

    print("module {}(".format(wrapper_name))
    def io_str(port):
        return "    {}{} {}{},".format(
            dir_to_str(port.direction),
            range_str(port),
            port.name,
            '_IN' if port.direction == Direction.INPUT else '')
    print("\n".join(sorted([io_str(p) for p in external_ports
                             if p.direction == Direction.INPUT and p.name not in clocks])))
    print("    output z,")
    if pll_name:
        print("    input clkin")
    else:
        print("    input clk")
    print(");\n")

    print("    // Internal wires:")
    for port in internal_ports:
        print("    wire{} {};".format(range_str(port), port.name))
    print("")
    print("    // Registers for external inputs:")
    for port in external_ports:
        if not port.direction == Direction.INPUT:
            continue
        if port.name in clocks:
            continue

        print("    reg{} {};".format(range_str(port), port.name))
    if pll_name:
        print("    wire clk;");

    print("    // Registers for external outputs:")
    for port in external_ports:
        if not port.direction == Direction.OUTPUT:
            continue
        if port.name in clocks:
            continue

        print("    reg{} {}_FLOPPED;".format(range_str(port), port.name))

    print("")

    if pll_name:
        print("    {} clk_inst(.refclk(clkin), .outclk_0(clk));".format(pll_name))

        print("")

    l = []
    for port in external_ports:
        if not port.direction == Direction.OUTPUT:
            continue
        l.append("{}_FLOPPED".format(port.name) if port.empty_range()
                 else '^{}_FLOPPED'.format(port.name))
    print("    assign z = {};".format(" ^ ".join(l)))

    print("")

    print("    always @(posedge clk) begin")
    for port in external_ports:
        if port.name in clocks:
            continue

        if port.direction == Direction.INPUT:
            print("        {} <= {}_IN;".format(port.name, port.name))
        else:
            print("        {}_FLOPPED <= {};".format(port.name, port.name))
    print("    end")

    print("")

    for mod in modules:
        print("    {} {}_inst(".format(mod.name, mod.name))
        l = []
        for port in mod.ports:
            if port.name in clocks:
                l.append("        .{}(clk)".format(port.name))
            else:
                l.append("        .{}({})".format(port.name, port.name))
        print(",\n".join(l))
        print("    );")

    print("endmodule")

filenames = [name for name in sys.argv[1:] if not name.startswith('-')]
args = [arg for arg in sys.argv[1:] if arg.startswith('-')]
clocks = []
wrapper_name = None
pll_name = None

def help():
    print("Usage: python3 {} file.v [file2.v ...] [-wname] [-cclkname ...] [-ppllname]"
          .format(sys.argv[0]))
    print("Flags:", file=sys.stderr)
    print("    -w<name>: set name of wrapper module", file=sys.stderr)
    print("    -c<clkname>: specify a port as being a clock (and use the clk signal)",
          file=sys.stderr)
    print("    -p<pllname>: specify the name of the PLL module, if one is desired",
          file=sys.stderr)
    exit(0)

if not filenames:
    help()

for arg in args:
    if arg.startswith('-w'):
        wrapper_name = arg[2:]
    elif arg.startswith('-c'):
        clocks.append(arg[2:])
    elif arg.startswith('-p'):
        pll_name = arg[2:]
    elif arg.startswith('-h'):
        help()
    else:
        assert False, "Unknown argument {}".format(arg)
if wrapper_name is None:
    wrapper_name = 'wrapper'

all_modules = set()
for filename in filenames:
    all_modules.add(process_file(filename))

process_modules(wrapper_name, all_modules, clocks, pll_name)
