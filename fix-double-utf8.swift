#!/usr/bin/env xcrun swift -g
// Fix doubly UTF8 encoded file names

// entry point is at the bottom
// TODO: protect against looping when recursively traversing directories

import Foundation;

var verbose = 0;        // verbosity level
var dryrun = false;     // don't actually do anything
var recurse = false;    // recursively traverse directories
let fmgr = NSFileManager.defaultManager();

class Combiner {
    private var memoizer: Dictionary<String, UnicodeScalar>

    init()
    {
        memoizer = [:];
    }
    func lookup(base: UnicodeScalar, _ combi: UnicodeScalar) -> UnicodeScalar
    {
        // this is a total hack and I'm sure there's a better way, but this is
        // good enough for this program. This hunts for an 8-bit character that
        // swift considers to be the same grapheme as the combined character
        let combined = "\(base)\(combi)";
        let rslt = memoizer[combined];
        if let y = rslt { return y }

        for i in 0x80...0xFF {
            let ch = UnicodeScalar(i);
            let v = String(ch);

            if String(ch) == combined {
                memoizer[combined] = ch;
                return ch;
            }
        }
        let ch = UnicodeScalar(0xFFFD); // Unicode replacement character �
        memoizer[combined] = ch;
        return ch;
    }
};
var combiner = Combiner();

enum FixResult {
    case NoChange
    case Fixed(String)
    case Error
}

func FixDoubleUTF8(name: String) -> FixResult
{
    var isASCII = true;
    var y: [UInt8] = [];

    for ch in name.unicodeScalars {
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
        if y.count == 0 { return FixResult.NoChange }

        let last = y.removeLast();
        let repl = combiner.lookup(UnicodeScalar(last), ch);
        // the replacement needs to be in the UTF8 range
        if repl.value >= 0x100 { return FixResult.NoChange }

        y.append(UInt8(repl));
    }
    if isASCII { return FixResult.NoChange }

    y.append(0); // null terminator
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

func ProcessName(dirname: String, basename: String)
{
    if verbose > 3 { println("considering '\(basename)'") }

    switch (FixDoubleUTF8(basename)) {
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

#if !TESTING

// MARK: Main is called here
Main(Process.arguments[0], Process.arguments[1..<Process.arguments.count]);

#else

let test = [
    "ãPDA FTãããã²å»äººã·ã¥ãã¬ãã³ã¼ã«ãå·¡é³ã«ã«ï¼ã¹ã¤ã ã¦ã§ã¢ï¼ã¹ã¤ã ã¦ã§ã¢PãPV [720p].mp4",
    "\u{61}\u{303}\u{80}\u{90}\u{50}\u{44}\u{41}\u{20}\u{46}\u{54}\u{61}\u{303}\u{80}\u{91}\u{61}\u{303}\u{83}\u{8D}\u{61}\u{303}\u{83}\u{88}\u{61}\u{303}\u{82}\u{B2}\u{61}\u{30A}\u{BB}\u{83}\u{61}\u{308}\u{BA}\u{BA}\u{61}\u{303}\u{82}\u{B7}\u{61}\u{303}\u{83}\u{A5}\u{61}\u{303}\u{83}\u{97}\u{61}\u{303}\u{83}\u{AC}\u{61}\u{303}\u{83}\u{92}\u{61}\u{303}\u{82}\u{B3}\u{61}\u{303}\u{83}\u{BC}\u{61}\u{303}\u{83}\u{AB}\u{61}\u{303}\u{80}\u{90}\u{61}\u{30A}\u{B7}\u{A1}\u{65}\u{301}\u{9F}\u{B3}\u{61}\u{303}\u{83}\u{AB}\u{61}\u{303}\u{82}\u{AB}\u{69}\u{308}\u{BC}\u{9A}\u{61}\u{303}\u{82}\u{B9}\u{61}\u{303}\u{82}\u{A4}\u{61}\u{303}\u{83}\u{A0}\u{61}\u{303}\u{82}\u{A6}\u{61}\u{303}\u{82}\u{A7}\u{61}\u{303}\u{82}\u{A2}\u{69}\u{308}\u{BC}\u{8F}\u{61}\u{303}\u{82}\u{B9}\u{61}\u{303}\u{82}\u{A4}\u{61}\u{303}\u{83}\u{A0}\u{61}\u{303}\u{82}\u{A6}\u{61}\u{303}\u{82}\u{A7}\u{61}\u{303}\u{82}\u{A2}\u{50}\u{61}\u{303}\u{80}\u{91}\u{50}\u{56}\u{20}\u{5B}\u{37}\u{32}\u{30}\u{70}\u{5D}\u{2E}\u{6D}\u{70}\u{34}",
    "\u{E3}\u{80}\u{90}PDA FT\u{E3}\u{80}\u{91}\u{E3}\u{83}\u{8D}\u{E3}\u{83}\u{88}\u{E3}\u{82}\u{B2}\u{61}\u{30A}\u{BB}\u{83}\u{61}\u{308}\u{BA}\u{BA}\u{E3}\u{82}\u{B7}\u{E3}\u{83}\u{A5}\u{E3}\u{83}\u{97}\u{E3}\u{83}\u{AC}\u{E3}\u{83}\u{92}\u{E3}\u{82}\u{B3}\u{E3}\u{83}\u{BC}\u{E3}\u{83}\u{AB}\u{E3}\u{80}\u{90}\u{61}\u{30A}\u{B7}\u{A1}\u{65}\u{301}\u{9F}\u{B3}\u{E3}\u{83}\u{AB}\u{E3}\u{82}\u{AB}\u{69}\u{308}\u{BC}\u{9A}\u{E3}\u{82}\u{B9}\u{E3}\u{82}\u{A4}\u{E3}\u{83}\u{A0}\u{E3}\u{82}\u{A6}\u{E3}\u{82}\u{A7}\u{E3}\u{82}\u{A2}\u{69}\u{308}\u{BC}\u{8F}\u{E3}\u{82}\u{B9}\u{E3}\u{82}\u{A4}\u{E3}\u{83}\u{A0}\u{E3}\u{82}\u{A6}\u{E3}\u{82}\u{A7}\u{E3}\u{82}\u{A2}\u{50}\u{E3}\u{80}\u{91}PV [720p].mp4"
];
let gold = "【PDA FT】ネトゲ廃人シュプレヒコール【巡音ルカ：スイムウェア／スイムウェアP】PV [720p].mp4";

for i in 0..<test.count {
    let tv = test[i];

    switch (FixDoubleUTF8(tv)) {
    case .NoChange:
        println("test failed; no change");
    case .Error:
        println("test failed; no conversion error");
    case let .Fixed(fixed):
        if fixed == gold { println("test passed") }
        else             { println("test failed") }
    }
}
#endif
