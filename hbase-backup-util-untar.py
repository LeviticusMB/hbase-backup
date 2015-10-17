#!/usr/bin/env python

import argparse, grp, pwd, os, sys, tarfile

def main(argv):
    parser = argparse.ArgumentParser(description='Extract a tar archive using simple I/O.', add_help = False)
    parser.add_argument('-?', '-h', '--help', help='Display this message and exit', action='store_true', dest='help')
    parser.add_argument('-v', '--verbose', help='Be verbose', action='store_true', dest='verbose')
    parser.add_argument('-U', '--unlink-first', help='Remove each file prior to extracting over it', action='store_true', dest='overwrite')
    parser.add_argument('-C', '--directory', metavar='destdir', help='Extract files to this base directory', dest='directory')
    parser.add_argument('--strip-components', metavar='NUMBER', type=int, help='Strip NUMBER leading components from file names on extraction', dest='strip')
    parser.add_argument('tarfile', metavar='tar-file', help='File to extract, if not stdin', nargs='?', action='store')

    args = parser.parse_args()

    if args.help:
        parser.print_help()
        sys.exit(0)

    directory = os.path.abspath(args.directory or '.')
    verbose   = args.verbose
    overwrite = args.overwrite
    tar_file  = args.tarfile or '/dev/stdin'
    strip     = args.strip or 0

    print 'Extracting tar archive %s to directory %s' % (tar_file, directory)

    tar = tarfile.open(tar_file, 'r|*')

    for entry in tar:
        name = split_path(entry.name)[strip:]

        if len(name) == 0:
            continue
        else:
            name = os.path.join(directory, *name)

        if entry.isdir():
            if not os.path.exists(name):
                if verbose:
                    print '[Creating directory] %s' % name
                os.mkdir(name)
                chown(name, entry)
            elif not os.path.isdir(name):
                raise RuntimeError('%s already exists and is not a directory!' % name)
            else:
                if verbose:
                    print '[Directory exists]   %s' % name
        elif entry.isfile():
            src = tar.extractfile(entry)

            if os.path.exists(name):
                if overwrite:
                    os.unlink(name)
                else:
                    print '[File exists]        %s' % name
                    continue

            if verbose:
                print '[Creating file]      %s' % name

            with open(name, 'wb') as dst:
                chown(name, entry)

                while True:
                    buffer = src.read(65536)
                    if not buffer:
                        break
                    dst.write(buffer)
        else:
            print 'Ignoring unknown object %s' % entry.name

def chown(name, entry):
    uid = entry.uid
    gid = entry.gid

    try:
        uid = pwd.getpwnam(entry.uname).pw_uid
        gid = pwd.getgrnam(entry.gname).gr_gid
    except:
        None

    try:
        os.chown(name, uid, gid)
    except OSError as err:
        print '[chown() failed]     %s' % name

def split_path(p):
    a, b = os.path.split(p)
    return (split_path(a) if len(a) else []) + [b]

if __name__ == "__main__":
   main(sys.argv[1:])
