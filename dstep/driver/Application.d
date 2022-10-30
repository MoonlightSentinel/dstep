/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.driver.Application;

import std.getopt;
import std.stdio : writeln, stderr;
import Path = std.path;
import std.file;

import clang.c.Index;

import clang.Compiler;
import clang.Index;
import clang.TranslationUnit;
import clang.Util;

import dstep.Configuration;
import dstep.core.Exceptions;
import dstep.translator.Options;
import dstep.translator.Translator;

version (D_Optimized)
    version = ENABLE_PARALLELISM;

version (ENABLE_PARALLELISM)
{
    import std.parallelism;
}
else
{
    alias parallel = (a, _) => a;
}

class Application
{
    private
    {
        Configuration config;
    }

    public this (Configuration config)
    {
        this.config = config;
    }

    public void run ()
    {
        import std.exception : enforce;
        import std.range;

        enforce!DStepException(config.inputFiles.length > 0,
            "dstep: error: must supply at least one input file\n");

        enforceInputFilesExist(config);

        auto translationUnits = makeTranslationUnits(config);

        enforceTranslationUnitsCompiled(translationUnits);

        auto inputFiles = config.inputFiles;
        auto outputFiles = makeOutputFiles(config);

        foreach (tuple; zip(inputFiles, outputFiles, translationUnits).parallel(1))
        {
            string outputDirectory = Path.dirName(tuple[1]);

            if (!exists(outputDirectory))
                mkdirRecurse(outputDirectory);

            Options options = this.config.toOptions(tuple[0], tuple[1]);

            auto translator = new Translator(tuple[2], options);
            translator.translate;
        }

        version (ENABLE_PARALLELISM)
            taskPool.finish(true);
    }

    static void enforceInputFilesExist(const Configuration config)
    {
        import std.exception : enforce;
        import std.format : format;

        foreach (inputFile; config.inputFiles)
        {
            enforce!DStepException(
                exists(inputFile),
                format("dstep: error: file '%s' doesn't exist\n", inputFile));

            enforce!DStepException(
                isFile(inputFile),
                format("dstep: error: '%s' is not a file\n", inputFile));
        }
    }

    void enforceTranslationUnitsCompiled(TranslationUnit[] translationUnits)
    {
        import std.array : Appender;
        import std.exception : enforce;

        bool translate = true;
        auto message = Appender!string();

        foreach (translationUnit; translationUnits)
        {
            foreach (diagnostics ; translationUnit.diagnostics)
            {
                auto severity = diagnostics.severity;

                with (CXDiagnosticSeverity)
                    if (translate)
                        translate = !(severity == fatal);

                message.put(diagnostics.format);
                message.put("\n");
            }
        }

        enforce!DStepException(translate, message.data);
    }

    static string[] makeOutputFiles(Configuration config)
    {
        import std.algorithm;
        import std.array;
        import std.range;

        import dstep.driver.Util : makeDefaultOutputFile;

        auto inputFiles = config.inputFiles;

        // when only one input file is supplied, -o argument is
        // interpreted as file path, otherwise as base directory path
        if (inputFiles.length == 1 && (!exists(config.output) && isDir(config.output)))
        {
            return [config.output.empty
                ? makeDefaultOutputFile(inputFiles.front, false)
                : config.output];
        }
        else
        {
            alias fmap = file => Path.buildPath(
                config.output,
                makeDefaultOutputFile(file, false));

            return inputFiles.map!fmap.array;
        }
    }

    static TranslationUnit[] makeTranslationUnits(Configuration config)
    {

        Index translationIndex = Index(false, false);
        Compiler compiler;

        auto translationUnits = new TranslationUnit[config.inputFiles.length];

        foreach (index, ref unit; translationUnits.parallel(1))
        {
            unit = TranslationUnit.parse(
                translationIndex,
                config.inputFiles[index],
                config.clangParams ~ compiler.internalFlags,
                compiler.internalHeaders);
        }

        return translationUnits;
    }
}
