/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: May 21, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Options;

import clang.Util;

import dstep.translator.ConvertCase;

enum Language
{
    c,
    objC
}

enum CollisionAction
{
    ignore,
    rename,
    abort
}

struct Options
{
    import clang.Cursor: Cursor;

    string[] inputFiles;
    string inputFile;
    string outputFile;
    Language language = Language.c;
    /// array of project root directories that should be used for module association
    string[string] packageByRootDirectory;
    string packageName;
    bool enableComments = true;
    bool publicSubmodules = false;
    bool normalizeModules = false;
    bool keepUntranslatable = false;
    bool reduceAliases = true;
    bool translateMacros = true;
    bool portableWCharT = true;
    bool zeroParamIsVararg = false;
    bool singleLineFunctionSignatures = false;
    bool spaceAfterFunctionName = true;
    bool aliasEnumMembers = false;
    bool renameEnumMembers = false;
    Set!string skipDefinitions;
    Set!string skipSymbols;
    bool printDiagnostics = true;
    CollisionAction collisionAction = CollisionAction.rename;
    const(string)[] globalAttributes;
    const(string)[] globalImports;
    bool delegate(ref const(Cursor)) isWantedCursorForTypedefs;

    string toString() const
    {
        import std.format : format;

        return format(
            "Options(outputFile = %s, language = %s, enableComments = %s, " ~
            "reduceAliases = %s, portableWCharT = %s)",
            outputFile,
            language,
            enableComments,
            reduceAliases,
            portableWCharT);
    }
}

string fullModuleName(
    const string packageName,
    const string[string] packageByRootDirectory,
    const string path,
    const bool normalize = true
)
{
    import std.algorithm;
    import std.path : baseName, stripExtension;
    import std.range;
    import std.uni;
    import std.utf;

    dchar replace(dchar c)
    {
        if (c == '_' || c.isWhite)
            return '_';
        else if (c.isPunctuation)
            return '.';
        else
            return c;
    }

    bool discard(dchar c)
    {
        return c.isAlphaNum || c == '_' || c == '.';
    }

    bool equivalent(dchar a, dchar b)
    {
        return (a == '.' || a == '_') && (b == '.' || b == '_');
    }

    const rp = resolvePackageRootPath(path, packageByRootDirectory);
    auto relPath = rp.found
                ? rp.relativePath
                : baseName(path);

    auto moduleBaseName = stripExtension(relPath);
    auto moduleName = moduleBaseName.map!replace.filter!discard.uniq!equivalent;

    if (normalize)
    {
        auto segments = moduleName.split!(x => x == '.');
        auto normalized = segments.map!(x => x.toUTF8.toSnakeCase).join('.');

        return packageName.length == 0
            ? normalized
            : only(packageName, normalized).join('.');
    }
    else
    {
        return packageName.length == 0
            ? moduleName.toUTF8
            : only(packageName, moduleName.toUTF8).join('.');
    }
}

unittest
{
    assert(fullModuleName("pkg", "foo") == "pkg.foo");
    assert(fullModuleName("pkg", "Foo") == "pkg.foo");
    assert(fullModuleName("pkg", "Foo.ext") == "pkg.foo");

    assert(fullModuleName("pkg", "Foo-bar.ext") == "pkg.foo.bar");
    assert(fullModuleName("pkg", "Foo_bar.ext") == "pkg.foo_bar");
    assert(fullModuleName("pkg", "Foo@bar.ext") == "pkg.foo.bar");
    assert(fullModuleName("pkg", "Foo~bar.ext") == "pkg.foo.bar");
    assert(fullModuleName("pkg", "Foo bar.ext") == "pkg.foo_bar");

    assert(fullModuleName("pkg", "Foo__bar.ext") == "pkg.foo_bar");
    assert(fullModuleName("pkg", "Foo..bar.ext") == "pkg.foo.bar");
    assert(fullModuleName("pkg", "Foo#$%#$%#bar.ext") == "pkg.foo.bar");
    assert(fullModuleName("pkg", "Foo_#$%#$%#bar.ext") == "pkg.foo_bar");

    assert(fullModuleName("pkg", "FooBarBaz.ext") == "pkg.foo_bar_baz");
    assert(fullModuleName("pkg", "FooBar.BazQux.ext") == "pkg.foo_bar.baz_qux");

    assert(fullModuleName("pkg", "FooBarBaz.ext", false) == "pkg.FooBarBaz");
    assert(fullModuleName("pkg", "FooBar.BazQux.ext", false) == "pkg.FooBar.BazQux");
}

/// Informations about a file in a package root
struct ResolvedPath
{
    bool found;             /// true when the package was resolved
    string relativePath;    /// file path relative to the package root
    string packageName;     /// name of the package
}

/++
 + Checks whether `path` denotes a file inside of the known packages
 + (specified via `--subpackage` on the command line, stored in `packageByRootDirectory`)
 +/
ResolvedPath resolvePackageRootPath(string path, const string[string] packageByRootDirectory)
{
    import std.path : buildPath, dirName, relativePath;
    import clang.Util : asAbsNormPath;

    // Shortcut if the user didn't specify any package
    if (!packageByRootDirectory.length)
        return ResolvedPath.init;

    // Ensure absolute paths
    path = asAbsNormPath(path);

    // Iterate all parent directories until there's a match in
    // packageByRootDirectory or it reached the file system root
    string root = path;
    string next;

    while ((next = dirName(root)) != root)
    {
        root = next;

        if (auto ptr = root in packageByRootDirectory)
        {
            const pac = *ptr;
            const rel = relativePath(path, root);
            const subRel = buildPath(pac, rel);   // Prepend custom package name
            return ResolvedPath(true, subRel, pac);
        }
    }

    return ResolvedPath.init;
}
