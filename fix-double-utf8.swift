#!/usr/bin/env xcrun swift -O
// Fix doubly UTF8 encoded file names

// entry point is at the bottom
// TODO: protect against looping when recursively traversing directories

import Foundation

private var verbose = 0         // verbosity level
private var dryrun = false      // don't actually do anything
private var recurse = false     // recursively traverse directories
private let fmgr = NSFileManager.defaultManager();

private func rename(path: String, from: String, to: String) -> NSError?
{
    if dryrun { return nil }
    var err: NSError?

    fmgr.moveItemAtPath(path.stringByAppendingPathComponent(from), toPath: path.stringByAppendingPathComponent(to), error: &err)
    return err
}

private var combine_memoizer = [String:UnicodeScalar?]()
private extension UnicodeScalar {
    func combine(combiner: UnicodeScalar) -> UnicodeScalar?
    {
        // This is a hack, but it's good enough for this program. This hunts for
        // an 8-bit character that Swift considers to be the same grapheme as
        // the combined character.
        let combined = "\(self)\(combiner)"
        if let y = combine_memoizer[combined] { return y }

        let ch = (0x80...0xFF).map({ UnicodeScalar($0) }).filter({ String($0) == combined }).first
        combine_memoizer[combined] = ch
        return ch
    }
}

private func FixDoubleUTF8(name: String) -> String?
{
    // The string is processed one Unicode character at a time
    // any 8-bit values are appended to the array as is
    // the array is then converted UTF8 -> Unicode
    // the additional wrinkle is having to deal with combining characters
    // any values > 0xFF, except combining characters, mean that it was'nt doubly encoded
    var x = [UInt8]()
    var prv: UnicodeScalar?

    for ch in name.unicodeScalars {
        if ch.value < 0x100 {
            x.append(UInt8(ch.value))
            prv = ch
            continue
        }
        if let repl = prv?.combine(ch) {
            x[x.endIndex - 1] = UInt8(repl.value)
        }
        else {
            return name // not a combining character
        }
        prv = nil
    }
    x.append(0)

    // conversion from UTF8 to Unicode happens here
    return x.withUnsafeBufferPointer {
        String.fromCString(UnsafePointer<CChar>($0.baseAddress))
    }
}

private func ProcessName(dir: String, name: String) -> String
{
    if verbose > 3 { println("considering '\(name)'") }

    if let fixed = FixDoubleUTF8(name) {
        if fixed != name {
            if verbose > 0 { println("renaming '\(name) to '\(fixed)' in '\(dir)'") }
            if let err = rename(dir, name, fixed) {
                println("Failed to rename '\(name) to '\(fixed)' in '\(dir)': \(err)")
            }
            else {
                return fixed
            }
        }
        else {
            if verbose > 2 { println("'\(name)' doesn't need to be fixed") }
        }
    }
    else {
        if verbose > 0 { println("'\(name)' caused an error") }
    }
    return name
}

func isDirectory(atPath: String) -> Bool
{
    var isDir: ObjCBool = false;
    return fmgr.fileExistsAtPath(atPath, isDirectory: &isDir) ? isDir ? true : false : false
}

private func ProcessDirectory(dir: String)
{
    if verbose > 1 { println("examining directory '\(dir)'") }

    if let cntnt = fmgr.contentsOfDirectoryAtPath(dir, error: nil) {
        for i in cntnt {
            let name = i as! String
            if name.hasPrefix(".") { continue }

            let newname = ProcessName(dir, name)
            if recurse && isDirectory(dir.stringByAppendingPathComponent(newname)) {
                ProcessDirectory(dir.stringByAppendingPathComponent(newname))
            }
        }
    }
}

private func SplitPath(path: String) -> (String, String)
{
    let dirname = path.stringByDeletingLastPathComponent
    let basename = path.lastPathComponent

    return (dirname == "" ? fmgr.currentDirectoryPath : dirname, basename)
}

private func Main()
{
    let progname = Process.arguments[0]
    var moreSwitches = true
    var processCurrent = true

    for arg in Process.arguments[1..<Process.arguments.endIndex] {
        if moreSwitches {
            switch (arg) {
            case "-n", "--dry-run":
                dryrun = true
                continue
            case "-r", "--recurse":
                recurse = true
                continue
            case "-v", "--verbose":
                ++verbose
                continue
            case "-h", "-?", "--help":
                println("\(progname) [-h|-?|--help]|([-n|--dry-run] [-v|--verbose] [-r|--recurse] [input-file-or-directory] ...")
                processCurrent = false
                continue
            case "--":
                moreSwitches = false
                continue
            default:
                break
            }
        }
        if isDirectory(arg) {
            ProcessDirectory(arg)
        }
        else {
            let (dir, name) = SplitPath(arg)
            ProcessName(dir, name)
        }
        processCurrent = false
    }
    if processCurrent {
        ProcessDirectory(fmgr.currentDirectoryPath)
    }
}

#if !TESTING

// MARK: Main is called here
Main()

#else

let test = [
    "【PDA FT】ネトゲ廃人シュプレヒコール【巡音ルカ：スイムウェア／スイムウェアP】PV [720p].mp4",
    "ãPDA FTãããã²å»äººã·ã¥ãã¬ãã³ã¼ã«ãå·¡é³ã«ã«ï¼ã¹ã¤ã ã¦ã§ã¢ï¼ã¹ã¤ã ã¦ã§ã¢PãPV [720p].mp4",
    "\u{61}\u{303}\u{80}\u{90}\u{50}\u{44}\u{41}\u{20}\u{46}\u{54}\u{61}\u{303}\u{80}\u{91}\u{61}\u{303}\u{83}\u{8D}\u{61}\u{303}\u{83}\u{88}\u{61}\u{303}\u{82}\u{B2}\u{61}\u{30A}\u{BB}\u{83}\u{61}\u{308}\u{BA}\u{BA}\u{61}\u{303}\u{82}\u{B7}\u{61}\u{303}\u{83}\u{A5}\u{61}\u{303}\u{83}\u{97}\u{61}\u{303}\u{83}\u{AC}\u{61}\u{303}\u{83}\u{92}\u{61}\u{303}\u{82}\u{B3}\u{61}\u{303}\u{83}\u{BC}\u{61}\u{303}\u{83}\u{AB}\u{61}\u{303}\u{80}\u{90}\u{61}\u{30A}\u{B7}\u{A1}\u{65}\u{301}\u{9F}\u{B3}\u{61}\u{303}\u{83}\u{AB}\u{61}\u{303}\u{82}\u{AB}\u{69}\u{308}\u{BC}\u{9A}\u{61}\u{303}\u{82}\u{B9}\u{61}\u{303}\u{82}\u{A4}\u{61}\u{303}\u{83}\u{A0}\u{61}\u{303}\u{82}\u{A6}\u{61}\u{303}\u{82}\u{A7}\u{61}\u{303}\u{82}\u{A2}\u{69}\u{308}\u{BC}\u{8F}\u{61}\u{303}\u{82}\u{B9}\u{61}\u{303}\u{82}\u{A4}\u{61}\u{303}\u{83}\u{A0}\u{61}\u{303}\u{82}\u{A6}\u{61}\u{303}\u{82}\u{A7}\u{61}\u{303}\u{82}\u{A2}\u{50}\u{61}\u{303}\u{80}\u{91}\u{50}\u{56}\u{20}\u{5B}\u{37}\u{32}\u{30}\u{70}\u{5D}\u{2E}\u{6D}\u{70}\u{34}",
    "\u{E3}\u{80}\u{90}PDA FT\u{E3}\u{80}\u{91}\u{E3}\u{83}\u{8D}\u{E3}\u{83}\u{88}\u{E3}\u{82}\u{B2}\u{61}\u{30A}\u{BB}\u{83}\u{61}\u{308}\u{BA}\u{BA}\u{E3}\u{82}\u{B7}\u{E3}\u{83}\u{A5}\u{E3}\u{83}\u{97}\u{E3}\u{83}\u{AC}\u{E3}\u{83}\u{92}\u{E3}\u{82}\u{B3}\u{E3}\u{83}\u{BC}\u{E3}\u{83}\u{AB}\u{E3}\u{80}\u{90}\u{61}\u{30A}\u{B7}\u{A1}\u{65}\u{301}\u{9F}\u{B3}\u{E3}\u{83}\u{AB}\u{E3}\u{82}\u{AB}\u{69}\u{308}\u{BC}\u{9A}\u{E3}\u{82}\u{B9}\u{E3}\u{82}\u{A4}\u{E3}\u{83}\u{A0}\u{E3}\u{82}\u{A6}\u{E3}\u{82}\u{A7}\u{E3}\u{82}\u{A2}\u{69}\u{308}\u{BC}\u{8F}\u{E3}\u{82}\u{B9}\u{E3}\u{82}\u{A4}\u{E3}\u{83}\u{A0}\u{E3}\u{82}\u{A6}\u{E3}\u{82}\u{A7}\u{E3}\u{82}\u{A2}\u{50}\u{E3}\u{80}\u{91}PV [720p].mp4"
];
let gold = "【PDA FT】ネトゲ廃人シュプレヒコール【巡音ルカ：スイムウェア／スイムウェアP】PV [720p].mp4";

for tv in test {
    if let fixed = FixDoubleUTF8(tv) {
        if fixed == gold {
            println("test passed")
        }
        else {
            println(fixed)
            println("test failed; doesn't match")
        }
    }
    else {
        println("test failed; conversion error");
    }
}

for (k, v) in combine_memoizer {
    let kk = Array<UnicodeScalar>(k.unicodeScalars)
    println("'\(kk.map { String(UInt32($0), radix: 16, uppercase: true)})' -> '\(String(UInt32(v!), radix: 16, uppercase: true))'")
}
#endif
