#!/usr/bin/env xcrun swift -O
//
//  main.swift
//  fix-double-UTF8
//
//  Created by Kenneth Durbrow on 11/20/17.
//  Copyright © 2017 Kenneth Durbrow. All rights reserved.
//

import Foundation

var dryrun = false;
var recurse = false;
var verbose = 0;
var isRepairing = false;

private var memo = [String:UnicodeScalar?]()
private func combine(unicodeScalar: UnicodeScalar?, combiner: UnicodeScalar) -> UnicodeScalar?
{
    guard let ch = unicodeScalar else { return nil }
    let together = "\(ch)\(combiner)"
    if let y = memo[together] { return y }
    
    let y = (0x80...0xFF).map({UnicodeScalar($0)}).filter({ String($0) == together }).first
    memo[together] = y
    return y
}

private func fixDoubleEncoding(_ name: String) -> String?
{
    var x = [UInt8]()
    var prv : UnicodeScalar?
    
    for ch in name.unicodeScalars {
        if ch.value < 0x100 {
            x.append(UInt8(ch.value))
            prv = ch
            continue
        }
        if let replace = combine(unicodeScalar: prv, combiner: ch) {
            x[x.endIndex - 1] = UInt8(replace.value)
        }
        else {
            return name
        }
    }
    x.append(0)
    
    return x.withUnsafeBufferPointer {
        guard let r = String.decodeCString($0.baseAddress, as: UTF8.self, repairingInvalidCodeUnits: isRepairing) else { return nil }
        return r.result
    }
}

private func process(name: String, `in` dir: URL) -> String
{
    if verbose > 3 { print("considering '\(name)'") }

    if let fixed = fixDoubleEncoding(name) {
        if fixed != name {
            if verbose > 0 { print("renaming '\(name) to '\(fixed)' in '\(dir)'") }
            if !dryrun {
                do {
                    try FileManager.default.moveItem(at: dir.appendingPathComponent(name), to: dir.appendingPathComponent(fixed))
                }
                catch {
                    print("Failed to rename '\(name) to '\(fixed)' in '\(dir)': \(error)")
                }
            }
            return fixed
        }
        else if verbose > 2 {
            print("'\(name)' doesn't need to be fixed")
        }
    }
    else {
        if verbose > 0 { print("'\(name)' caused an error") }
    }
    return name
}

private func process(directory item: URL)
{
    if verbose > 1 { print("examining '\(item)'") }

    if let e = FileManager.default.enumerator(at: item, includingPropertiesForKeys: [.isDirectoryKey, .parentDirectoryURLKey, .nameKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
    {
        for ii in e {
            if let i = ii as? URL
             , let v = try? i.resourceValues(forKeys: [.isDirectoryKey, .parentDirectoryURLKey, .nameKey])
             , let isdir = v.isDirectory
             , let p = v.parentDirectory
             , let n = v.name
            {
                let newName = process(name: n, in: p)
                
                if recurse && isdir {
                    process(directory: p.appendingPathComponent(newName, isDirectory: true))
                }
            }
        }
    }
}

private func process(item: URL)
{
    if let v = try? item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .parentDirectoryURLKey, .nameKey])
    {
        if let isdir = v.isDirectory, isdir {
            process(directory: item)
        }
        else if let isfile = v.isRegularFile, isfile, let p = v.parentDirectory, let n = v.name {
            _ = process(name: n, in: p)
        }
    }
}

#if !TESTING
let progname = CommandLine.arguments[0]
var moreSwitches = true
var processCurrent : URL? = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

for arg in CommandLine.arguments[1...] {
    if moreSwitches {
        switch arg {
        case "-f", "-force":
            isRepairing = true
            continue
        case "-n", "-dry-run":
            dryrun = true
            continue
        case "-r", "-recurse":
            recurse = true
            continue
        case "-v", "-verbose":
            verbose += 1
            continue
        case "-h", "-?", "-help":
            print("\(progname) [-h|-?|-help] | ([-n|-dry-run] [-v|-verbose] [-r|-recurse] [-f|-force] [input-file-or-directory] ...")
            exit(0)
        case "--":
            moreSwitches = false
            continue
        default:
            break
        }
    }
    process(item: URL(fileURLWithPath: arg))
    processCurrent = nil
}
if let currentDirectory = processCurrent {
    process(item: currentDirectory)
}
#else

let test = [
    "【PDA FT】ネトゲ廃人シュプレヒコール【巡音ルカ：スイムウェア／スイムウェアP】PV [720p].mp4",
    "ãPDA FTãããã²å»äººã·ã¥ãã¬ãã³ã¼ã«ãå·¡é³ã«ã«ï¼ã¹ã¤ã ã¦ã§ã¢ï¼ã¹ã¤ã ã¦ã§ã¢PãPV [720p].mp4",
    "\u{61}\u{303}\u{80}\u{90}\u{50}\u{44}\u{41}\u{20}\u{46}\u{54}\u{61}\u{303}\u{80}\u{91}\u{61}\u{303}\u{83}\u{8D}\u{61}\u{303}\u{83}\u{88}\u{61}\u{303}\u{82}\u{B2}\u{61}\u{30A}\u{BB}\u{83}\u{61}\u{308}\u{BA}\u{BA}\u{61}\u{303}\u{82}\u{B7}\u{61}\u{303}\u{83}\u{A5}\u{61}\u{303}\u{83}\u{97}\u{61}\u{303}\u{83}\u{AC}\u{61}\u{303}\u{83}\u{92}\u{61}\u{303}\u{82}\u{B3}\u{61}\u{303}\u{83}\u{BC}\u{61}\u{303}\u{83}\u{AB}\u{61}\u{303}\u{80}\u{90}\u{61}\u{30A}\u{B7}\u{A1}\u{65}\u{301}\u{9F}\u{B3}\u{61}\u{303}\u{83}\u{AB}\u{61}\u{303}\u{82}\u{AB}\u{69}\u{308}\u{BC}\u{9A}\u{61}\u{303}\u{82}\u{B9}\u{61}\u{303}\u{82}\u{A4}\u{61}\u{303}\u{83}\u{A0}\u{61}\u{303}\u{82}\u{A6}\u{61}\u{303}\u{82}\u{A7}\u{61}\u{303}\u{82}\u{A2}\u{69}\u{308}\u{BC}\u{8F}\u{61}\u{303}\u{82}\u{B9}\u{61}\u{303}\u{82}\u{A4}\u{61}\u{303}\u{83}\u{A0}\u{61}\u{303}\u{82}\u{A6}\u{61}\u{303}\u{82}\u{A7}\u{61}\u{303}\u{82}\u{A2}\u{50}\u{61}\u{303}\u{80}\u{91}\u{50}\u{56}\u{20}\u{5B}\u{37}\u{32}\u{30}\u{70}\u{5D}\u{2E}\u{6D}\u{70}\u{34}",
    "\u{E3}\u{80}\u{90}PDA FT\u{E3}\u{80}\u{91}\u{E3}\u{83}\u{8D}\u{E3}\u{83}\u{88}\u{E3}\u{82}\u{B2}\u{61}\u{30A}\u{BB}\u{83}\u{61}\u{308}\u{BA}\u{BA}\u{E3}\u{82}\u{B7}\u{E3}\u{83}\u{A5}\u{E3}\u{83}\u{97}\u{E3}\u{83}\u{AC}\u{E3}\u{83}\u{92}\u{E3}\u{82}\u{B3}\u{E3}\u{83}\u{BC}\u{E3}\u{83}\u{AB}\u{E3}\u{80}\u{90}\u{61}\u{30A}\u{B7}\u{A1}\u{65}\u{301}\u{9F}\u{B3}\u{E3}\u{83}\u{AB}\u{E3}\u{82}\u{AB}\u{69}\u{308}\u{BC}\u{9A}\u{E3}\u{82}\u{B9}\u{E3}\u{82}\u{A4}\u{E3}\u{83}\u{A0}\u{E3}\u{82}\u{A6}\u{E3}\u{82}\u{A7}\u{E3}\u{82}\u{A2}\u{69}\u{308}\u{BC}\u{8F}\u{E3}\u{82}\u{B9}\u{E3}\u{82}\u{A4}\u{E3}\u{83}\u{A0}\u{E3}\u{82}\u{A6}\u{E3}\u{82}\u{A7}\u{E3}\u{82}\u{A2}\u{50}\u{E3}\u{80}\u{91}PV [720p].mp4"
];
let gold = "【PDA FT】ネトゲ廃人シュプレヒコール【巡音ルカ：スイムウェア／スイムウェアP】PV [720p].mp4";
    
for tv in test {
    if let fixed = fixDoubleEncoding(tv) {
        if fixed == gold {
            print("test passed")
        }
        else {
            print(fixed)
            print("test failed; doesn't match")
        }
    }
    else {
        print("test failed; conversion error");
    }
}
#endif
