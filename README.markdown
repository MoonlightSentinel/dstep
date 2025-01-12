# DStep

DStep is a tool for automatically generating D bindings for C and Objective-C
libraries. This is implemented by processing C or Objective-C header files and
output D modules. DStep uses the Clang compiler as a library (libclang) to
process the header files.

## Fork-specific changes

The following changes are currently implemented in this fork an might be upstreamed
at some point in the future:

- implement the `--subpackage <directory=package>` switch to support
  headers with library dependencies. The flag registers the specified
  directory as a source path (similar to `-I` from clang) that contains
  source files belonging to the specified package.

  This flags enables DStep to handle complex libraries consisting of
  multiple subpackages by mirroring the directory structure in the
  `--output` directory and using appropriate module names / imports.

  Consider the following example:

```
├── app
│   └── source
│       └── root.h
├── lib
│   └── source
│       ├── common.h
│       └── nested
│           └── stuff.h
```

Example command that yields the following results:

```
dstep \
    -Iapp/source \
    -Ilib/source \
    --output=output \
    --subpackage app/source=app \
    --subpackage=lib/source=lib \
    app/source/root.h \
    lib/source/common.h \
	lib/source/nested/stuff.h
```

```
output
├── app
│   └── root.d
└── lib
    ├── common.d
    └── nested
        └── stuff.d
```

- support for incomplete compilations, e.g. due to missing headers
- expose the `keep-untranslatable` flag to the CLI

Bugfixes:
- `[U]LL` literals are translated as `[U]L`
- `--output=<directory>` works with single input files

Internal:
- disable parallelism by default for non-optimized builds. Compile with
  `-version=ENABLE_PARALLELISM` to revert to the old behaviour

## Download

For the latest release see: [releases/latest](https://github.com/jacob-carlborg/dstep/releases/latest).

Pre-compiled binaries are available for macOS and Linux as 64 bit binaries and
Windows as 32 and 64 bit binaries. The Linux binaries are completely statically
linked and should work on all distros. The macOS binaries are statically linked
against libclang requires no other dependencies than the system libraries. They
should work on macOS Mavericks (10.9) and later. The Windows binaries require
to install libclang. See the [releases](https://github.com/jacob-carlborg/dstep/releases) section.

Alternatively install via [Dub](http://code.dlang.org/download)

## License

The source code is available under the [Boost Software License 1.0](http://www.boost.org/LICENSE_1_0.txt)

## Building

### Posix

#### Requirements

* libclang - [http://clang.llvm.org](http://clang.llvm.org) - 10.0.0 or 9.0.0.
    The idea is that the two most recent versions of libclang are supported.
* A D compiler - The latest version of [DMD](http://dlang.org/download.html)
    or [LDC](https://github.com/ldc-developers/ldc/releases/latest)
* Dub [http://code.dlang.org/download](http://code.dlang.org/download)
    (also shipped with the compilers)

#### Building

1. Install all requirements, see [above](#requirements)
2. Clone the repository by running:

        $ git clone https://github.com/jacob-carlborg/dstep

3. Run `dub build`

A configuration script will try to automatically locate libclang by looking
through a couple of default search paths. If libclang is not found in any of the
default paths, please manually invoke the configuration script and specify the
path to where libclang is installed using the `--llvm-path` flag.

```
$ ./configure --llvm-path /usr/lib/llvm-4.0
```

### Windows

#### Requirements

* LLVM - [http://llvm.org/releases/download.html](http://llvm.org/releases/download.html) -
    pre-built binaries for Windows. Has to be installed at the default location
* DMD - [http://dlang.org/download.html](http://dlang.org/download.html) -
    2.071.0 or later
* Dub - [http://code.dlang.org/download](http://code.dlang.org/download)
* Visual Studio - for example Visual Studio Community

#### Building

1. Install all requirements, see [above](#requirements)
2. Clone the repository by running:

		$ git clone git://github.com/jacob-carlborg/dstep.git

3. Run `dub build --arch=x86_mscoff --build=release` to build 32-bit version
4. Run `dub build --arch=x86_64 --build=release` to build 64-bit version

#### Remarks

Building 32-bit version requires a 32-bit variant of the Visual Studio toolchain
to be present in `PATH`. The same for 64-bit. Remember to specify
`--arch=x86_mscoff` when building 32-bit version. The architecture specification
is mandatory as with the default architecture or `--arch=x86` dub will try to
use unsupported `OPTLINK` linker. `OPTLINK` linker requires unsupported version
of libclang binaries. Remember to install LLVM to its default installation path
and to add its binaries to the `PATH` environmental variable (otherwise you may
need to change `dub.json`). When the program compiles under Windows but crashes
at start, make sure an appropriate version of `libclang.dll` is available for
DStep (you can validate it easily by copying dll to the directory with DStep).
[Here](https://docs.microsoft.com/en-us/windows/desktop/Dlls/dynamic-link-library-search-order#search-order-for-desktop-applications)
you can find more information on the topic.

## Usage

    $ dstep Foo.h -o Foo.d

For translating Objective-C headers add the `-ObjC` flag.

    $ dstep Foo.h -o Foo.d -ObjC

For translating multiple files at once, simply pass all the files to dstep.
In this case though, `-o` (if given) would point to output directory name.
The directory will be created if it doesn't exist.

    $ dstep Foo1.h Foo2.h Foo3.h .... FooN.h -o ./outputDirectory/

Use `-h` for usage information. Any flags recognized by Clang can be used.

## Limitations/Known issues

* Supports translating some of the preprocessor, like: `#define` for simple
    constants, function like macros and the token concatenation operator (`##`)
* Doesn't translate `#include` to `import`. Imports for a few standard C headers
    are added automatically
* Doesn't translate C++ at all
* Umbrella headers. Some headers just serve to include other headers. If these
    other headers contain some form of protection, like `#error`, to be included
    directly this can cause problems for DStep
* Some headers are designed to always be included together with other header
    files. These headers may very well use symbols from other header files
    without including them itself. Since DStep is designed to convert header
    files one-by-one this doesn't work. There are two workarounds for this:

    1. Add `#include`-directives for the header files the header file is
        actually using
    2. Use the `-include <file>` flag available in Clang to indicate the given
        `<file>` should be processed before the file that should be translated.
        DStep accepts all flags Clang accepts
