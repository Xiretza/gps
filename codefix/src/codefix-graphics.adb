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

with Ada.Exceptions;         use Ada.Exceptions;

with Glib;                   use Glib;
with Gtk.GEntry;             use Gtk.GEntry;
with Gtk.Combo;              use Gtk.Combo;
with Gtk.Enums;              use Gtk.Enums;
with Gtk.Notebook;           use Gtk.Notebook;
with Gtk.Label;              use Gtk.Label;
with Gtk.Clist;              use Gtk.Clist;

with Diff_Utils;             use Diff_Utils;
with Vdiff_Pkg;              use Vdiff_Pkg;
with Vdiff_Utils;            use Vdiff_Utils;

with Codefix;                use Codefix;
with Codefix.Text_Manager;   use Codefix.Text_Manager;
with Codefix.Errors_Manager; use Codefix.Errors_Manager;
with Codefix.Merge_Utils;    use Codefix.Merge_Utils;
with Codefix.Formal_Errors;  use Codefix.Formal_Errors;
use Codefix.Formal_Errors.Command_List;

with Final_Window_Pkg;       use Final_Window_Pkg;

package body Codefix.Graphics is

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Graphic_Codefix : out Graphic_Codefix_Access;
      Kernel          : access Glide_Kernel.Kernel_Handle_Record'Class;
      Current_Text    : Ptr_Text_Navigator;
      Errors_Found    : Ptr_Errors_Interface) is
   begin
      Graphic_Codefix := new Graphic_Codefix_Record;
      Codefix.Graphics.Initialize
        (Graphic_Codefix, Kernel, Current_Text, Errors_Found);
   end Gtk_New;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Graphic_Codefix : access Graphic_Codefix_Record'Class;
      Kernel          : access Glide_Kernel.Kernel_Handle_Record'Class;
      Current_Text    : Ptr_Text_Navigator;
      Errors_Found    : Ptr_Errors_Interface) is
   begin
      Codefix_Window_Pkg.Initialize (Graphic_Codefix);

      Graphic_Codefix.Kernel := Kernel_Handle (Kernel);
      Graphic_Codefix.Current_Text := Current_Text;
      Graphic_Codefix.Errors_Found := Errors_Found;

      Analyze
        (Graphic_Codefix.Corrector,
         Graphic_Codefix.Current_Text.all,
         Graphic_Codefix.Errors_Found.all,
         null);

      Remove_Page (Graphic_Codefix.Choices_Proposed, 0);
      Load_Next_Error (Graphic_Codefix);
   end Initialize;

   ----------
   -- Free --
   ----------

   procedure Free (Graphic_Codefix : access Graphic_Codefix_Record'Class) is
   begin
      Free (Graphic_Codefix.Current_Text.all);
      Free (Graphic_Codefix.Corrector);
      Free (Graphic_Codefix.Errors_Found.all);
      Free (Graphic_Codefix.Vdiff_List);
      Destroy (Graphic_Codefix);
      --  Free_Parsers;  ??? Do I need to free parsers at the end of
      --  the program ?
   end Free;

   ----------
   -- Quit --
   ----------

   procedure Quit (Graphic_Codefix : access Graphic_Codefix_Record'Class) is
   begin
      Free (Graphic_Codefix);
   end Quit;

   ----------
   -- Free --
   ----------

   procedure Free (This : in out Vdiff_Access) is
      pragma Unreferenced (This);
   begin
      null;
   end Free;

   -----------------
   -- Next_Choice --
   -----------------

   procedure Next_Choice
     (Graphic_Codefix : access Graphic_Codefix_Record'Class) is
   begin
      Next_Page (Graphic_Codefix.Choices_Proposed);
   end Next_Choice;

   -----------------
   -- Prev_Choice --
   -----------------

   procedure Prev_Choice
     (Graphic_Codefix : access Graphic_Codefix_Record'Class) is
   begin
      Prev_Page (Graphic_Codefix.Choices_Proposed);
   end Prev_Choice;

   ---------------------
   -- Load_Next_Error --
   ---------------------

   procedure Load_Next_Error
     (Graphic_Codefix : access Graphic_Codefix_Record'Class)
   is
      procedure Display_Sol;
      --  Initialize the variable Proposition with the current solution.

      procedure Modify_Tab;
      --  Update the data recorded inside the current page of the Notebook.

      procedure Add_Tab;
      --  Add a page in the Notebook and initialize its data.

      Current_Sol      : Command_List.List_Node;
      Proposition      : Vdiff_Access;
      Label            : Gtk_Label;
      Current_Nb_Tabs  : Integer;
      Current_Vdiff    : Vdiff_Lists.List_Node;
      Extended_Extract : Extract;
--      Success_Update   : Boolean;
--      Already_Fixed    : Boolean;
      New_Popdown_Str  : String_List.Glist;

      -----------------
      -- Display_Sol --
      -----------------

      procedure Display_Sol is
         Current_Line      : Ptr_Extract_Line;
         First_Iterator    : Text_Iterator_Access;
         Current_Iterator  : Text_Iterator_Access;
         Previous_File     : Dynamic_String := new String'("");
         Total_Nb_Files    : constant Natural :=
           Get_Nb_Files (Extended_Extract);
      begin

         Current_Line := Get_First_Line (Extended_Extract);
         First_Iterator := new Text_Iterator;
         Current_Iterator := First_Iterator;

         if Current_Line = null then
            return;
         end if;

         loop
            if Total_Nb_Files > 1
              and then Previous_File.all /=
                Get_Cursor (Current_Line.all).File_Name.all
            then
               Assign (Previous_File, Get_Cursor (Current_Line.all).File_Name);
               Current_Iterator.New_Line :=
                 new String'(Previous_File.all);
               Current_Iterator.Old_Line :=
                 new String'(Previous_File.all);
               Current_Iterator.File_Caption := True;
               Current_Iterator.Next := new Text_Iterator;
               Current_Iterator := Current_Iterator.Next;
            end if;

            Current_Iterator.New_Line := new String'
              (Get_New_Text (Current_Line.all));

            if Get_Context (Current_Line.all) = Original_Unit then
               Current_Iterator.Old_Line := new String'
                 (Current_Iterator.New_Line.all);
            elsif Get_Context (Current_Line.all) /= Unit_Created then
               Current_Iterator.Old_Line := new String'(Get_Old_Text
                  (Current_Line.all, Graphic_Codefix.Current_Text.all));
            end if;

            Current_Iterator.Original_Position :=
              Get_Cursor (Current_Line.all).Line;

            case Get_Context (Current_Line.all) is
               when Original_Unit =>
                  Current_Iterator.Action := Nothing;
               when Unit_Modified =>
                  Current_Iterator.Action := Change;
               when Unit_Created =>
                  Current_Iterator.Action := Append;
               when Unit_Deleted =>
                  Current_Iterator.Action := Delete;
            end case;

            Current_Iterator.Color_Enabled :=
              Get_Coloration (Current_Line.all);
            Current_Line := Next (Current_Line.all);

            exit when Current_Line = null;

            Current_Iterator.Next := new Text_Iterator;
            Current_Iterator := Current_Iterator.Next;
         end loop;

         Free (Current_Iterator.Next);

         Fill_Diff_Lists
           (Graphic_Codefix.Kernel,
            Proposition.Clist1,
            Proposition.Clist2,
            First_Iterator);

         Free (First_Iterator);

         Set_Text (Proposition.Label1, "Old text");
         Set_Text (Proposition.Label2, "Fixed text");
         Set_Text
           (Proposition.File_Label1, Get_Files_Names (Extended_Extract, 50));
         Set_Text
           (Proposition.File_Label2, Get_Files_Names (Extended_Extract, 50));

         Free (Previous_File);
      end Display_Sol;

      ----------------
      -- Modify_Tab --
      ----------------

      procedure Modify_Tab is
      begin
         Proposition := Data (Current_Vdiff);
         Clear (Proposition.Clist1);
         Clear (Proposition.Clist2);
         Display_Sol;
      end Modify_Tab;

      -------------
      -- Add_Tab --
      -------------

      procedure Add_Tab is
      begin
         Gtk_New (Proposition);

         Gtk_New (Label, "Choice" & Integer'Image (Current_Nb_Tabs + 1));

         Display_Sol;

         Append_Page
           (Graphic_Codefix.Choices_Proposed,
            Proposition,
            Label);

         Append (Graphic_Codefix.Vdiff_List, Proposition);
      end Add_Tab;

      --  begin of Load_Next_Error

   begin
      if Graphic_Codefix.Current_Error /= Null_Error_Id then
         Graphic_Codefix.Current_Error := Next (Graphic_Codefix.Current_Error);
      else
         Graphic_Codefix.Current_Error :=
           Get_First_Error (Graphic_Codefix.Corrector);
      end if;

      if Graphic_Codefix.Current_Error = Null_Error_Id then
         declare
            Final_Window : Final_Window_Access;
         begin
            Gtk_New (Final_Window);
            Show_All (Final_Window);
            Final_Window.Graphic_Codefix := Graphic_Codefix_Access
              (Graphic_Codefix);
            return;
         end;
      end if;

      if Get_Error_State
        (Graphic_Codefix.Automatic_Skip,
         Get_Category (Graphic_Codefix.Current_Error)) = Enabled
      then
         Load_Next_Error (Graphic_Codefix);
         return;
      end if;

      if Length (Get_Solutions (Graphic_Codefix.Current_Error)) = 1
        and then Get_Error_State
          (Graphic_Codefix.Automatic_Fix,
           Get_Category (Graphic_Codefix.Current_Error)) = Enabled
      then
         Validate_And_Commit
           (Graphic_Codefix.Corrector,
            Graphic_Codefix.Current_Text.all,
            Graphic_Codefix.Current_Error,
            1);
         Load_Next_Error (Graphic_Codefix);
         return;
      end if;

      Current_Sol := First (Get_Solutions (Graphic_Codefix.Current_Error));
      Current_Vdiff := First (Graphic_Codefix.Vdiff_List);

      Current_Nb_Tabs := 0;

      while Current_Sol /= Command_List.Null_Node loop
         Execute
           (Data (Current_Sol),
            Graphic_Codefix.Current_Text.all,
            Extended_Extract);

         Extend_Before
           (Extended_Extract,
            Graphic_Codefix.Current_Text.all,
            Display_Lines_Before);
         Extend_After
           (Extended_Extract,
            Graphic_Codefix.Current_Text.all,
            Display_Lines_After);

--         Update_Changes
--           (Graphic_Codefix.Corrector,
--            Graphic_Codefix.Current_Text,
--            Extended_Extract,
--            Success_Update,
--            Already_Fixed);

--         if Already_Fixed or else not Success_Update then
--            Free (Extended_Extract);
--            exit;
--         end if;
--

         if Current_Vdiff /= Vdiff_Lists.Null_Node then
            Modify_Tab;
            Current_Vdiff := Next (Current_Vdiff);
         else
            Add_Tab;
         end if;

         Current_Nb_Tabs := Current_Nb_Tabs + 1;
         String_List.Append
           (New_Popdown_Str, Get_Caption (Data (Current_Sol)));

         Free (Extended_Extract);

         Current_Sol := Next (Current_Sol);
      end loop;

      Set_Popdown_Strings (Graphic_Codefix.Fix_Caption_List, New_Popdown_Str);

      Graphic_Codefix.Nb_Tabs := Current_Nb_Tabs;
      Set_Text
        (Graphic_Codefix.Error_Caption,
         Get_Message (Get_Error_Message (Graphic_Codefix.Current_Error)));

      if Current_Nb_Tabs = 1
        and then Get_Error_State
          (Graphic_Codefix.Automatic_Fix,
           Get_Category (Graphic_Codefix.Current_Error)) = Enabled
      then
         Valid_Current_Solution (Graphic_Codefix);
         Load_Next_Error (Graphic_Codefix);
         return;
      end if;

      Set_Current_Page (Graphic_Codefix.Choices_Proposed, 0);

      --  ???  Maybe an other function to print changes in notebook ?
      Show_All (Graphic_Codefix);
   end Load_Next_Error;

   ----------------------------
   -- Valid_Current_Solution --
   ----------------------------

   procedure Valid_Current_Solution
     (Graphic_Codefix : access Graphic_Codefix_Record'Class)
   is
      Current_Command : Command_List.List_Node;
   begin
      Current_Command := First (Get_Solutions (Graphic_Codefix.Current_Error));

      while Get_Caption (Data (Current_Command)) /=
        Get_Text (Graphic_Codefix.Fix_Entry)
      loop

         Current_Command := Next (Current_Command);

         if Current_Command = Command_List.Null_Node then
            Raise_Exception
              (Codefix_Panic'Identity,
               "Text """ &
                 Get_Text (Graphic_Codefix.Fix_Entry) &
               """ red in graphic entry not found in internal solution list");
         end if;
      end loop;

      Validate_And_Commit
        (Graphic_Codefix.Corrector,
         Graphic_Codefix.Current_Text.all,
         Graphic_Codefix.Current_Error,
         Data (Current_Command));
   end Valid_Current_Solution;

   ----------------------
   -- Get_Nth_Solution --
   ----------------------

   function Get_Nth_Solution
     (Graphic_Codefix : access Graphic_Codefix_Record'Class) return Gint
   is
      Current_Command : Command_List.List_Node;
      Current_Number  : Gint := 1;
   begin
      Current_Command := First (Get_Solutions (Graphic_Codefix.Current_Error));

      while Get_Caption (Data (Current_Command)) /=
        Get_Text (Graphic_Codefix.Fix_Entry)
      loop
         Current_Number := Current_Number + 1;
         Current_Command := Next (Current_Command);

         if Current_Command = Command_List.Null_Node then
            Raise_Exception
              (Codefix_Panic'Identity,
               "Text """ &
                 Get_Text (Graphic_Codefix.Fix_Entry) &
               """ red in graphic entry not found in internal solution list");
         end if;
      end loop;

      return Current_Number;
   end Get_Nth_Solution;

end Codefix.Graphics;
