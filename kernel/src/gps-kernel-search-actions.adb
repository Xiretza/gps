------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2013-2015, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNAT.Strings;        use GNAT.Strings;
with GPS.Kernel.Actions;  use GPS.Kernel.Actions;
with GPS.Search;          use GPS.Search;
with Gtk.Enums;           use Gtk.Enums;
with Gtk.Text_Buffer;     use Gtk.Text_Buffer;
with Gtk.Text_Iter;       use Gtk.Text_Iter;
with Gtk.Text_Tag;        use Gtk.Text_Tag;
with Gtk.Text_View;       use Gtk.Text_View;
with Pango.Enums;         use Pango.Enums;

package body GPS.Kernel.Search.Actions is

   -------------------
   -- Documentation --
   -------------------

   overriding function Documentation
     (Self    : not null access Actions_Search_Provider) return String
   is
      pragma Unreferenced (Self);
   begin
      return "Search amongst the GPS commands, and execute the selected one";
   end Documentation;

   -----------------
   -- Set_Pattern --
   -----------------

   overriding procedure Set_Pattern
     (Self    : not null access Actions_Search_Provider;
      Pattern : not null access GPS.Search.Search_Pattern'Class;
      Limit   : Natural := Natural'Last)
   is
      pragma Unreferenced (Limit);
   begin
      Self.Pattern := Search_Pattern_Access (Pattern);
      Self.Iter := Start (Self.Kernel);
   end Set_Pattern;

   ----------
   -- Next --
   ----------

   overriding procedure Next
     (Self     : not null access Actions_Search_Provider;
      Result   : out GPS.Search.Search_Result_Access;
      Has_Next : out Boolean)
   is
      Action : constant Action_Record_Access := Get (Self.Iter);
      C      : Search_Context;
      S      : GNAT.Strings.String_Access;
   begin
      Result := null;

      if Action /= null then

         --  Do not complete on menu names
         if Action.Name (Action.Name'First) /= '/' then
            C := Self.Pattern.Start (Action.Name.all);
            if C /= GPS.Search.No_Match then
               S := new String'
                  (Self.Pattern.Highlight_Match
                     (Action.Name.all, Context => C));
               Result := new Actions_Search_Result'
                 (Kernel   => Self.Kernel,
                  Provider => Self,
                  Score    => C.Score,
                  Short    => S,
                  Long     => null,
                  Id       => S,
                  Name     => new String'(Action.Name.all));

               Self.Adjust_Score (Result);
            end if;
         end if;

         Has_Next := True;
         Next (Self.Kernel, Self.Iter);
      else
         Has_Next := False;
      end if;
   end Next;

   ---------------------
   -- Complete_Suffix --
   ---------------------

   overriding function Complete_Suffix
     (Self      : not null access Actions_Search_Provider;
      Pattern   : not null access GPS.Search.Search_Pattern'Class)
      return String
   is
      Suffix      : Unbounded_String;
      Suffix_Last : Natural := 0;
      Action      : Action_Record_Access;
      C           : Search_Context;
   begin
      Self.Set_Pattern (Pattern);

      loop
         Action := Get (Self.Iter);
         exit when Action = null;

         --  Do not complete on menu names
         if Action.Name (Action.Name'First) /= '/' then
            C := Self.Pattern.Start (Action.Name.all);
            if C /= GPS.Search.No_Match then
               Self.Pattern.Compute_Suffix
                 (C, Action.Name.all, Suffix, Suffix_Last);
               exit when Suffix_Last = 0;
            end if;
         end if;

         Next (Self.Kernel, Self.Iter);
      end loop;

      return Slice (Suffix, 1, Suffix_Last);
   end Complete_Suffix;

   ----------
   -- Free --
   ----------

   overriding procedure Free (Self : in out Actions_Search_Result) is
   begin
      GNAT.Strings.Free (Self.Name);
      Free (Kernel_Search_Result (Self));
   end Free;

   -------------
   -- Execute --
   -------------

   overriding procedure Execute
     (Self       : not null access Actions_Search_Result;
      Give_Focus : Boolean)
   is
      Dummy : Boolean;
      pragma Unreferenced (Dummy, Give_Focus);
   begin
      Dummy := Execute_In_Background (Self.Kernel, Self.Name.all);
   end Execute;

   ----------
   -- Full --
   ----------

   overriding function Full
     (Self : not null access Actions_Search_Result)
     return Gtk.Widget.Gtk_Widget
   is
      Action : constant Action_Record_Access :=
         Lookup_Action (Self.Kernel, Self.Name.all);
      View : Gtk_Text_View;
      Buffer : Gtk_Text_Buffer;
      Underline : Gtk_Text_Tag;
      Bold      : Gtk_Text_Tag;
      Iter   : Gtk_Text_Iter;
   begin
      if Action /= null and then Action.Description /= null then
         Gtk_New (Buffer);
         Gtk_New (View, Buffer);
         Unref (Buffer);

         View.Set_Editable (False);
         View.Set_Wrap_Mode (Wrap_Word);

         Bold := Buffer.Create_Tag;
         Set_Property (Bold, Gtk.Text_Tag.Weight_Property, Pango_Weight_Bold);

         Underline := Buffer.Create_Tag;
         Set_Property
            (Underline, Gtk.Text_Tag.Weight_Property, Pango_Weight_Bold);
         Set_Property
            (Underline, Gtk.Text_Tag.Underline_Property,
             Pango_Underline_Single);

         Buffer.Get_End_Iter (Iter);
         Buffer.Insert_With_Tags
            (Iter, Action.Name.all & ASCII.LF & ASCII.LF, Underline);

         Buffer.Insert (Iter, Action.Description.all);

         return Gtk.Widget.Gtk_Widget (View);
      end if;
      return null;
   end Full;

end GPS.Kernel.Search.Actions;
