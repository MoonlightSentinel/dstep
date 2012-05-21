/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: may 1, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Struct;

import mambo.core._;

import clang.c.index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.translator.Translator;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Type;

class Struct : Declaration
{
	this (Cursor cursor, Cursor parent, Translator translator)
	{
		super(cursor, parent, translator);
	}
	
	string translate ()
	{
		return writeStruct(spelling, (context) {
			foreach (cursor, parent ; cursor.declarations)
			{
				with (CXCursorKind)
					switch (cursor.kind)
					{
						case CXCursor_FieldDecl:
							if (cursor.type.isUnexposed && cursor.type.declaration.isValid)
							{

								context.instanceVariables ~= translator.translate(cursor.type.declaration);
							}
							
							context.instanceVariables ~= translator.variable(cursor, new String);
						break;
						
						default: break;
					}
			}
		});
	}

private:

	string writeStruct (string name, void delegate (StructData context) dg)
	{
		auto context = new StructData;
		context.name = translateIdentifier(name);
		
		dg(context);
		
		return context.data;
	}
}