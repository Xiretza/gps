-----------------------------------------------------------------------
--              GtkAda - Ada95 binding for Gtk+/Gnome                --
--                                                                   --
--                     Copyright (C) 2001                            --
--                         ACT-Europe                                --
--                                                                   --
-- This library is free software; you can redistribute it and/or     --
-- modify it under the terms of the GNU General Public               --
-- License as published by the Free Software Foundation; either      --
-- version 2 of the License, or (at your option) any later version.  --
--                                                                   --
-- This library is distributed in the hope that it will be useful,   --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of    --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details.                          --
--                                                                   --
-- You should have received a copy of the GNU General Public         --
-- License along with this library; if not, write to the             --
-- Free Software Foundation, Inc., 59 Temple Place - Suite 330,      --
-- Boston, MA 02111-1307, USA.                                       --
--                                                                   --
-- As a special exception, if other files instantiate generics from  --
-- this unit, or you link this unit with other files to produce an   --
-- executable, this  unit  does not  by itself cause  the resulting  --
-- executable to be covered by the GNU General Public License. This  --
-- exception does not however invalidate any other reasons why the   --
-- executable file  might be covered by the  GNU Public License.     --
-----------------------------------------------------------------------

with Glib;                   use Glib;
with Glib.Object;            use Glib.Object;
with Glib.Values;            use Glib.Values;
with Gtk;                    use Gtk;
with Gtk.Handlers;           use Gtk.Handlers;
with Gtk.Text_Iter;          use Gtk.Text_Iter;
with Gtk.Text_Mark;          use Gtk.Text_Mark;
with Gtk.Text_Tag_Table;     use Gtk.Text_Tag_Table;
with Gtkada.Types;           use Gtkada.Types;
with Pango.Enums;

with Basic_Types;            use Basic_Types;
with Language;               use Language;
with Src_Highlighting;       use Src_Highlighting;

with GNAT.OS_Lib;            use GNAT.OS_Lib;
with Interfaces.C.Strings;   use Interfaces.C.Strings;
with System;
with String_Utils;           use String_Utils;

package body Src_Editor_Buffer is

   use type System.Address;

   Default_Keyword_Color : constant String := "";
   Default_Comment_Color : constant String := "blue";
   Default_String_Color  : constant String := "brown";
   --  ??? As soon as we have defined a uniform GLIDE handling of
   --  ??? defaults/preferences, these constants should move there.

   Default_Keyword_Font_Attr  : constant Font_Attributes :=
     To_Font_Attributes (Weight => Pango.Enums.Pango_Weight_Bold);
   Default_Comment_Font_Attr  : constant Font_Attributes :=
     To_Font_Attributes (Style => Pango.Enums.Pango_Style_Italic);
   Default_String_Font_Attr   : constant Font_Attributes :=
     To_Font_Attributes;
   --  ??? Just as for the colors, these will eventually move away.

   Default_HL_Line_Color : constant String := "green";
   --  ??? As soon as a uniform GLIDE handling of defaults/preferences
   --  ??? is put in place, move this constant there.

   Default_HL_Region_Color : constant String := "cyan";
   --  ??? Move to GLIDE defaults/preferences area.

   Class_Record : GObject_Class := Uninitialized_Class;
   --  A pointer to the 'class record'.

   Signals : Interfaces.C.Strings.chars_ptr_array :=
     (1 => New_String ("cursor_position_changed"));
   --  The list of new signals supported by this GObject

   Signal_Parameters : constant Glib.Object.Signal_Parameter_Types :=
     (1 => (GType_Int, GType_Int));
   --  The parameters associated to each new signal

   package Buffer_Callback is new Gtk.Handlers.Callback
     (Widget_Type => Source_Buffer_Record);

   --------------------------
   -- Forward declarations --
   --------------------------

   procedure Changed_Handler
     (Buffer : access Source_Buffer_Record'Class;
      Params : Glib.Values.GValues);
   --  This procedure is used to signal to the clients that the insert
   --  cursor position may have changed by emitting the
   --  "cursor_position_changed" signal.

   procedure Mark_Set_Handler
     (Buffer : access Source_Buffer_Record'Class;
      Params : Glib.Values.GValues);
   --  This procedure is used to signal to the clients that the insert
   --  cursor position has changed by emitting the "cursor_position_changed"
   --  signal. This signal is emitted only when the mark changed is the
   --  Insert_Mark.

   procedure Insert_Text_Cb
     (Buffer          : access Source_Buffer_Record'Class;
      End_Insert_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      Text            : String);
   --  This procedure recomputes the syntax-highlighting of the buffer
   --  in a semi-optimized manor, based on syntax-highlighting already
   --  done before the insertion and the text added.
   --
   --  This procedure assumes that the language has been set.

   procedure Insert_Text_Handler
     (Buffer : access Source_Buffer_Record'Class;
      Params : Glib.Values.GValues);
   --  This procedure is just a proxy between the "insert_text" signal
   --  and the Insert_Text_Cb callback. It extracts the parameters from
   --  Params and then call Insert_Text_Cb. For efficiency reasons, the
   --  signal is processed only when Lang is not null.
   --
   --  Note that this handler is designed to be connected "after", in which
   --  case the Insert_Iter iterator is located at the end of the inserted
   --  text.

   procedure First_Insert_Text
     (Buffer : access Source_Buffer_Record'Class;
      Params : Glib.Values.GValues);
   --  First handler connected to the "insert_text" signal.
   --  This handler will handle automatic indentation of Text.

   procedure Delete_Range_Cb
     (Buffer : access Source_Buffer_Record'Class;
      Iter   : Gtk_Text_Iter);
   --  This procedure recomputes the syntax-highlighting of the buffer
   --  in a semi-optimized manor, based on syntax-highlighting already
   --  done before the deletion and the location of deletion.
   --
   --  This procedure assumes that the language has been set.

   procedure Delete_Range_Handler
     (Buffer : access Source_Buffer_Record'Class;
      Params : Glib.Values.GValues);
   --  This procedure is just a proxy between the "delete_range" signal
   --  and the Delete_Range_Cb callback. It extracts the parameters from
   --  Params and then call Delete_Range_Cb. For efficiency reasons, the
   --  signal is processed only when Lang is not null.
   --
   --  Note that this handler is designed to be connected "after", in which
   --  case the Start and End iterators are equal, since the text between
   --  these iterators have already been deleted.

   procedure Emit_New_Cursor_Position
     (Buffer : access Source_Buffer_Record'Class;
      Line   : Gint;
      Column : Gint);
   --  Signal the new cursor position by emitting the "cursor_position_changed"
   --  signal. Line and Column are the new line and column number of the
   --  cursor. Note that line numbers start from 1.

   procedure Highlight_Slice
     (Buffer     : access Source_Buffer_Record'Class;
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter);
   --  Re-compute the highlighting for at the least the given region.
   --  If the text creates non-closed comments or string regions, then
   --  the re-highlighted area is automatically extended to the right.
   --  When the re-highlighted area is extended to the right, the extension
   --  is computed in a semi-intelligent fashion.

   procedure Kill_Highlighting
     (Buffer : access Source_Buffer_Record'Class;
      From   : Gtk_Text_Iter;
      To     : Gtk_Text_Iter);
   --  Remove all highlighting tags for the given region.

   procedure Forward_To_Line_End (Iter : in out Gtk_Text_Iter);
   --  This is a temporary implementation of Gtk.Text_Iter.Forward_To_Line_End
   --  because the gtk+ one is broken at the moment, and causes Critical
   --  warnings.
   --  ??? Remove this procedure when the problem is fixed.

   procedure Strip_Ending_Line_Terminator
     (Buffer : access Source_Buffer_Record'Class);
   --  Delete the last character of the buffer if it is an ASCII.LF.

   ---------------------
   -- Changed_Handler --
   ---------------------

   procedure Changed_Handler
     (Buffer : access Source_Buffer_Record'Class;
      Params : Glib.Values.GValues)
   is
      Line : Gint;
      Col  : Gint;
   begin
      Get_Cursor_Position (Buffer, Line => Line, Column => Col);
      Emit_New_Cursor_Position (Buffer, Line => Line, Column => Col);
   end Changed_Handler;

   ----------------------
   -- Mark_Set_Handler --
   ----------------------

   procedure Mark_Set_Handler
     (Buffer : access Source_Buffer_Record'Class;
      Params : Glib.Values.GValues)
   is
      Mark : constant Gtk_Text_Mark :=
        Get_Text_Mark (Glib.Values.Nth (Params, 2));
   begin
      --  Emit the new cursor position if it is the Insert_Mark that was
      --  changed.
      if Get_Object (Mark) /= Get_Object (Buffer.Insert_Mark) then
         declare
            Iter : Gtk_Text_Iter;
            Line : Gint;
            Col  : Gint;
         begin
            Get_Text_Iter (Glib.Values.Nth (Params, 1), Iter);
            Line := Get_Line (Iter);
            Col := Get_Line_Offset (Iter);
            Emit_New_Cursor_Position (Buffer, Line => Line, Column => Col);
         end;
      end if;
   end Mark_Set_Handler;

   --------------------
   -- Insert_Text_Cb --
   --------------------

   procedure Insert_Text_Cb
     (Buffer          : access Source_Buffer_Record'Class;
      End_Insert_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      Text            : String)
   is
      Start_Iter  : Gtk_Text_Iter;
      End_Iter    : Gtk_Text_Iter;
      Entity_Kind : Language_Entity;
      Ignored     : Boolean;

      Tags : Highlighting_Tags renames Buffer.Syntax_Tags;
   begin
      --  Set the Start_Iter to the begining of the inserted text,
      --  and set the End_Iter.
      Copy (Source => End_Insert_Iter, Dest => Start_Iter);
      Backward_Chars (Start_Iter, Text'Length, Ignored);
      Copy (Source => End_Insert_Iter, Dest => End_Iter);

      --  Search the initial minimum area to re-highlight...
      Entity_Kind := Normal_Text;

      Entity_Kind_Search_Loop :
      for Current_Entity in Standout_Language_Entity loop

         if Has_Tag (Start_Iter, Tags (Current_Entity)) then
            --  This means that we are in a highlighted region. The minimum
            --  region to re-highlight starts from the begining of the current
            --  region to the end of the following region.
            Entity_Kind := Current_Entity;
            Backward_To_Tag_Toggle (Start_Iter, Result => Ignored);
            Forward_To_Tag_Toggle (End_Iter, Tags (Entity_Kind), Ignored);
            Forward_To_Tag_Toggle (End_Iter, Result => Ignored);
            exit Entity_Kind_Search_Loop;

         elsif Begins_Tag (End_Iter, Tags (Current_Entity)) or else
           Ends_Tag (Start_Iter, Tags (Current_Entity))
         then
            --  Case Begins_Tag:
            --    This means that we inserted right at the begining of
            --    a highlighted region... The minimum region to re-highlight
            --    starts from the begining of the previous region to the
            --    end of the current region.
            --  Case Ends_Tag:
            --    This means that we inserted right at the end of a highlighted
            --    region. In this case, the minimum region to re-highlight
            --    starts from the begining of the previous region to the end of
            --    the current region.
            --  In both cases, the processing is the same...

            Entity_Kind := Current_Entity;
            Backward_To_Tag_Toggle (Start_Iter, Result => Ignored);
            Forward_To_Tag_Toggle (End_Iter, Result => Ignored);
            exit Entity_Kind_Search_Loop;
         end if;
      end loop Entity_Kind_Search_Loop;

      if Entity_Kind = Normal_Text then
         --  We are inside a normal text region. Just re-highlight this region.
         Backward_To_Tag_Toggle (Start_Iter, Result => Ignored);
         Forward_To_Tag_Toggle (End_Iter, Result => Ignored);
      end if;

      Highlight_Slice (Buffer, Start_Iter, End_Iter);
   end Insert_Text_Cb;

   -------------------------
   -- Insert_Text_Handler --
   -------------------------

   procedure Insert_Text_Handler
     (Buffer : access Source_Buffer_Record'Class;
      Params : Glib.Values.GValues) is
   begin
      if Buffer.Lang /= null then
         declare
            Pos    : Gtk_Text_Iter;
            Length : constant Gint := Get_Int (Nth (Params, 3));
            Text   : constant String :=
              Get_String (Nth (Params, 2), Length => Length);

         begin
            Get_Text_Iter (Nth (Params, 1), Pos);
            Insert_Text_Cb (Buffer, Pos, Text);
         end;
      end if;
   end Insert_Text_Handler;

   -----------------------
   -- First_Insert_Text --
   -----------------------

   Spaces : constant String (1 .. 256) := (others => ' ');

   procedure First_Insert_Text
     (Buffer : access Source_Buffer_Record'Class;
      Params : Glib.Values.GValues) is
   begin
      if Buffer.Inserting then
         return;
      end if;

      if Buffer.Lang /= null then
         declare
            Pos         : Gtk_Text_Iter;
            Length      : constant Gint := Get_Int (Nth (Params, 3));
            Text        : constant String :=
              Get_String (Nth (Params, 2), Length => Length);
            Indent      : Natural;
            Next_Indent : Natural;
            Line, Col   : Gint;
            C_Str       : Gtkada.Types.Chars_Ptr;

         begin
            Get_Text_Iter (Nth (Params, 1), Pos);

            if Length = 1 and then Text (1) = ASCII.LF then
               Get_Cursor_Position (Buffer, Line, Col);

               --  We're spending most of our time getting this string.
               --  Consider saving the current line, indentation level and
               --  the stacks used by Next_Indentation to avoid parsing
               --  the buffer from scratch each time.

               C_Str := Get_Slice (Buffer, 0, 0, Line, Col);

               declare
                  Slice        : Unchecked_String_Access :=
                    To_Unchecked_String (C_Str);
                  pragma Suppress (Access_Check, Slice);
                  Start        : Integer;
                  Slice_Length : constant Natural :=
                    Natural (Strlen (C_Str)) + 1;
                  Index        : Integer := Slice_Length - 1;

               begin
                  Slice (Slice_Length) := ASCII.LF;
                  Next_Indentation
                    (Buffer.Lang, C_Str, Slice_Length, Indent, Next_Indent);

                  --  Stop propagation of this signal, since we will completely
                  --  replace the current line in the call to Replace_Slice
                  --  below.

                  Emit_Stop_By_Name (Buffer, "insert_text");

                  Skip_To_Char (Slice.all, Index, ASCII.LF, -1);

                  if Index < Slice'First then
                     Index := Slice'First;
                  end if;

                  Start := Index;

                  while Index <= Slice_Length
                    and then (Slice (Index) = ' '
                              or else Slice (Index) = ASCII.HT
                              or else Slice (Index) = ASCII.LF
                              or else Slice (Index) = ASCII.CR)
                  loop
                     Index := Index + 1;
                  end loop;

                  if Index > Slice_Length then
                     Index := Slice_Length;
                  end if;

                  --  Prevent recursion
                  Buffer.Inserting := True;

                  --  Replace everything at once, important for efficiency
                  --  and also because otherwise, some marks will no longer be
                  --  valid.

                  Replace_Slice
                    (Buffer, Line, 0, Line, Col,
                     Spaces (1 .. Indent) & Slice (Index .. Slice_Length) &
                     Spaces (1 .. Next_Indent));

                  Buffer.Inserting := False;
                  g_free (C_Str);
               end;
            end if;
         end;
      end if;
   end First_Insert_Text;

   ---------------------
   -- Delete_Range_Cb --
   ---------------------

   procedure Delete_Range_Cb
     (Buffer : access Source_Buffer_Record'Class;
      Iter   : Gtk_Text_Iter)
   is
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter;
      Ignored    : Boolean;

   begin
      --  Search the initial minimum area to re-highlight:
      --    - case Has_Tag:
      --        This means that we are inside a highlighted region. In that
      --        case, we just re-highlight this region.
      --    - case Begins_Tag:
      --        We are at the begining of a highlighted region. We re-highlight
      --        from the begining of the previous region to the end of this
      --        region.
      --    - case Ends_Tag:
      --        We are at the end of a highlighed region. We re-highlight from
      --        the begining of this region to the end of the next region.
      --  I all three cases, the processing is the same...

      Copy (Source => Iter, Dest => Start_Iter);
      Copy (Source => Iter, Dest => End_Iter);
      Backward_To_Tag_Toggle (Start_Iter, Result => Ignored);
      Forward_To_Tag_Toggle (End_Iter, Result => Ignored);
      Highlight_Slice (Buffer, Start_Iter, End_Iter);
   end Delete_Range_Cb;

   --------------------------
   -- Delete_Range_Handler --
   --------------------------

   procedure Delete_Range_Handler
     (Buffer : access Source_Buffer_Record'Class;
      Params : Glib.Values.GValues) is
   begin
      if Buffer.Lang /= null then
         declare
            Start_Iter : Gtk_Text_Iter;
         begin
            Get_Text_Iter (Nth (Params, 1), Start_Iter);
            Delete_Range_Cb (Buffer, Start_Iter);
         end;
      end if;
   end Delete_Range_Handler;

   ------------------------------
   -- Emit_New_Cursor_Position --
   ------------------------------

   procedure Emit_New_Cursor_Position
     (Buffer : access Source_Buffer_Record'Class;
      Line   : Gint;
      Column : Gint)
   is
      procedure Emit_By_Name
        (Object : System.Address;
         Name   : String;
         Line   : Gint;
         Column : Gint);
      pragma Import (C, Emit_By_Name, "g_signal_emit_by_name");

   begin
      Emit_By_Name
        (Get_Object (Buffer), "cursor_position_changed" & ASCII.NUL,
         Line => Line, Column => Column);
   end Emit_New_Cursor_Position;

   ---------------------
   -- Highlight_Slice --
   ---------------------

   procedure Highlight_Slice
     (Buffer     : access Source_Buffer_Record'Class;
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter)
   is
      Lang_Context        : constant Language_Context :=
        Get_Language_Context (Buffer.Lang);
      Entity              : Language_Entity;
      Entity_Start        : Gtk_Text_Iter;
      Entity_End          : Gtk_Text_Iter;
      An_Iter             : Gtk_Text_Iter;
      Ignored             : Boolean;
      Tags                : Highlighting_Tags renames Buffer.Syntax_Tags;

      procedure Local_Highlight (From : Gtk_Text_Iter; To : Gtk_Text_Iter);
      --  Highlight the region exactly located between From and To.
      --  After this procedure is run, some variables are positioned to
      --  the following values:
      --    - Entity is equal to the last entity kind found inside the
      --      given region
      --    - Entity_Start is set to the begining of the last region found
      --      in the given buffer slice
      --    - Entity_End is set to the end of the given buffer slice.

      procedure Local_Highlight (From : Gtk_Text_Iter; To : Gtk_Text_Iter) is
         Slice               : constant String := Get_Slice (From, To);
         Slice_Offset        : constant Gint := Get_Offset (From);
         Entity_Start_Offset : Gint;
         Entity_End_Offset   : Gint;
         Entity_Length       : Gint;
         Index               : Natural := Slice'First;
         Next_Char           : Positive;
      begin
         --  First, un-apply all the style tags...
         Kill_Highlighting (Buffer, From, To);

         --  Now re-highlight the text...
         Copy (Source => From, Dest => Entity_Start);
         Entity_Start_Offset := Slice_Offset;

         Highlight_Loop :
         loop
            Looking_At
              (Buffer.Lang, Slice (Index .. Slice'Last), Entity, Next_Char);

            Entity_Length := Gint (Next_Char - Index);
            Entity_End_Offset := Entity_Start_Offset + Entity_Length;
            Get_Iter_At_Offset (Buffer, Entity_End, Entity_End_Offset);

            if Entity in Standout_Language_Entity then
               Apply_Tag (Buffer, Tags (Entity), Entity_Start, Entity_End);
            end if;

            exit Highlight_Loop when Next_Char > Slice'Last;

            Index := Next_Char;
            Entity_Start_Offset := Entity_End_Offset;
            Copy (Source => Entity_End, Dest => Entity_Start);
         end loop Highlight_Loop;
      end Local_Highlight;

   begin
      Local_Highlight (From => Start_Iter, To => End_Iter);

      --  Check the last entity found during the highlighting loop
      case Entity is

         when Normal_Text |
              Keyword_Text =>
            --  Nothing to do in that case, the current highlighting is already
            --  perfect.
            null;

         when Comment_Text =>

            if Lang_Context.New_Line_Comment_Start_Length /= 0 then
               --  Apply the Comment_Text tag from the end of the current
               --  highlighted area to the end of the current line.
               Copy (Source => Entity_End, Dest => Entity_Start);
               Forward_To_Line_End (Entity_End);
               Kill_Highlighting (Buffer, Entity_Start, Entity_End);
               Apply_Tag (Buffer, Tags (Entity), Entity_Start, Entity_End);

            elsif Lang_Context.Comment_End_Length /= 0 then
               --  In this case, comments end with a defined string. check the
               --  last characters if they match the end-of-comment string. If
               --  they match, then verify that it is indeed an end-of-comment
               --  string when the start-of-comment and end-of-comment strings
               --  are identical (this is done by checking if the comments
               --  tag is applied at the begining of the suposed end-of-comment
               --  string). If the comment area is not closed, then
               --  re-highlight up to the end of the buffer.

               Copy (Source => Entity_End, Dest => An_Iter);
               Backward_Chars
                 (An_Iter, Gint (Lang_Context.Comment_End_Length), Ignored);

               if Get_Slice (An_Iter, Entity_End) /=
                    Lang_Context.Comment_End or else
                  not (Lang_Context.Comment_Start =
                         Lang_Context.Comment_End and then
                       Has_Tag (An_Iter, Tags (Comment_Text)))
               then
                  Forward_To_End (Entity_End);
                  Local_Highlight (From => Entity_Start, To => Entity_End);
               end if;

            end if;

         when String_Text =>
            --  First, check that we don't have a constant character...
            --  We have a constant Character region if the length of the
            --  region is exactly 3 (2 delimiters + the character), and
            --  the first and last characters are equal to
            --  Lang_Context.Constant_Character.

            if Get_Offset (Entity_Start) - Get_Offset (Entity_End) = 3
               and then
               Get_Char (Entity_Start) = Lang_Context.Constant_Character
            then
               Copy (Source => Entity_End, Dest => An_Iter);
               Backward_Char (An_Iter, Ignored);
               if Get_Char (An_Iter) = Lang_Context.Constant_Character then
                  --  In this case, the text following this area is not
                  --  affected, so there is no more text to re-highlight.
                  return;
               end if;
            end if;

            --  Now, verify that the string is closed by checking the last
            --  character against the string delimiter. If we find it,
            --  then make sure that we are indeed closing the string
            --  (as opposed to opening it) by checking whether the String_Text
            --  tag is applied at the position before the string delimiter.

            Copy (Source => Entity_End, Dest => An_Iter);
            Backward_Char (An_Iter, Ignored);

            if Get_Char (An_Iter) /= Lang_Context.String_Delimiter or else
               not Has_Tag (An_Iter, Tags (String_Text))
            then
               Forward_To_Line_End (Entity_End);
               Local_Highlight (From => Entity_Start, To => Entity_End);
            end if;
      end case;
   end Highlight_Slice;

   -----------------------
   -- Kill_Highlighting --
   -----------------------

   procedure Kill_Highlighting
     (Buffer : access Source_Buffer_Record'Class;
      From   : Gtk_Text_Iter;
      To     : Gtk_Text_Iter) is
   begin
      for Entity_Kind in Standout_Language_Entity loop
         Remove_Tag (Buffer, Buffer.Syntax_Tags (Entity_Kind), From, To);
      end loop;
   end Kill_Highlighting;

   -------------------------
   -- Forward_To_Line_End --
   -------------------------

   procedure Forward_To_Line_End (Iter : in out Gtk_Text_Iter) is
      Result_Ignored : Boolean;
   begin
      while not Is_End (Iter) and then not Ends_Line (Iter) loop
         Forward_Char (Iter, Result_Ignored);
      end loop;
   end Forward_To_Line_End;

   ----------------------------------
   -- Strip_Ending_Line_Terminator --
   ----------------------------------

   procedure Strip_Ending_Line_Terminator
     (Buffer : access Source_Buffer_Record'Class)
   is
      Iter      : Gtk_Text_Iter;
      End_Iter  : Gtk_Text_Iter;
      Ignored   : Boolean;
   begin
      --  Does the buffer end with CR & LF?
      if Get_Char_Count (Buffer) > 1 then
         Get_End_Iter (Buffer, End_Iter);
         Copy (Source => End_Iter, Dest => Iter);
         Backward_Chars (Iter, Count => 2, Result => Ignored);
         if Get_Slice (Iter, End_Iter) = ASCII.CR & ASCII.LF then
            Delete (Buffer, Iter, End_Iter);
            return;
         end if;
      end if;

      --  Or does it end with a CR or LF?
      if Get_Char_Count (Buffer) > 0 then
         Get_End_Iter (Buffer, Iter);
         Backward_Char (Iter, Ignored);
         case Character'(Get_Char (Iter)) is
            when ASCII.LF | ASCII.CR =>
               Get_End_Iter (Buffer, End_Iter);
               Delete (Buffer, Iter, End_Iter);
            when others =>
               null;
         end case;
      end if;
   end Strip_Ending_Line_Terminator;

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Buffer : out Source_Buffer;
      Lang   : Language.Language_Access := null) is
   begin
      Buffer := new Source_Buffer_Record;
      Initialize (Buffer, Lang);
   end Gtk_New;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Buffer : access Source_Buffer_Record'Class;
      Lang   : Language.Language_Access := null)
   is
      Tags : Gtk_Text_Tag_Table;
   begin
      Gtk.Text_Buffer.Initialize (Buffer);
      Glib.Object.Initialize_Class_Record
        (Buffer, Signals, Class_Record, "GlideSourceBuffer",
         Signal_Parameters);

      Buffer.Lang := Lang;

      Buffer.Syntax_Tags :=
        Create_Syntax_Tags
          (Keyword_Color     => Default_Keyword_Color,
           Keyword_Font_Attr => Default_Keyword_Font_Attr,
           Comment_Color     => Default_Comment_Color,
           Comment_Font_Attr => Default_Comment_Font_Attr,
           String_Color      => Default_String_Color,
           String_Font_Attr  => Default_String_Font_Attr);
      --  ??? Use preferences for the colors and font attributes...

      --  Save the newly created highlighting tags into the source buffer
      --  tag table.

      Tags := Get_Tag_Table (Buffer);

      for Entity_Kind in Standout_Language_Entity'Range loop
         Text_Tag_Table.Add (Tags, Buffer.Syntax_Tags (Entity_Kind));
      end loop;

      --  Create HL_Line_Tag and save it into the source buffer tag table.
      Create_Highlight_Line_Tag (Buffer.HL_Line_Tag, Default_HL_Line_Color);
      Text_Tag_Table.Add (Tags, Buffer.HL_Line_Tag);

      --  Create HL_Region_Tag and save it into the source buffer tag table.
      Create_Highlight_Region_Tag
        (Buffer.HL_Region_Tag, Default_HL_Region_Color);
      Text_Tag_Table.Add (Tags, Buffer.HL_Region_Tag);

      --  Save the insert mark for fast retrievals, since we will need to
      --  access it very often.
      Buffer.Insert_Mark := Get_Insert (Buffer);

      --  And finally, connect ourselves to the interestings signals

      Buffer_Callback.Connect
        (Buffer, "changed", Cb => Changed_Handler'Access, After => True);
      Buffer_Callback.Connect
        (Buffer, "mark_set", Cb => Mark_Set_Handler'Access, After => True);
      Buffer_Callback.Connect
        (Buffer, "insert_text",
         Cb => First_Insert_Text'Access);
      Buffer_Callback.Connect
        (Buffer, "insert_text",
         Cb => Insert_Text_Handler'Access,
         After => True);
      Buffer_Callback.Connect
        (Buffer, "delete_range",
         Cb => Delete_Range_Handler'Access,
         After => True);
   end Initialize;

   ---------------
   -- Load_File --
   ---------------

   procedure Load_File
     (Buffer          : access Source_Buffer_Record;
      Filename        : String;
      Lang_Autodetect : Boolean := True;
      Success         : out Boolean)
   is
      FD : File_Descriptor := Invalid_FD;
      File_Buffer_Length : constant := 128 * 1_024;
      File_Buffer : String (1 .. File_Buffer_Length);
      Characters_Read : Natural;
   begin
      Success := True;

      FD := Open_Read (Filename & ASCII.NUL, Fmode => Text);
      if FD = Invalid_FD then
         Success := False;
         return;
      end if;

      Clear (Buffer);

      if Lang_Autodetect then
         Set_Language (Buffer, Get_Language_From_File (Filename));
      end if;

      Characters_Read := File_Buffer_Length;
      while Characters_Read = File_Buffer_Length loop
         Characters_Read := Read (FD, File_Buffer'Address, File_Buffer_Length);
         if Characters_Read > 0 then
            Insert_At_Cursor (Buffer, File_Buffer (1 .. Characters_Read));
         end if;
      end loop;

      Close (FD);

      Strip_Ending_Line_Terminator (Buffer);

   exception
      when others =>
         --  To avoid consuming up all File Descriptors, we catch all
         --  exceptions here, and close the current file descriptor before
         --  reraising the exception.
         if FD /= Invalid_FD then
            Close (FD);
         end if;
         raise;
   end Load_File;

   ------------------
   -- Save_To_File --
   ------------------

   procedure Save_To_File
     (Buffer   : access Source_Buffer_Record;
      Filename : String;
      Success  : out Boolean)
   is
      FD         : File_Descriptor := Invalid_FD;
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter;
   begin
      Success := True;

      FD := Create_File (Filename & ASCII.NUL, Fmode => Text);

      if FD = Invalid_FD then
         Success := False;
         return;
      end if;

      Get_Bounds (Buffer, Start_Iter, End_Iter);

      declare
         File_Buffer : constant String :=
           Get_Text (Buffer, Start_Iter, End_Iter);
         Bytes_Written : Integer;

      begin
         Bytes_Written := Write (FD, File_Buffer'Address, File_Buffer'Length);

         if Bytes_Written /= File_Buffer'Length then
            --  Means that there is not enough space to save the file. Return
            --  a failure.
            Success := False;
         end if;
      end;

      Close (FD);

   exception
      when others =>
         --  To avoid consuming up all File Descriptors, we catch all
         --  exceptions here, and close the current file descriptor before
         --  reraising the exception.

         if FD /= Invalid_FD then
            Close (FD);
         end if;

         raise;
   end Save_To_File;

   -----------
   -- Clear --
   -----------

   procedure Clear (Buffer : access Source_Buffer_Record) is
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter;
   begin
      if Get_Char_Count (Buffer) > 0 then
         Get_Bounds (Buffer, Start_Iter, End_Iter);
         Delete (Buffer, Start_Iter, End_Iter);
      end if;
   end Clear;

   ------------------
   -- Set_Language --
   ------------------

   procedure Set_Language
     (Buffer : access Source_Buffer_Record;
      Lang   : Language.Language_Access)
   is
      Buffer_Start_Iter : Gtk_Text_Iter;
      Buffer_End_Iter   : Gtk_Text_Iter;
   begin
      if Buffer.Lang /= Lang then
         Buffer.Lang := Lang;
         Get_Bounds (Buffer, Buffer_Start_Iter, Buffer_End_Iter);

         --  Do not try to highlight an empty buffer
         if not Is_End (Buffer_Start_Iter) then
            if Buffer.Lang /= null then
               Highlight_Slice (Buffer, Buffer_Start_Iter, Buffer_End_Iter);
            else
               Kill_Highlighting (Buffer, Buffer_Start_Iter, Buffer_End_Iter);
            end if;
         end if;
      end if;
   end Set_Language;

   ------------------
   -- Get_Language --
   ------------------

   function Get_Language
     (Buffer : access Source_Buffer_Record) return Language.Language_Access is
   begin
      return Buffer.Lang;
   end Get_Language;

   -----------------------
   -- Is_Valid_Position --
   -----------------------

   function Is_Valid_Position
     (Buffer : access Source_Buffer_Record;
      Line   : Gint;
      Column : Gint := 0) return Boolean
   is
      Iter : Gtk_Text_Iter;
   begin
      --  First check that Line does not exceed the number of lines
      --  in the buffer.
      if Line >= Get_Line_Count (Buffer) then
         return False;
      end if;

      --  At this point, we know that the line number is valid. If the column
      --  number is 0, then no need to verify the column number as well.
      --  Column 0 always exists and this speeds up the query.
      if Column = 0 then
         return True;
      end if;

      --  Get a text iterator at the begining of the line number Line.
      --  Then, move it to the end of the line to get the number of
      --  characters in this line.
      Get_Iter_At_Line_Offset (Buffer, Iter, Line, 0);
      Forward_To_Line_End (Iter);

      --  Check that Column does not exceed the number of character in
      --  in the current line.
      if Column > Get_Line_Offset (Iter) then
         return False;
      end if;

      --  At this point, we passed all the checks, so the position is licit.
      return True;
   end Is_Valid_Position;

   -------------------------
   -- Set_Cursor_Position --
   -------------------------

   procedure Set_Cursor_Position
     (Buffer  : access Source_Buffer_Record;
      Line    : Gint;
      Column  : Gint)
   is
      Iter : Gtk_Text_Iter;
   begin
      pragma Assert (Is_Valid_Position (Buffer, Line, Column));

      --  At this point, we know that the (Line, Column) position is
      --  valid, so we can safely get the iterator at this position.
      Get_Iter_At_Line_Offset (Buffer, Iter, Line, Column);
      Place_Cursor (Buffer, Iter);
   end Set_Cursor_Position;

   -------------------------
   -- Get_Cursor_Position --
   -------------------------

   procedure Get_Cursor_Position
     (Buffer : access Source_Buffer_Record;
      Line   : out Gint;
      Column : out Gint)
   is
      Insert_Iter : Gtk_Text_Iter;
   begin
      Get_Iter_At_Mark (Buffer, Insert_Iter, Buffer.Insert_Mark);
      Line := Get_Line (Insert_Iter);
      Column := Get_Line_Offset (Insert_Iter);
   end Get_Cursor_Position;

   --------------------------
   -- Get_Selection_Bounds --
   --------------------------

   procedure Get_Selection_Bounds
     (Buffer       : access Source_Buffer_Record;
      Start_Line   : out Gint;
      Start_Column : out Gint;
      End_Line     : out Gint;
      End_Column   : out Gint;
      Found        : out Boolean)
   is
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter;
   begin
      Get_Selection_Bounds (Buffer, Start_Iter, End_Iter, Found);
      if Found then
         Start_Line   := Get_Line (Start_Iter);
         Start_Column := Get_Line_Offset (Start_Iter);
         End_Line     := Get_Line (End_Iter);
         End_Column   := Get_Line_Offset (End_Iter);
      else
         Start_Line   := 0;
         Start_Column := 0;
         End_Line     := 0;
         End_Column   := 0;
      end if;
   end Get_Selection_Bounds;

   -------------------
   -- Get_Selection --
   -------------------

   function Get_Selection
     (Buffer : access Source_Buffer_Record) return String
   is
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter;
      Found      : Boolean;

   begin
      Get_Selection_Bounds (Buffer, Start_Iter, End_Iter, Found);

      if Found then
         return Get_Slice (Buffer, Start_Iter, End_Iter);
      else
         return "";
      end if;
   end Get_Selection;

   ------------
   -- Search --
   ------------

   procedure Search
     (Buffer             : access Source_Buffer_Record;
      Pattern            : String;
      Case_Sensitive     : Boolean := True;
      Whole_Word         : Boolean := False;
      Search_Forward     : Boolean := True;
      From_Line          : Gint := 0;
      From_Column        : Gint := 0;
      Found              : out Boolean;
      Match_Start_Line   : out Gint;
      Match_Start_Column : out Gint;
      Match_End_Line     : out Gint;
      Match_End_Column   : out Gint) is
   begin
      pragma Assert (Is_Valid_Position (Buffer, From_Line, From_Column));

      Found := False;
      Match_Start_Line   := 0;
      Match_Start_Column := 0;
      Match_End_Line     := 0;
      Match_End_Column   := 0;
      --  ??? This function is not implemented yet. Always return false
      --  ??? for the moment.
   end Search;

   ---------------
   -- Get_Slice --
   ---------------

   function Get_Slice
     (Buffer       : access Source_Buffer_Record;
      Start_Line   : Gint;
      Start_Column : Gint;
      End_Line     : Gint;
      End_Column   : Gint) return Gtkada.Types.Chars_Ptr
   is
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter;
   begin
      pragma Assert (Is_Valid_Position (Buffer, Start_Line, Start_Column));
      pragma Assert (Is_Valid_Position (Buffer, End_Line, End_Column));

      Get_Iter_At_Line_Offset (Buffer, Start_Iter, Start_Line, Start_Column);
      Get_Iter_At_Line_Offset (Buffer, End_Iter, End_Line, End_Column);
      return Get_Text (Buffer, Start_Iter, End_Iter);
   end Get_Slice;

   function Get_Slice
     (Buffer       : access Source_Buffer_Record;
      Start_Line   : Gint;
      Start_Column : Gint;
      End_Line     : Gint;
      End_Column   : Gint) return String
   is
      Str : Gtkada.Types.Chars_Ptr :=
        Get_Slice (Buffer, Start_Line, Start_Column, End_Line, End_Column);
      S   : constant String := Value (Str);

   begin
      g_free (Str);
      return S;
   end Get_Slice;

   ------------
   -- Insert --
   ------------

   procedure Insert
     (Buffer  : access Source_Buffer_Record;
      Line    : Gint;
      Column  : Gint;
      Text    : String)
   is
      Iter : Gtk_Text_Iter;
   begin
      pragma Assert (Is_Valid_Position (Buffer, Line, Column));

      Get_Iter_At_Line_Offset (Buffer, Iter, Line, Column);
      Insert (Buffer, Iter, Text);
   end Insert;

   -------------------
   -- Replace_Slice --
   -------------------

   procedure Replace_Slice
     (Buffer       : access Source_Buffer_Record;
      Start_Line   : Gint;
      Start_Column : Gint;
      End_Line     : Gint;
      End_Column   : Gint;
      Text         : String)
   is
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter;
   begin
      pragma Assert (Is_Valid_Position (Buffer, Start_Line, Start_Column));
      pragma Assert (Is_Valid_Position (Buffer, End_Line, End_Column));

      Get_Iter_At_Line_Offset (Buffer, Start_Iter, Start_Line, Start_Column);
      Get_Iter_At_Line_Offset (Buffer, End_Iter, End_Line, End_Column);

      --  Currently, Gtk_Text_Buffer does not export a service to replace
      --  some text, so we delete the slice first, then insert the text...
      Delete (Buffer, Start_Iter, End_Iter);
      Get_Iter_At_Line_Offset (Buffer, Start_Iter, Start_Line, Start_Column);
      Insert (Buffer, Start_Iter, Text);
   end Replace_Slice;

   ------------------
   -- Delete_Slice --
   ------------------

   procedure Delete_Slice
     (Buffer       : access Source_Buffer_Record;
      Start_Line   : Gint;
      Start_Column : Gint;
      End_Line     : Gint;
      End_Column   : Gint)
   is
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter;
   begin
      pragma Assert (Is_Valid_Position (Buffer, Start_Line, Start_Column));
      pragma Assert (Is_Valid_Position (Buffer, End_Line, End_Column));

      Get_Iter_At_Line_Offset (Buffer, Start_Iter, Start_Line, Start_Column);
      Get_Iter_At_Line_Offset (Buffer, End_Iter, End_Line, End_Column);

      Delete (Buffer, Start_Iter, End_Iter);
   end Delete_Slice;

   ----------------
   -- Select_All --
   ----------------

   procedure Select_All (Buffer : access Source_Buffer_Record) is
      Insert_Mark    : constant Gtk_Text_Mark := Get_Insert (Buffer);
      Selection_Mark : constant Gtk_Text_Mark := Get_Selection_Bound (Buffer);
      Start_Iter     : Gtk_Text_Iter;
      End_Iter       : Gtk_Text_Iter;
   begin
      Get_Start_Iter (Buffer, Start_Iter);
      Get_End_Iter (Buffer, End_Iter);
      --  Move the selection_bound mark to the begining of the buffer, and
      --  the insert mark at the end, thus creating the selection on the
      --  entire buffer
      Move_Mark (Buffer, Selection_Mark, Start_Iter);
      Move_Mark (Buffer, Insert_Mark, End_Iter);
   end Select_All;

   --------------------
   -- Highlight_Line --
   --------------------

   procedure Highlight_Line
     (Buffer  : access Source_Buffer_Record;
      Line    : Gint)
   is
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter;
   begin
      pragma Assert (Line < Get_Line_Count (Buffer));

      --  Search for a highlighte line, if any, and unhighlight it.
      Cancel_Highlight_Line (Buffer);

      --  And finally highlight the given line
      Get_Iter_At_Line_Offset (Buffer, Start_Iter, Line, 0);
      Copy (Source => Start_Iter, Dest => End_Iter);
      Forward_To_Line_End (End_Iter);
      Apply_Tag (Buffer, Buffer.HL_Line_Tag, Start_Iter, End_Iter);
   end Highlight_Line;

   ----------------------
   -- Unhighlight_Line --
   ----------------------

   procedure Unhighlight_Line
     (Buffer  : access Source_Buffer_Record;
      Line    : Gint)
   is
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter;
   begin
      pragma Assert (Line < Get_Line_Count (Buffer));

      Get_Iter_At_Line_Offset (Buffer, Start_Iter, Line, 0);
      Copy (Source => Start_Iter, Dest => End_Iter);
      Forward_To_Line_End (End_Iter);
      Remove_Tag (Buffer, Buffer.HL_Line_Tag, Start_Iter, End_Iter);
   end Unhighlight_Line;

   ---------------------------
   -- Cancel_Highlight_Line --
   ---------------------------

   procedure Cancel_Highlight_Line
     (Buffer : access Source_Buffer_Record)
   is
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter;
      Found      : Boolean := True;
   begin
      Get_Start_Iter (Buffer, Start_Iter);
      if not Begins_Tag (Start_Iter, Buffer.HL_Line_Tag) then
         Forward_To_Tag_Toggle (Start_Iter, Buffer.HL_Line_Tag, Found);
      end if;
      if Found then
         Copy (Source => Start_Iter, Dest => End_Iter);
         Forward_To_Line_End (End_Iter);
         Remove_Tag (Buffer, Buffer.HL_Line_Tag, Start_Iter, End_Iter);
      end if;
   end Cancel_Highlight_Line;

   ----------------------
   -- Highlight_Region --
   ----------------------

   procedure Highlight_Region
     (Buffer : access Source_Buffer_Record;
      Start_Line   : Gint;
      Start_Column : Gint;
      End_Line     : Gint;
      End_Column   : Gint)
   is
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter;
   begin
      pragma Assert (Is_Valid_Position (Buffer, Start_Line, Start_Column));
      pragma Assert (Is_Valid_Position (Buffer, End_Line, End_Column));

      Get_Iter_At_Line_Offset (Buffer, Start_Iter, Start_Line, Start_Column);
      Get_Iter_At_Line_Offset (Buffer, End_Iter, End_Line, End_Column);
      Apply_Tag (Buffer, Buffer.HL_Region_Tag, Start_Iter, End_Iter);
   end Highlight_Region;

   ------------------------
   -- Unhighlight_Region --
   ------------------------

   procedure Unhighlight_Region
     (Buffer : access Source_Buffer_Record;
      Start_Line   : Gint;
      Start_Column : Gint;
      End_Line     : Gint;
      End_Column   : Gint)
   is
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter;
   begin
      pragma Assert (Is_Valid_Position (Buffer, Start_Line, Start_Column));
      pragma Assert (Is_Valid_Position (Buffer, End_Line, End_Column));

      Get_Iter_At_Line_Offset (Buffer, Start_Iter, Start_Line, Start_Column);
      Get_Iter_At_Line_Offset (Buffer, End_Iter, End_Line, End_Column);
      Remove_Tag (Buffer, Buffer.HL_Region_Tag, Start_Iter, End_Iter);
   end Unhighlight_Region;

   ---------------------
   -- Unhighlight_All --
   ---------------------

   procedure Unhighlight_All (Buffer : access Source_Buffer_Record)
   is
      Start_Iter : Gtk_Text_Iter;
      End_Iter   : Gtk_Text_Iter;
   begin
      Get_Start_Iter (Buffer, Start_Iter);
      Get_End_Iter (Buffer, End_Iter);
      Remove_Tag (Buffer, Buffer.HL_Region_Tag, Start_Iter, End_Iter);
   end Unhighlight_All;

end Src_Editor_Buffer;
