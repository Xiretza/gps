-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                        Copyright (C) 2002                         --
--                            ACT-Europe                             --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

--  with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Exceptions;          use Ada.Exceptions;
--  with String_Utils;            use String_Utils;

with GNAT.Regpat;             use GNAT.Regpat;

with Language;                use Language;

with Codefix.Text_Manager.Ada_Commands; use Codefix.Text_Manager.Ada_Commands;

package body Codefix.Formal_Errors is

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (This : in out Error_Message; Message : String) is
   begin
      Assign (This.Message, Message);
      Parse_Head (Message, This);
   end Initialize;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (This : in out Error_Message; Line, Col : Positive) is
   begin
      Assign (This.Message, "");
      This.Line := Line;
      This.Col := Col;
   end Initialize;

   -----------------
   -- Get_Message --
   -----------------

   function Get_Message (This : Error_Message) return String is
   begin
      return This.Message.all;
   end Get_Message;

   ----------
   -- Free --
   ----------

   procedure Free (This : in out Error_Message) is
   begin
      Free (File_Cursor (This));
      Free (This.Message);
   end Free;

   ----------------
   -- Parse_Head --
   ----------------

   procedure Parse_Head (Message : String; This : out Error_Message) is
      Matches : Match_Array (0 .. 3);
      Matcher : constant Pattern_Matcher :=
         Compile ("([^:]*):([0-9]*):([0-9]*)");

   begin
      Match (Matcher, Message, Matches);

      begin
         Assign (This.File_Name,
                 Message (Matches (1).First .. Matches (1).Last));
         This.Line := Positive'Value
            (Message (Matches (2).First .. Matches (2).Last));
         This.Col := Positive'Value
            (Message (Matches (3).First .. Matches (3).Last));

      exception
         when Constraint_Error => -- et tester No_Match
            null; -- Lever une exception due au 'Value
      end;
   end Parse_Head;

   -----------
   -- Clone --
   -----------

   function Clone (This : Error_Message) return Error_Message is
      New_Message : Error_Message;
   begin
      New_Message := (Clone (File_Cursor (This)) with
                        new String'(This.Message.all));
      return New_Message;
   end Clone;

   -----------------
   -- Get_Command --
   -----------------

   function Get_Command
     (This     : Solution_List;
      Position : Positive) return Text_Command'Class
   is
      Current_Node : Command_List.List_Node;
   begin
      Current_Node := First (This);

      for J in 1 .. Position - 1 loop
         Current_Node := Next (Current_Node);
      end loop;

      return Data (Current_Node);
   end Get_Command;

   ----------
   -- Free --
   ----------

   procedure Free (This : in out Solution_List) is
   begin
      Free (This, True);
   end Free;

   -----------------
   -- Delete_With --
   -----------------

   function Delete_With
     (Current_Text : Text_Navigator_Abstr'Class;
      Cursor       : File_Cursor'Class;
      Name         : String;
      Move_To      : File_Cursor := Null_File_Cursor) return Text_Command'Class
   is
      pragma Unreferenced (Current_Text, Cursor, Name, Move_To);
      Command : Insert_Word_Cmd;
   begin
      return Command;
--      Extract_Use, New_Extract  : Ada_List;
--      Temp_Extract              : Extract;
--      Use_Info, Pkg_Info        : Construct_Information;
--      Cursor_Use                : File_Cursor := File_Cursor (Cursor);
--      Success                   : Boolean := True;
--      Index_Name, Prev_Index    : Natural := 0;
--   begin
--      Pkg_Info := Search_Unit
--        (Current_Text, Cursor.File_Name.all, Cat_With, Name);

--      if Pkg_Info.Category = Cat_Unknown then
--         Pkg_Info := Search_Unit
--           (Current_Text, Cursor.File_Name.all, Cat_Package, Name);
--         Get_Unit (Current_Text, Cursor, Ada_Instruction (New_Extract));
--         Remove_Instruction (New_Extract);
--         Set_Caption
--           (New_Extract,
--            "Delete instantiation and use clauses of unit """ & Name & """");
--      else
--         Get_Unit (Current_Text, Cursor, New_Extract);
--         Remove_Elements (New_Extract, Name);
--         Set_Caption
--           (New_Extract,
--            "Delete with and use clauses for unit """ & Name & """");

--         if Move_To /= Null_File_Cursor then
--          Add_Line (New_Extract, Move_To, "with " & Pkg_Info.Name.all & ";");
--         end if;
--      end if;

--      loop
--         Index_Name := Index_Name + 1;
--         Skip_To_Char (Pkg_Info.Name.all, Index_Name, '.');
--         exit when Index_Name > Pkg_Info.Name'Last + 1;

--         Use_Info := Search_Unit
--           (Current_Text,
--            Cursor.File_Name.all,
--            Cat_Use,
--            Pkg_Info.Name.all (Prev_Index + 1 .. Index_Name - 1));

--         if Use_Info.Category /= Cat_Unknown then
--            Cursor_Use.Col := Use_Info.Sloc_Start.Column;
--            Cursor_Use.Line := Use_Info.Sloc_Start.Line;
--            Get_Unit (Current_Text, Cursor_Use, Extract_Use);

--            if Move_To /= Null_File_Cursor then
--               Add_Line
--                 (New_Extract, Move_To, "use " & Use_Info.Name.all & ";");
--            end if;

--            Remove_Elements (Extract_Use, Name);
--            Unchecked_Assign (Temp_Extract, New_Extract);
--            Unchecked_Free (New_Extract);
--            Merge
--              (New_Extract,
--               Temp_Extract,
--               Extract_Use,
--               Current_Text,
--               Success);

--            Set_Caption (New_Extract, Get_Caption (Temp_Extract));

--            Free (Temp_Extract);
--            Free (Extract_Use);
--            exit when not Success;
--         end if;

--         Prev_Index := Index_Name;
--      end loop;

--      if not Success then
--         null; --  ???
--      end if;

--      return New_Extract;

   end Delete_With;

   ---------------
   -- Should_Be --
   ---------------

   function Should_Be
     (Current_Text : Text_Navigator_Abstr'Class;
      Message      : File_Cursor'Class;
      Str_Expected : String;
      Str_Red      : String := "";
      Format_Red   : String_Mode := Text_Ascii;
      Caption      : String := "") return Solution_List
   is
      Result      : Solution_List;
      New_Command : Replace_Word_Cmd;
      Old_Word    : Word_Cursor;
   begin
      if Str_Red /= "" then
         Old_Word := (File_Cursor (Message)
                      with new String'(Str_Red), Format_Red);

         if Caption = "" then
            if Format_Red = Text_Ascii then
               Set_Caption
                 (New_Command,
                  "Replace """ & Str_Red & """ by """ & Str_Expected & """");
            else
               Set_Caption
                 (New_Command,
                  "Replace misspelled word by """ & Str_Expected & """");
            end if;
         else
            Set_Caption (New_Command, Caption);
         end if;
      else
         Old_Word := (File_Cursor (Message)
                      with new String'("(^[\w]+)"), Regular_Expression);

         if Caption = "" then
            Set_Caption
              (New_Command,
               "Replace misspelled word by """ & Str_Expected & """");
         else
            Set_Caption (New_Command, Caption);
         end if;
      end if;

      Initialize (New_Command, Current_Text, Old_Word, Str_Expected);

      Append (Result, New_Command);

      return Result;
   end Should_Be;

   -----------------
   -- Wrong_Order --
   -----------------

   function Wrong_Order
     (Current_Text  : Text_Navigator_Abstr'Class;
      Message       : Error_Message;
      First_String  : String;
      Second_String : String) return Solution_List
   is
      pragma Unreferenced (Current_Text, Message, First_String, Second_String);
--      New_Command   : Invert_Words_Cmd;
--      Word1, Word2  : Word_Cursor;
--      Matches       : Match_Array (1 .. 1);
--      Matcher       : constant Pattern_Matcher :=
--        Compile ("(" & Second_String & ") ", Case_Insensitive);
--      Second_Cursor : File_Cursor := File_Cursor (Message);
--      Line_Cursor   : File_Cursor := File_Cursor (Message);
--      Result        : Solution_List;

   begin
      return Command_List.Null_List;
--      Second_Cursor.Col := 1;

--      loop
--         Match (Matcher, Get_Line (Current_Text, Second_Cursor), Matches);
--         exit when Matches (1) /= No_Match;
--         Second_Cursor.Line := Second_Cursor.Line - 1;
--      end loop;

--      Line_Cursor.Col := 1;
--      Get_Line (Current_Text, Line_Cursor, New_Extract);

--      if Message.Line /= Second_Cursor.Line then
--         Get_Line (Current_Text, Second_Cursor, New_Extract);
--      end if;

--      Second_Cursor.Col := Matches (1).First;

--      Word1 := (File_Cursor (Message)
--               with new String'(First_String), Text_Ascii);


--      Word2 := (File_Cursor (Second_Cursor)
--               with new String'(Second_String), Text_Ascii);

--      Inititialize (New_Command, Current_Text, Word1, Word2);

--      Set_Caption
--        (New_Command,
--         "Invert """ & First_String & """ and """ & Second_String & """");

--      Append (Result, New_Command);

--      return Result;
   end Wrong_Order;

   --------------
   -- Expected --
   --------------

   function Expected
     (Current_Text    : Text_Navigator_Abstr'Class;
      Message         : File_Cursor'Class;
      String_Expected : String;
      Add_Spaces      : Boolean := True;
      Position        : Relative_Position := Specified) return Solution_List
   is
      New_Command  : Insert_Word_Cmd;
      Word         : Word_Cursor;
      Result       : Solution_List;
   begin

      Word := (File_Cursor (Message)
               with new String'(String_Expected), Text_Ascii);

      Initialize (New_Command, Current_Text, Word, Add_Spaces, Position);

      Set_Caption
        (New_Command,
         "Add expected word """ & String_Expected & """");

      Append (Result, New_Command);

      return Result;
   end Expected;

   ----------------
   -- Unexpected --
   ----------------

   function Unexpected
     (Current_Text      : Text_Navigator_Abstr'Class;
      Message           : File_Cursor'Class;
      String_Unexpected : String;
      Mode              : String_Mode := Text_Ascii) return Solution_List
   is
      New_Command  : Insert_Word_Cmd;
      Word         : Word_Cursor;
      Result       : Solution_List;
   begin

      Word := (File_Cursor (Message)
               with new String'(String_Unexpected), Mode);

      Initialize (New_Command, Current_Text, Word);

      Set_Caption
        (New_Command,
         "Remove unexpected word """ & String_Unexpected & """");

      Append (Result, New_Command);

      return Result;
   end Unexpected;

   ------------------
   -- Wrong_Column --
   ------------------

   function Wrong_Column
     (Current_Text    : Text_Navigator_Abstr'Class;
      Message         : File_Cursor'Class;
      Column_Expected : Natural := 0) return Solution_List
   is
      pragma Unreferenced (Current_Text, Message, Column_Expected);
--      function Closest (Size_Red : Positive) return Positive;
      --  Return the closest indentation modulo Indentation_Width.

--      function Closest (Size_Red : Positive) return Positive is
--      begin
--         case (Size_Red - 1) mod Indentation_Width is
--            when 0 =>
--               return Size_Red + Indentation_Width;
               --  not - Identation_Width because of the case where
               --  Size_Red = 1
--            when 1 =>
--               return Size_Red - 1;
--            when 2 =>
--               return Size_Red + 1;
--            when others =>
--               Raise_Exception
--                 (Codefix_Panic'Identity,
--                  "Indentation_With changed, please update Wrong_Column.");
--         end case;
--      end Closest;

--      New_Extract   : Extract;
--      Str_Red       : Dynamic_String;
--      White_String  : constant String (1 .. 256) := (others => ' ');
--      Line_Cursor   : File_Cursor := File_Cursor (Message);
--      Column_Chosen : Natural;


   begin
      return Command_List.Null_List;
--      Line_Cursor.Col := 1;
--      Get_Line (Current_Text, Line_Cursor, New_Extract);
--      Str_Red := new String'(Get_String (New_Extract));

--      if Column_Expected = 0 then
--         Column_Chosen := Closest (Message.Col);
--      else
--         Column_Chosen := Column_Expected;
--      end if;

--      Set_String
--        (New_Extract,
--         White_String (1 .. Column_Chosen - 1) &
--           Str_Red (Message.Col .. Str_Red'Length));

--      Set_Caption
--        (New_Extract,
--         "Move begin of instruction to column " &
--           Integer'Image (Column_Chosen));

--      Free (Str_Red);
--      return New_Extract;
   end Wrong_Column;

   -------------------------
   -- With_Clause_Missing --
   -------------------------

   function With_Clause_Missing
     (Current_Text   : Text_Navigator_Abstr'Class;
      Cursor         : File_Cursor'Class;
      Missing_Clause : String) return Solution_List
   is
      Word_With   : Word_Cursor;
      New_Command : Insert_Word_Cmd;
      Result      : Solution_List;
   begin
      Word_With := (Line => 0,
                    Col => 1,
                    File_Name => Cursor.File_Name,
                    String_Match => new String'
                      ("with " & Missing_Clause
                       & "; use " & Missing_Clause & ";"),
                    Mode => Text_Ascii);

      Initialize (New_Command, Current_Text, Word_With);

      Set_Caption
        (New_Command,
         "Add with and use clause for package """ & Missing_Clause &
         """ at the begining of the file");

      Append (Result, New_Command);

      return Result;
   end With_Clause_Missing;

   ----------------
   -- Bad_Casing --
   ----------------

   function Bad_Casing
     (Current_Text : Text_Navigator_Abstr'Class;
      Cursor       : File_Cursor'Class;
      Correct_Word : String := "";
      Word_Case    : Case_Type := Mixed) return Solution_List
   is
      pragma Unreferenced (Current_Text, Cursor, Correct_Word, Word_Case);
--      function To_Correct_Case (Str : String) return String;
      --  Return the string after having re-cased it (with Word_Case).

      ---------------------
      -- To_Correct_Case --
      ---------------------

--      function To_Correct_Case (Str : String) return String is
--         New_String : String (Str'Range);
--      begin
--         case Word_Case is
--            when Mixed =>
--               New_String := Str;
--               Mixed_Case (New_String);

--            when Upper =>
--               for J in Str'Range loop
--                  New_String (J) := To_Upper (Str (J));
--               end loop;

--            when Lower =>
--               for J in Str'Range loop
--                  New_String (J) := To_Lower (Str (J));
--               end loop;
--         end case;

--         return New_String;
--      end To_Correct_Case;

--      New_Extract : Extract;
--      Cursor_Line : File_Cursor := File_Cursor (Cursor);
--      Word        : constant Pattern_Matcher := Compile ("([\w]+)");
--      Matches     : Match_Array (0 .. 1);
--      Size        : Integer;
--      Line        : Dynamic_String;
--      Word_Chosen : Dynamic_String;

   begin
      return Command_List.Null_List;
--      Cursor_Line.Col := 1;
--      Get_Line (Current_Text, Cursor_Line, New_Extract);
--      Assign (Line, Get_String (New_Extract));
--      Match (Word, Line (Cursor.Col .. Line'Length), Matches);

--      Size := Matches (1).Last - Matches (1).First + 1;

--      if Correct_Word /= "" then
--         Word_Chosen := new String'(Correct_Word);
--      else
--         Word_Chosen := new String'
--           (To_Correct_Case (Line (Matches (1).First .. Matches (1).Last)));
--      end if;

--      Replace_Word
--        (New_Extract,
--         Cursor,
--         Word_Chosen (Word_Chosen'Last - Size + 1 .. Word_Chosen'Last),
--         Size);

--      Set_Caption
--        (New_Extract,
--         "Replace bad-cased word by """ & Word_Chosen.all & """");

--      Free (Word_Chosen);
--
--      return New_Extract;
   end Bad_Casing;

   --------------------
   -- Not_Referenced --
   --------------------

   function Not_Referenced
     (Current_Text : Text_Navigator_Abstr'Class;
      Cursor       : File_Cursor'Class;
      Category     : Language_Category;
      Name         : String) return Solution_List
   is

--      function Delete_Entity return Extract;
      --  Delete the body, and if it exisits the declaration, of an unit
      --  (typically, a subprogram).

--      function Add_Pragma return Extract;
      --  Add a pragma after the declaration or, if there is no declaration,
      --  after the body.

--      function Add_Parameter_Pragma return Extract;

      -------------------
      -- Delete_Entity --
      -------------------

--      function Delete_Entity return Extract is
--         New_Extract : Extract;
--      begin
--         Get_Entity (New_Extract, Current_Text, Cursor);
--         Delete_All_Lines (New_Extract);
--         return New_Extract;
--      end Delete_Entity;

      ----------------
      -- Add_Pragma --
      ----------------

--      function Add_Pragma return Extract is
--         New_Extract  : Extract;
--         New_Position : File_Cursor;
--         Declaration  : Construct_Information;
--      begin
--         Declaration := Get_Unit (Current_Text, Cursor);
--         New_Position.Line := Declaration.Sloc_End.Line;
--         New_Position.Col  := Declaration.Sloc_End.Column;
--         Assign (New_Position.File_Name, Cursor.File_Name);
--         Add_Line (New_Extract, New_Position, "pragma Unreferenced (" &
--                     Name & ");");
--         Free (New_Position);
--         return New_Extract;
--      end Add_Pragma;

      --------------------------
      -- Add_Parameter_Pragma --
      --------------------------

--      function Add_Parameter_Pragma return Extract is
--         New_Extract           : Extract;
--         New_Position, Garbage : File_Cursor;
--         Declaration           : Construct_Information;

--      begin
--         Declaration := Get_Unit
--           (Current_Text, Cursor, Before, Cat_Procedure, Cat_Function);
--         New_Position.Line := Declaration.Sloc_Entity.Line;
--         New_Position.Col  := Declaration.Sloc_Entity.Column;
--         Assign (New_Position.File_Name, Cursor.File_Name);

--         Garbage := New_Position;
--         New_Position := File_Cursor
--           (Search_String (Current_Text, New_Position, ")"));
--         Free (Garbage);

--         Garbage := New_Position;
--         New_Position := File_Cursor
--           (Search_String (Current_Text, New_Position, "is"));
--         Free (Garbage);

--         Add_Line
--           (New_Extract,
--            New_Position, "pragma Unreferenced (" & Name & ");");

--         Free (New_Position);

--         return New_Extract;
--      end Add_Parameter_Pragma;

      --  begin of Not_Referenced

      Result : Solution_List;

   begin

      case Category is
         when Cat_Variable =>
            declare
               New_Command : Remove_Elements_Cmd;
               Var_Cursor  : Word_Cursor :=
                 (File_Cursor (Cursor) with new String'(Name), Text_Ascii);
            begin
               Add_To_Remove (New_Command, Current_Text, Var_Cursor);
               Set_Caption
                 (New_Command,
                  "Delete variable """ & Name & """");
               Append (Result, New_Command);
            end;

--         when Cat_Function | Cat_Procedure =>

--            New_Extract := Delete_Entity;
--            Set_Caption
--              (New_Extract,
--              "Delete subprogram """ & Name & """");
--            Append (New_Solutions, New_Extract);

--            New_Extract := Add_Pragma;
--            Set_Caption
--              (New_Extract,
--               "Add pragma Unreferenced to subprogram """ & Name & """");
--            Append (New_Solutions, New_Extract);

--         when Cat_Type =>

--            New_Extract := Delete_Entity;
--            Set_Caption
--              (New_Extract,
--               "Delete type """ & Name & """");
--            Append (New_Solutions, New_Extract);

--            New_Extract := Add_Pragma;
--            Set_Caption
--              (New_Extract,
--               "Add pragma Unreferenced to type """ & Name & """");
--            Append (New_Solutions, New_Extract);

--         when Cat_Local_Variable =>

--            New_Extract := Add_Parameter_Pragma;
--            Set_Caption
--              (New_Extract,
--             "Add pragma Unreferenced to formal parameter """ & Name & """");
--            Append (New_Solutions, New_Extract);

         when Cat_With =>
            declare
               New_Command : Remove_Pkg_Clauses_Cmd;
               With_Cursor : Word_Cursor :=
                 (File_Cursor (Cursor) with new String'(Name), Text_Ascii);
            begin
               Initialize (New_Command, Current_Text, With_Cursor);
               Set_Caption
                 (New_Command,
                  "Remove all clauses for package " & Name);
               Append (Result, New_Command);
            end;
         when others =>
            Raise_Exception
              (Codefix_Panic'Identity,
               "Wrong category given : " & Language_Category'Image (Category));
      end case;

      return Result;
   end Not_Referenced;

   ------------------------
   --  First_Line_Pragma --
   ------------------------

   function First_Line_Pragma
     (Current_Text : Text_Navigator_Abstr'Class;
      Cursor       : File_Cursor'Class) return Solution_List
   is
      Begin_Cursor : File_Cursor := File_Cursor (Cursor);
      New_Command   : Move_Word_Cmd;
      Result        : Solution_List;
      Pragma_Cursor : Word_Cursor;
   begin
      Pragma_Cursor := (File_Cursor (Cursor) with
                        String_Match => new String'
                          ("(pragma[\b]*\([^\)*]\)[\b]*;)"),
                        Mode => Regular_Expression);

      Begin_Cursor.Line := 0;
      Begin_Cursor.Col := 1;

      Initialize (New_Command, Current_Text, Pragma_Cursor, Begin_Cursor);

      Set_Caption
        (New_Command,
         "Move the pragma to the beginnig of the file");

      return Result;
   end First_Line_Pragma;

   ------------------
   -- Not_Modified --
   ------------------

   function Not_Modified
     (Current_Text : Text_Navigator_Abstr'Class;
      Cursor       : File_Cursor'Class;
      Name         : String) return Solution_List
   is
      pragma Unreferenced (Current_Text, Cursor, Name);

--      New_Extract : Ada_List;
--      New_Instr   : Dynamic_String;
--      Col_Decl    : Natural;

   begin
      return Command_List.Null_List;
--      Get_Unit (Current_Text, Cursor, New_Extract);

--      if Get_Number_Of_Elements (New_Extract) = 1 then
--         Replace_Word
--           (New_Extract,
--            Search_String (New_Extract, ":"),
--            ": constant",
--            ":");
--      else
--         Cut_Off_Elements (New_Extract, New_Instr, Name);

--         Col_Decl := New_Instr'First;
--         Skip_To_Char (New_Instr.all, Col_Decl, ':');

--         Assign
--           (New_Instr,
--            New_Instr (New_Instr'First .. Col_Decl) & " constant" &
--              New_Instr (Col_Decl + 1 .. New_Instr'Last));

--         Add_Line (New_Extract, Get_Stop (New_Extract), New_Instr.all);
--         Free (New_Instr);
--      end if;

--      Set_Caption
--        (New_Extract,
--         "Add ""constant"" to the declaration of """ & Name & """");

--      return New_Extract;
   end Not_Modified;

   -----------------------
   -- Resolve_Ambiguity --
   -----------------------

   function Resolve_Ambiguity
     (Current_Text     : Text_Navigator_Abstr'Class;
      Error_Cursor     : File_Cursor'Class;
      Solution_Cursors : Cursor_Lists.List;
      Name             : String) return Solution_List
   is
      pragma Unreferenced (Current_Text, Error_Cursor, Solution_Cursors, Name);
--    Str_Array     : array (1 .. Length (Solution_Cursors)) of Dynamic_String;
--      New_Extract   : Extract;
--      List_Extracts : Extract_List.List;
--      Error_Line    : File_Cursor := File_Cursor (Error_Cursor);
--      Cursor_Node   : Cursor_Lists.List_Node;
--      Index_Str     : Positive := 1;
   begin
      return Command_List.Null_List;

--      Cursor_Node := First (Solution_Cursors);

--      while Cursor_Node /= Cursor_Lists.Null_Node loop
--         Assign
--           (Str_Array (Index_Str),
--            Get_Extended_Unit_Name (Current_Text, Data (Cursor_Node)));

--         for J in 1 ..  Index_Str - 1 loop
--            if Str_Array (J).all = Str_Array (Index_Str).all then
               --  ???  Free
--               return Extract_List.Null_List;
--            end if;
--         end loop;

--         Error_Line.Col := 1;
--         Get_Line (Current_Text, Error_Line, New_Extract);

--         Add_Word
--           (New_Extract,
--            Error_Cursor,
--            Str_Array (Index_Str).all & ".");

--         Set_Caption
--           (New_Extract,
--            "Prefix """ & Name & """ by """ &
--              Str_Array (Index_Str).all & """");

--         Append (List_Extracts, New_Extract);
--         Unchecked_Free (New_Extract);

--         Index_Str := Index_Str + 1;
--         Cursor_Node := Next (Cursor_Node);
--      end loop;

--      return List_Extracts;
   end Resolve_Ambiguity;

   -----------------------
   -- Remove_Conversion --
   -----------------------

   function Remove_Conversion
     (Current_Text : Text_Navigator_Abstr'Class;
      Cursor       : File_Cursor'Class;
      Object_Name   : String) return Solution_List
   is
      pragma Unreferenced (Current_Text, Cursor, Object_Name);
--      procedure Right_Paren (Current_Index : in out Integer);
      --  Put Current_Index extactly on the right paren correponding the last
      --  left paren.

--      New_Extract   : Ada_Instruction;
--      Current_Line  : Ptr_Extract_Line;
--      Line_Cursor   : File_Cursor := File_Cursor (Cursor);
--      Str_Line      : Dynamic_String;
--      Current_Index : Natural := 1;

--      procedure Right_Paren (Current_Index : in out Integer) is
--      begin
--         loop
--            if Current_Index > Get_String (Current_Line.all)'Last then
--               Current_Index := 1;
--               Current_Line := Next (Current_Line.all);
--            end if;

--            case Get_String (Current_Line.all) (Current_Index) is
--               when '(' =>
--                  Current_Index := Current_Index + 1;
--                  Right_Paren (Current_Index);
--               when ')' =>
--                  return;
--               when others =>
--                  Current_Index := Current_Index + 1;
--            end case;
--         end loop;
--      end Right_Paren;

   begin
      return Command_List.Null_List;
--      Line_Cursor.Col := 1;
--      Get_Unit (Current_Text, Cursor, New_Extract);
--      Current_Line := Get_Line (New_Extract, Line_Cursor);

--      Erase
--        (New_Extract,
--         Cursor,
--         Search_String (New_Extract, "(", Cursor));

--      Current_Index := Cursor.Col;
--      Right_Paren (Current_Index);

--      Assign (Str_Line, Get_String (Current_Line.all));
--      Set_String
--        (Current_Line.all,
--         Str_Line (Str_Line'First .. Current_Index - 1) &
--           Str_Line (Current_Index + 1 .. Str_Line'Last));

--      Free (Str_Line);

--      Set_Caption
--      (New_Extract, "Remove useless conversion of """ & Object_Name & """");

--      return New_Extract;
   end Remove_Conversion;

   -----------------------
   -- Move_With_To_Body --
   -----------------------

   function Move_With_To_Body
     (Current_Text : Text_Navigator_Abstr'Class;
      Cursor       : File_Cursor'Class) return Solution_List
   is
      pragma Unreferenced (Current_Text, Cursor);
--      Spec_Extract         : Ada_List;
--      Body_Info, With_Info : Construct_Information;
--      Last_With            : File_Cursor;
--      Body_Name            : Dynamic_String;
   begin
      return Command_List.Null_List;
--      With_Info := Search_Unit
--        (Current_Text,
--         Cursor.File_Name.all,
--         Cat_With);

--      Assign
--        (Body_Name,
--         Get_Body_Or_Spec (Current_Text, Cursor.File_Name.all));

--      Body_Info := Search_Unit
--        (Current_Text,
--         Body_Name.all,
--         Cat_With,
--         With_Info.Name.all);

--      if Body_Info.Category = Cat_Unknown then
--         Assign (Last_With.File_Name, Body_Name.all);


--         Last_With.Col := 1;
--         Last_With.Line := 1;

--         Body_Info := Get_Unit (Current_Text, Last_With, After, Cat_Package);

--         Last_With.Line := Body_Info.Sloc_Start.Line - 1;

--         Spec_Extract := Delete_With
--           (Current_Text, Cursor, With_Info.Name.all, Last_With);
--      else
--         Spec_Extract := Delete_With
--           (Current_Text, Cursor, With_Info.Name.all);
--      end if;

--      Set_Caption
--        (Spec_Extract,
--         "Move with clause from """ & Cursor.File_Name.all &
--           """ to """ & Body_Name.all & """");

--      Free (Body_Name);
--      return Spec_Extract;
   end Move_With_To_Body;

end Codefix.Formal_Errors;
