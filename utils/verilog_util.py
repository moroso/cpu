class Direction:
    INPUT = 0
    OUTPUT = 1
    # TODO: bidir?

def dir_to_str(d):
    if d == Direction.INPUT:
        return "input"
    else:
        return "output"

class Port:
    def __init__(self, name, direction, range_upper, range_lower):
        self.name = name
        self.direction = direction
        self.range_upper = range_upper
        self.range_lower = range_lower

    def __str__(self):
        if self.empty_range():
            return "{} {}".format(
                dir_to_str(self.direction),
                self.name
            )
        else:
            return "{} [{}:{}] {}".format(
                dir_to_str(self.direction),
                self.range_upper, self.range_lower,
                self.name
            )

    def __repr__(self):
        return "PORT:'{}'".format(self)

    def empty_range(self):
        return self.range_upper == self.range_lower == 0

class Module:
    def __init__(self, name, ports):
        self.name = name
        self.ports = ports

def process_file(fname):
    '''
    AD-HOC VERILOG PARSING FTW!!!

    (If it's not obvious, this makes a lot of assumptions about the formatting of the
    file and will fail badly on plenty of perfectly valid files. You've been warned.)
    '''
    modname = ''
    ports = []
    with open(fname, 'r') as f:
        for line in f:
            l = line.strip()
            toks = l.split()
            if toks and toks[0] == 'module':
                assert not modname, "Multiple modules in file"
                modname = toks[1].split('(')[0]
            if toks and toks[0] in ('input', 'output'):
                direction = Direction.INPUT if toks[0] == 'input' else Direction.OUTPUT
                name = toks[-1].split(',')[0].split(')')[0].split(';')[0]
                if '[' in l:
                    range_str = l[l.index('[')+1:l.index(']')]
                    upper, lower = range_str.split(':')
                else:
                    upper, lower = 0, 0
                port = Port(name, direction, upper, lower)
                ports.append(port)
    assert modname, "Cannot extract module name from {}".format(fname)
    return Module(modname, ports)
