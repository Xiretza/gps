-----------------------------------------------------------------------
--                   GVD - The GNU Visual Debugger                   --
--                                                                   --
--                      Copyright (C) 2000-2004                      --
--                              ACT-Europe                           --
--                                                                   --
-- GVD is free  software;  you can redistribute it and/or modify  it --
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

with GVD.Main_Window; use GVD.Main_Window;
with GVD.Types;       use GVD.Types;
with Process_Proxies; use Process_Proxies;
with Debugger;        use Debugger;
with System;
with Ada.Unchecked_Conversion;
with Traces;          use Traces;

package body GVD.Trace is

   --  Internally, we only handle two different handles, since it makes things
   --  much simpler to activate, and anyway we either want the minimal or all
   --  of it anyway
   Me : constant array (Command_Type) of Debug_Handle :=
     (Internal => Create ("GVD.Out", Off),   --  Could be "Internal"
      Hidden   => Create ("GVD.Out", Off),   --  Could be "Hidden"
      Visible  => Create ("GVD.Out", Off),   --  Could be "Visible"
      User     => Create ("GVD.Out", Off));  --  Could be "User"

   Direction_String : constant array (IO_Kind) of String (1 .. 4) :=
     (Input_Kind  => "-> """,
      Output_Kind => "<- """);

   pragma Warnings (Off);
   --  This UC is safe aliasing-wise, so kill warning
   function To_Main_Window is new
     Ada.Unchecked_Conversion (System.Address, GVD_Main_Window);
   pragma Warnings (On);

   ------------------
   -- Output_Error --
   ------------------

   procedure Output_Error (Str : String) is
   begin
      Output_Line ("# " & Str);
      if Global_Output /= null then
         Output (Global_Output.all, Str, Error => True);
      end if;
   end Output_Error;

   -----------------
   -- Output_Line --
   -----------------

   procedure Output_Line (Str : String) is
   begin
      Traces.Trace (Me (User), Str);
   end Output_Line;

   -----------------
   -- Output_Info --
   -----------------

   procedure Output_Info (Str : String) is
   begin
      Output_Line ("% " & Str);
      if Global_Output /= null then
         Output (Global_Output.all, Str, Error => False);
      end if;
   end Output_Info;

   --------------------
   -- Output_Message --
   --------------------

   procedure Output_Message
     (Process : Visual_Debugger;
      Str     : String;
      Mode    : Command_Type;
      Kind    : IO_Kind := Input_Kind)
   is
      Num  : constant String := Integer'Image (Process.Debugger_Num);
      Output : String (1 .. Str'Length * 2);
      pragma Warnings (Off, Output);
      Index  : Natural := Output'First;
      Prefix : constant String := '[' & Num (2 .. Num'Last) & "] ";
      Had_Output : Boolean := False;

   begin
      for J in Str'Range loop
         case Str (J) is
            when ASCII.LF =>
               if not Had_Output then
                  Traces.Trace (Me (Mode), Prefix
                         & Direction_String (Kind)
                         & Output (Output'First .. Index - 1)
                         & '"');
                  Had_Output := True;
               else
                  Traces.Trace (Me (Mode), Prefix & "..."
                         & Direction_String (Kind)
                         & Output (Output'First .. Index - 1)
                         & '"');
               end if;
               Index := Output'First;
            when ASCII.CR =>
               Output (Index)     := '\';
               Output (Index + 1) := 'r';
               Index := Index + 2;
            when ASCII.HT =>
               Output (Index)     := '\';
               Output (Index + 1) := 't';
               Index := Index + 2;
            when others =>
               Output (Index) := Str (J);
               Index := Index + 1;
         end case;
      end loop;

      if Index > Output'First then
         if not Had_Output then
            Traces.Trace (Me (Mode), Prefix
                   & Direction_String (Kind)
                   & Output (Output'First .. Index - 1)
                   & '"');
         else
            Traces.Trace (Me (Mode), Prefix & "..."
                   & Direction_String (Kind)
                   & Output (Output'First .. Index - 1)
                   & '"');
         end if;
      end if;
   end Output_Message;

   ------------------
   -- Input_Filter --
   ------------------

   procedure Input_Filter
     (Descriptor : Process_Descriptor'Class;
      Str        : String;
      User_Data  : System.Address := System.Null_Address)
   is
      Window : constant GVD_Main_Window := To_Main_Window (User_Data);
   begin
      declare
         Tab : constant Visual_Debugger := Convert (Window, Descriptor);
      begin
         Output_Message
           (Tab, Str,
            Get_Command_Mode (Get_Process (Tab.Debugger)), Input_Kind);
      exception
         when Debugger_Not_Found => null;
      end;
   end Input_Filter;

   -------------------
   -- Output_Filter --
   -------------------

   procedure Output_Filter
     (Descriptor : Process_Descriptor'Class;
      Str        : String;
      User_Data  : System.Address := System.Null_Address)
   is
      Window : constant GVD_Main_Window := To_Main_Window (User_Data);
   begin
      declare
         Tab : constant Visual_Debugger := Convert (Window, Descriptor);
      begin
         Output_Message
           (Tab, Str,
            Get_Command_Mode (Get_Process (Tab.Debugger)), Output_Kind);
      exception
         when Debugger_Not_Found => null;
      end;
   end Output_Filter;

end GVD.Trace;
