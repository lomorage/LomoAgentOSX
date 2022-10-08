#!/usr/bin/env python3

# TODO: handle LC_UNIXTHREAD register content parsing

import sys
import os
import pprint
import re
import tempfile
import subprocess

def line_to_fields_pair(line):
    # Time stamp format: %u %(ctime)s
    # Example:
    #    time stamp 2 Thu Jan  1 08:00:02 1970
    # Producer Code:
    #   printf("\ttime stamp %u ", dl.dylib.timestamp);
    #   timestamp = (time_t)dl.dylib.timestamp;
    #   printf("%s", ctime(&timestamp));
    l = line.lstrip()
    if l.startswith('time stamp '):
        return ['time stamp', l[len('time stamp '):-1]]
    fields = line.rsplit(maxsplit=1)
    # Handle parenthesis
    #    align 2^4 (16)
    #    reserved2 6 (size of stubs)
    #    reserved1 40 (index into indirect symbol table)
    #    align 2^4 (16)
    #    name /usr/lib/dyld (offset 12)
    #    path /Users/user/Qt/5.6/clang_64/lib (offset 12)

    if len(fields) > 1 and fields[1].endswith(')'):
        (f0, f1) = fields
        # f1 could be '(16)' or
        #             'offset 12)' with the '(' in f0
        t = f0.rsplit(sep='(', maxsplit=1)
        if len(t) == 2:
            f1 = '(' + t[1] + ' ' + f1
            f0 = t[0]
        t = f0.rsplit(maxsplit=1)
        if len(t) > 1:
            fields = [ t[0], t[1] + ' ' + f1 ]
    fields[0] = fields[0].strip()
    if len(fields) == 1:
        fields.append('')
    return fields

def do_load_commands_parse(lines):
    #MY-Binary:
    #Load command 0
    #      cmd LC_SEGMENT_64
    #  cmdsize 72
    #  segname __PAGEZERO
    #   vmaddr 0x0000000000000000
    #   vmsize 0x0000000100000000
    #  fileoff 0
    # filesize 0
    #  maxprot 0x00000000
    # initprot 0x00000000
    #   nsects 0
    #    flags 0x0
    #Load command 1
    # ...
    #Section
    #compatibility version 5.6.0
    out = [] 
    for i in lines:
        h = i[0]
        if not h.isspace() and h.isupper():
            if out:
                yield out
            out = [ i ]
        else:
            out.append(i)
    if out:
        yield out

def otool_load_commands_parse(lines):
    out = []
    for i in do_load_commands_parse(lines):
        if len(i) == 1:
            l = i[0].strip()
            if l.endswith(':'):
                o = {'binary': l[:-1]}
            else:
                o = dict([line_to_fields_pair(l)])
        else:
            for x in i:
                f = line_to_fields_pair(x)
                if len(f) != 2:
                    raise ValueError
            o = dict([line_to_fields_pair(x) for x in i])
        out.append(o)
    return out

def otool_rpath(args):
    # Look for:
    #   Load command 18
    #   cmd LC_RPATH
    #   cmdsize 48
    #   path /Users/user/Qt/5.6/clang_64/lib (offset 12)

    def print_usage_exit():
        sys.stderr.write('usage: %s MACHO_FILE\n' % (program_name(),))
        sys.exit(2)

    def find_rpaths(load_commands):
        r = re.compile(r'[\s]\(offset [\d]+\)$')
        for i in load_commands:
            if i.get('cmd') == 'LC_RPATH':
                p = i['path']
                m = r.search(p)
                if m:
                    yield p[:m.span()[0]]
                else:
                    yield p

    try:
        (macho_binary,) = args
    except ValueError:
        print_usage_exit()

    tf = tempfile.TemporaryFile(mode='w+')
    subprocess.check_call(['otool', '-l', macho_binary], stdout=tf)
    tf.seek(0)
    l = otool_load_commands_parse(tf)

    ret = []
    for i in find_rpaths(l):
        print(i)
        if not i.startswith('@'):
            ret.append(i)

    return ret

def program_name():
    return os.path.basename(sys.argv[0])

if __name__ == '__main__':
    otool_rpath(sys.argv[1:])
