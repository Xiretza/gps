-----------------------------------------------------------------------
--                 Odd - The Other Display Debugger                  --
--                                                                   --
--                         Copyright (C) 2000                        --
--                 Emmanuel Briot and Arnaud Charlet                 --
--                                                                   --
-- Odd is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this library; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with GNAT.Expect;       use GNAT.Expect;
with GNAT.OS_Lib;       use GNAT.OS_Lib;
with Items;             use Items;
with Process_Proxies;   use Process_Proxies;
with Language;          use Language;
with Language.Debugger; use Language.Debugger;
with Odd.Types;         use Odd.Types;
with Odd.Process;       use Odd.Process;

package body Debugger is

   use String_History;

   Remote_Protocol : constant String := "rsh";
   --  How to run a process on a remote machine ?

   ----------
   -- Free --
   ----------

   procedure Free (Bt : in out Backtrace_Array) is
   begin
      for J in Bt'Range loop
         Free (Bt (J).Program_Counter);
         Free (Bt (J).Subprogram);
         Free (Bt (J).Source_Location);
      end loop;
   end Free;

   ----------------
   -- Parse_Type --
   ----------------

   function Parse_Type
     (Debugger : access Debugger_Root'Class;
      Entity   : String) return Items.Generic_Type_Access
   is
      Result   : Generic_Type_Access;
      Type_Str : String  := Type_Of (Debugger, Entity);
      Index    : Natural := Type_Str'First;

   begin
      if Type_Str'Length /= 0 then
         Parse_Type
           (Language_Debugger_Access (Debugger.The_Language),
            Type_Str, Entity, Index, Result);
      end if;

      return Result;
   end Parse_Type;

   -----------------
   -- Parse_Value --
   -----------------

   procedure Parse_Value
     (Debugger    : access Debugger_Root'Class;
      Entity      : String;
      Value       : in out Items.Generic_Type_Access;
      Value_Found : out Boolean)
   is
      Type_Str   : String := Value_Of (Debugger, Entity);
      Index      : Natural := Type_Str'First;
      Repeat_Num : Positive;

   begin
      Reset_Recursive (Value);
      Value_Found := Type_Str'Length /= 0;
      if Value_Found then
         Parse_Value
           (Language_Debugger_Access (Debugger.The_Language),
            Type_Str, Index, Value, Repeat_Num);
      end if;
   end Parse_Value;

   ------------------
   -- Set_Language --
   ------------------

   procedure Set_Language
     (Debugger     : access Debugger_Root;
      The_Language : Language.Language_Access) is
   begin
      Language.Free (Debugger.The_Language);
      Debugger.The_Language := The_Language;
   end Set_Language;

   ------------------
   -- Get_Language --
   ------------------

   function Get_Language
     (Debugger : access Debugger_Root) return Language.Language_Access is
   begin
      return Debugger.The_Language;
   end Get_Language;

   -----------------
   -- Get_Process --
   -----------------

   function Get_Process
     (Debugger : access Debugger_Root) return Process_Proxy_Access is
   begin
      return Debugger.Process;
   end Get_Process;

   -------------------
   -- General_Spawn --
   -------------------

   procedure General_Spawn
     (Debugger       : access Debugger_Root'Class;
      Arguments      : GNAT.OS_Lib.Argument_List;
      Debugger_Name  : String;
      Proxy          : Process_Proxies.Process_Proxy_Access;
      Remote_Machine : String := "")
   is
      Descriptor : Process_Descriptor_Access;
   begin
      --  Start the external debugger.
      --  Note that there is no limitation on the buffer size, since we can
      --  not control the length of what gdb will return...

      Debugger.Process := Proxy;

      if Remote_Machine = "" then
         Descriptor := new Process_Descriptor'
           (Non_Blocking_Spawn
             (Debugger_Name, Arguments,
              Buffer_Size => 0,
              Err_To_Out => True));
      else
         declare
            Real_Arguments : Argument_List (1 .. Arguments'Length + 2);
         begin
            Real_Arguments (1) := new String'(Remote_Machine);
            Real_Arguments (2) := new String'(Debugger_Name);
            Real_Arguments (3 .. Real_Arguments'Last) := Arguments;

            Descriptor := new Process_Descriptor'
              (Non_Blocking_Spawn
                (Remote_Protocol,
                 Real_Arguments,
                 Buffer_Size => 0,
                 Err_To_Out => True));
            Free (Real_Arguments (1));
            Free (Real_Arguments (2));
         end;
      end if;

      if Get_Pid (Descriptor.all) = GNAT.Expect.Invalid_Pid then
         raise Spawn_Error;
      end if;

      Set_Descriptor (Debugger.Process, Descriptor);
   end General_Spawn;

   ---------------------
   -- Found_File_Name --
   ---------------------

   procedure Found_File_Name
     (Debugger    : access Debugger_Root;
      Str         : String;
      Name_First  : out Natural;
      Name_Last   : out Positive;
      First, Last : out Natural;
      Line        : out Natural) is
   begin
      First      := 0;
      Last       := 0;
      Name_First := 0;
      Name_Last  := 1;
      Line       := 0;
   end Found_File_Name;

   -----------------
   -- Get_Uniq_Id --
   -----------------

   function Get_Uniq_Id
     (Debugger : access Debugger_Root;
      Entity   : String)
     return String
   is
   begin
      return Entity;
   end Get_Uniq_Id;

   -------------------
   -- Thread_Switch --
   -------------------

   procedure Thread_Switch
     (Debugger : access Debugger_Root'Class;
      Thread   : Natural) is
   begin
      Send (Debugger, Thread_Switch (Get_Language (Debugger), Thread));
   end Thread_Switch;

   -----------------------
   -- Source_Files_List --
   -----------------------

   function Source_Files_List (Debugger : access Debugger_Root)
                              return Odd.Types.String_Array
   is
      A : Odd.Types.String_Array (1 .. 0);
   begin
      return A;
   end Source_Files_List;

   ----------
   -- Send --
   ----------

   procedure Send
     (Debugger         : access Debugger_Root'Class;
      Cmd              : String;
      Display          : Boolean := False;
      Empty_Buffer     : Boolean := True;
      Wait_For_Prompt  : Boolean := True) is
   begin
      if Display then
         Text_Output_Handler
           (Convert (Debugger.Window, Debugger),
            Cmd & ASCII.LF, True);
         Append (Convert (Debugger.Window, Debugger).Command_History, Cmd);
      end if;

      Send (Get_Process (Debugger), Cmd, Empty_Buffer);
      Send_Completed (Debugger, Cmd);

      if Wait_For_Prompt then
         Wait_Prompt (Debugger);

         --  Postprocessing (e.g handling of auto-update).

         if Is_Context_Command (Debugger, Cmd) then
            Context_Changed (Convert (Debugger.Window, Debugger));
         elsif Is_Execution_Command (Debugger, Cmd) then
            Process_Stopped (Convert (Debugger.Window, Debugger));

         --  Should we update the list of breakpoints => No if we are in
         --  an internal command, since that would be too costly
         elsif Is_Break_Command (Debugger, Cmd)
           and then not Is_Internal_Command (Get_Process (Debugger)) then
            Update_Breakpoints (Convert (Debugger.Window, Debugger));
         end if;
      end if;
   end Send;

   --------------------
   -- Send_Completed --
   --------------------

   procedure Send_Completed
     (Debugger : access Debugger_Root;
      Cmd      : String) is
   begin
      null;
   end Send_Completed;

   ------------------------------
   -- Variable_Name_With_Frame --
   ------------------------------

   function Variable_Name_With_Frame
     (Debugger : access Debugger_Root;
      Var      : String)
     return String
   is
   begin
      return Var;
   end Variable_Name_With_Frame;

   ---------------------
   -- List_Exceptions --
   ---------------------

   function List_Exceptions
     (Debugger : access Debugger_Root)
     return Odd.Types.Exception_Array
   is
      Arr : Exception_Array (1 .. 0);
   begin
      return Arr;
   end List_Exceptions;

end Debugger;
