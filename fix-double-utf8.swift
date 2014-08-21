#!/usr/bin/env xcrun swift -O -g
// Fix doubly UTF8 encoded file names

// entry point is at the bottom
// TODO: protect against looping when recursively traversing directories

import Foundation;

var verbose = 0;        // verbosity level
var dryrun = false;     // don't actually do anything
var recurse = false;    // recursively traverse directories
var memoizer: Dictionary<String, UnicodeScalar> = [:]
let fmgr = NSFileManager.defaultManager();

enum FixResult {
    case NoChange
    case Fixed(String)
    case Error
}

func DoubleUTF8Fix(name: String) -> FixResult
{
    enum FixResult1 {
        case IsASCII
        case IsNotUTF8
        case UTF8([UInt8])
    }
    
    func TryFix(bad: String) -> FixResult1
    {
        var isASCII = true;
        var y: [UInt8] = [];

        func ShortCode(l: UnicodeScalar, c: UnicodeScalar) -> UnicodeScalar
        {
            let s = "\(l)\(c)";
            let r = memoizer[s];
            if let y = r { return y }

            for i in 0x80...0xFF {
                let ch = UnicodeScalar(i);
                let v = String(ch);

                if v == s {
                    memoizer[s] = ch;
                    return ch;
                }
            }
            return UnicodeScalar(0xFFFD); // Unicode replacement character �
        }
        for ch in bad.unicodeScalars {
            if ch.value < 0x80 {
                y.append(UInt8(ch));
                continue;
            }
            isASCII = false;

            if ch.value < 0x100 {
                y.append(UInt8(ch));
                continue;
            }
            // might be a combining character that when combined with the
            // preceeding character maps to a codepoint in the UTF8 range
            if y.count == 0 { return FixResult1.IsNotUTF8 }

            let last = y.removeLast();
            let repl = ShortCode(UnicodeScalar(last), ch);
            // the replacement needs to be in the UTF8 range
            if repl.value >= 0x100 { return FixResult1.IsNotUTF8 }

            y.append(UInt8(repl));
        }
        if isASCII { return FixResult1.IsASCII }

        y.append(0); // null terminator
        return FixResult1.UTF8(y);
    }
    let try = TryFix(name);
    switch (try) {
    case .IsASCII, .IsNotUTF8:
        return FixResult.NoChange;
    case let .UTF8(y):
        return y.withUnsafeBufferPointer {
            let cstr = UnsafePointer<CChar>($0.baseAddress);
            let rslt = String.fromCStringRepairingIllFormedUTF8(cstr);
            if let str = rslt.0 {
                if !rslt.1 { return FixResult.Fixed(str) }
                if verbose > 1 { println("'\(name)' -> '\(str)'") }
            }
            return FixResult.Error;
        }
    }
}

func ProcessName(dirname: String, basename: String)
{
    if verbose > 3 { println("considering '\(basename)'") }
    let try = DoubleUTF8Fix(basename);

    switch (try) {
    case .NoChange:
        if verbose > 2 { println("'\(basename)' doesn't need to be fixed") }
        return;
    case .Error:
        if verbose > 0 { println("'\(dirname.stringByAppendingPathComponent(basename))' would cause an error") }
        return;
    case let .Fixed(fixed):
        let baseFull = dirname.stringByAppendingPathComponent(basename);
        let fixedFull = dirname.stringByAppendingPathComponent(fixed);

        if verbose > 0 { println("renaming '\(baseFull) to '\(fixedFull)'") }
        if dryrun { return }
        if fmgr.moveItemAtPath(baseFull, toPath: fixedFull, error: nil) { return }
        println("Failed to rename '\(baseFull) to '\(fixedFull)'")
    }
}

func isDirectoryAtPath(path: String) -> Bool
{
    var isDir: ObjCBool = false;
    return fmgr.fileExistsAtPath(path, isDirectory: &isDir) ? isDir ? true : false : false
}

func ProcessDirectory(path: String)
{
    if verbose > 1 { println("examining directory '\(path)'") }

    let dir = fmgr.contentsOfDirectoryAtPath(path, error: nil)!;
    for name in filter(map(dir, { $0 as String }), { !$0.hasPrefix(".") }) {
        let fullname = path.stringByAppendingPathComponent(name);

        if isDirectoryAtPath(fullname) {
            ProcessName(path, name);
            if recurse { ProcessDirectory(fullname) }
        }
        else { ProcessName(path, name) }
    }
}

func ProcessDirectoryOrFile(path: String)
{
    if isDirectoryAtPath(path) {
        ProcessDirectory(path);
        return;
    }
    let dirname = path.stringByDeletingLastPathComponent;
    let basename = path.lastPathComponent;
    ProcessName(dirname, basename);
}

func Main(progname: String, arguments: Slice<String>)
{
    for arg in arguments {
        switch (arg) {
        case "-h", "-?", "--help":
            println("\(progname) [-h|-?|--help]|([-n|--dry-run] [-v|--verbose] [-r|--recurse] [input-file-or-directory] ...");
            return
        default:
            ();
        }
    }
    // TODO: better argument parsing
    for arg in arguments {
        switch (arg) {
        case "-n", "--dry-run":
            dryrun = true;
        case "-r", "--recurse":
            recurse = true;
        case "-v", "--verbose":
            ++verbose;
        default:
            ();
        }
    }
    var someArg = false;

    for arg in filter(arguments, { !$0.hasPrefix("-") }) {
        someArg = true;
        ProcessDirectoryOrFile(arg);
    }
    if someArg { return }
    ProcessDirectory(".");
}

// MARK: Main is called here
Main(Process.arguments[0], Process.arguments[1..<Process.arguments.count]);
