-----------------------------------------------------------------------
--                              G P S                                --
--                                                                   --
--                     Copyright (C) 2000-2005                       --
--                             AdaCore                               --
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

with Glib;                  use Glib;
with Gtk;                   use Gtk;
with Gtk.Accel_Group;       use Gtk.Accel_Group;
with Gtk.Box;               use Gtk.Box;
with Gtk.Menu_Bar;          use Gtk.Menu_Bar;
with Gtk.Menu_Item;         use Gtk.Menu_Item;
with Gtk.Object;            use Gtk.Object;
with Gtk.Widget;            use Gtk.Widget;
with Gtkada.Handlers;       use Gtkada.Handlers;
with Gtkada.Types;

with Breakpoints_Editor;    use Breakpoints_Editor;
with Factory_Data;
with GVD.Dialogs;           use GVD.Dialogs;
with GVD.Types;             use GVD.Types;
with GVD.Process;           use GVD.Process;
with Debugger;              use Debugger;
with Process_Proxies;       use Process_Proxies;
with Glide_Intl;            use Glide_Intl;

with Interfaces.C.Strings;  use Interfaces.C.Strings;

package body GVD.Main_Window is

   Signals : constant Gtkada.Types.Chars_Ptr_Array :=
     (1 => New_String ("preferences_changed"));
   Class_Record : GObject_Class := Uninitialized_Class;

   procedure On_Destroy (Window : access Gtk_Widget_Record'Class);
   --  Callback for the "destroy" dialog

   -------------------------------
   -- Prepare_Cleanup_Debuggers --
   -------------------------------

   procedure Prepare_Cleanup_Debuggers
     (Window : access GVD_Main_Window_Record'Class)
   is
      Debugger : Visual_Debugger;
      List     : Debugger_List_Link := Window.First_Debugger;

   begin
      while List /= null loop
         Debugger := Visual_Debugger (List.Debugger);

         if Debugger.Debugger /= null
           and then Command_In_Process (Get_Process (Debugger.Debugger))
         then
            Interrupt (Debugger.Debugger);
         end if;

         List := List.Next;
      end loop;
   end Prepare_Cleanup_Debuggers;

   -----------------------
   -- Cleanup_Debuggers --
   -----------------------

   procedure Cleanup_Debuggers
     (Window : access GVD_Main_Window_Record'Class)
   is
      Debugger : Visual_Debugger;
      List     : Debugger_List_Link := Window.First_Debugger;

   begin
      while List /= null loop
         Debugger := Visual_Debugger (List.Debugger);
         Debugger.Exiting := True;
         Window.Current_Debugger := Glib.Object.GObject (Debugger);

         if Debugger.Debugger /= null then
            begin
               Close (Debugger.Debugger);
            exception
               when others =>
                  --  ??? Would be nice to handle more specific errors, but
                  --  since we are exiting, ignore any exception instead of
                  --  generating unfriendly bug boxes
                  null;
            end;
         end if;

         List := List.Next;
      end loop;

      Window.Current_Debugger := null;
      Free (Window.Command_History);
   end Cleanup_Debuggers;

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Main_Window : out GVD_Main_Window;
      Key         : String;
      Menu_Items  : Gtk_Item_Factory_Entry_Array) is
   begin
      Main_Window := new GVD_Main_Window_Record;
      GVD.Main_Window.Initialize (Main_Window, Key, Menu_Items);
   end Gtk_New;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Main_Window : access GVD_Main_Window_Record'Class;
      Key         : String;
      Menu_Items  : Gtk_Item_Factory_Entry_Array)
   is
      Menu : Gtk_Widget;
   begin
      Main_Debug_Window_Pkg.Initialize (Main_Window);
      Initialize_Class_Record
        (Main_Window, Signals, Class_Record, Type_Name => "GvdMainWindow");

      Gtk_New (Main_Window.Main_Accel_Group);
      Add_Accel_Group (Main_Window, Main_Window.Main_Accel_Group);
      Gtk_New (Main_Window.Process_Mdi, Main_Window.Main_Accel_Group);
      Add (Main_Window.Vbox, Main_Window.Process_Mdi);
      Gtk_New
        (Main_Window.Factory, Gtk.Menu_Bar.Get_Type,
         Key, Main_Window.Main_Accel_Group);
      Factory_Data.Create_Items
        (Main_Window.Factory, Menu_Items, Main_Window.all'Access);
      Menu := Get_Widget (Main_Window.Factory, Key);
      Main_Window.Menu_Bar := Gtk_Menu_Bar (Menu);
      Gtk_New_Hbox (Main_Window.Menu_Box, False, 0);
      Pack_Start (Main_Window.Vbox, Main_Window.Menu_Box, False, False);
      Pack_Start (Main_Window.Menu_Box, Menu);
      Reorder_Child (Main_Window.Vbox, Main_Window.Menu_Box, 0);
      Set_Submenu
        (Gtk_Menu_Item (Get_Widget (Main_Window.Factory, '/' & (-"Window"))),
         Create_Menu (Main_Window.Process_Mdi));

      Widget_Callback.Connect
        (Main_Window, "destroy",
         Widget_Callback.To_Marshaller (On_Destroy'Access));
   end Initialize;

   ----------------
   -- On_Destroy --
   ----------------

   procedure On_Destroy (Window : access Gtk_Widget_Record'Class) is
      Win : constant GVD_Main_Window := GVD_Main_Window (Window);
   begin
      Unref (Win.Factory);

      if Win.Task_Dialog /= null then
         Destroy (Win.Task_Dialog);
      end if;

      if Win.Thread_Dialog /= null then
         Destroy (Win.Thread_Dialog);
      end if;

      if Win.PD_Dialog /= null then
         Destroy (Win.PD_Dialog);
      end if;

      if Win.History_Dialog /= null then
         Destroy (Win.History_Dialog);
      end if;

      if Win.Memory_View /= null then
         Destroy (Win.Memory_View);
      end if;
   end On_Destroy;

   -----------------
   -- Set_Toolbar --
   -----------------

   procedure Set_Toolbar
     (Main_Window : access GVD_Main_Window_Record'Class;
      Toolbar     : access Gtk_Widget_Record'Class)
   is
      Box : Gtk_Hbox;
   begin
      Gtk_New_Hbox (Box, False, 0);
      Pack_Start (Main_Window.Toolbar_Box, Box, False, False);
      Pack_Start (Box, Toolbar, False, False);
      Show_All (Box);
   end Set_Toolbar;

   -----------------------------
   -- Update_External_Dialogs --
   -----------------------------

   procedure Update_External_Dialogs
     (Window   : access GVD_Main_Window_Record'Class;
      Debugger : Glib.Object.GObject := null)
   is
      use type Glib.Object.GObject;

      Tab : Visual_Debugger := Visual_Debugger (Debugger);

   begin
      if Debugger = null then
         Tab := Get_Current_Process (Window);
      end if;

      if Tab /= null
        and then Tab.Debugger /= null
        and then not Command_In_Process (Get_Process (Tab.Debugger))
      then
         if Window.Thread_Dialog /= null then
            Update (Thread_Dialog_Access (Window.Thread_Dialog), Tab);
         end if;

         if Window.Task_Dialog /= null then
            Update (Task_Dialog_Access (Window.Task_Dialog), Tab);
         end if;

         if Window.History_Dialog /= null then
            Update (History_Dialog_Access (Window.History_Dialog), Tab);
         end if;

         if Window.PD_Dialog /= null then
            Update (PD_Dialog_Access (Window.PD_Dialog), Tab);
         end if;
      end if;
   end Update_External_Dialogs;

   ----------------
   -- Find_Match --
   ----------------

   procedure Find_Match
     (H   : in out History_List;
      Num : in Natural;
      D   : in Direction)
   is
      Data    : GNAT.OS_Lib.String_Access;
      Current : History_Data;
   begin
      begin
         Data := Get_Current (H).Command;
      exception
         when No_Such_Item =>
            Data := null;
      end;

      loop
         if D = Backward then
            Move_To_Previous (H);
         else
            Move_To_Next (H);
         end if;

         Current := Get_Current (H);

         exit when Current.Debugger_Num = Num
           and then Current.Mode /= Hidden
           and then (Data = null
                     or else Current.Command.all /= Data.all);
      end loop;
   end Find_Match;

   -------------------------
   -- Preferences_Changed --
   -------------------------

   procedure Preferences_Changed
     (Window : access GVD_Main_Window_Record'Class)
   is
   begin
      Widget_Callback.Emit_By_Name
        (Gtk_Widget (Window), "preferences_changed");
   end Preferences_Changed;

   ---------------------
   -- Switch_Debugger --
   ---------------------

   procedure Switch_Debugger
     (Window   : access GVD_Main_Window_Record'Class;
      Debugger : Glib.Object.GObject)
   is
      Process     : constant Visual_Debugger := Visual_Debugger (Debugger);
      Widget      : Gtk_Widget;
      WTX_Version : Natural;

      use type Glib.Object.GObject;

   begin
      if Window.Current_Debugger = Debugger then
         return;
      end if;

      Window.Current_Debugger := Debugger;

      if Process.Debugger = null then
         return;
      end if;

      Update_External_Dialogs (Window, Debugger);

      if Window.Breakpoints_Editor /= null then
         Set_Process
           (Breakpoint_Editor_Access (Window.Breakpoints_Editor), Process);
      end if;

      --  ??? Replace by a signal "debugger_switch" on the main window
      --  Do not call Executable_Changed if the debugger is busy, since
      --  this would generate an assert failure, trying to send commands to
      --  the gdb while the debugger is already handling a command.
      --  This test should also go when we use a debugger_switch signal.

      if not Command_In_Process (Get_Process (Process.Debugger)) then
         Executable_Changed (Process, "");
      end if;

      --  Update the sensitivity of the Data/Protection Domains menu
      --  item

      Widget := Get_Widget (Window.Factory, -"/Debug/Data/Protection Domains");

      if Widget /= null then
         Info_WTX (Process.Debugger, WTX_Version);

         if WTX_Version /= 3 then
            Set_Sensitive (Widget, False);
         else
            Set_Sensitive (Widget, True);
         end if;
      end if;
   end Switch_Debugger;

end GVD.Main_Window;
