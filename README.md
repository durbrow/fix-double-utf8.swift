fix-double-utf8.swift
=====================

A command line tool written in swift to fix doubly-encoded UTF8 file names

To run the tool; for example:
=============================
    fix-double-utf8.swift -n -v -v -r

Assuming that a swift capable xcrun is installed and in your PATH, this should print lots
of stuff about examining directories and renaming, but because of the -n, nothing will be
changed.

To run the test:
================
    xcrun swift -g -D TESTING fix-double-utf8.swift
