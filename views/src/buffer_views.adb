------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2005-2013, AdaCore                     --
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

with Glib;                   use Glib;
with Glib.Convert;           use Glib.Convert;
with Glib.Object;            use Glib.Object;
with Gdk.Event;              use Gdk.Event;
with Gdk.Pixbuf;             use Gdk.Pixbuf;
with Gdk.Rectangle;          use Gdk.Rectangle;
with Gdk.Types;              use Gdk.Types;
with Gtk.Box;                use Gtk.Box;
with Gtk.Check_Menu_Item;    use Gtk.Check_Menu_Item;
with Gtk.Enums;              use Gtk.Enums;
with Gtk.Handlers;           use Gtk.Handlers;
with Gtk.Label;              use Gtk.Label;
with Gtk.Menu;               use Gtk.Menu;
with Gtk.Notebook;           use Gtk.Notebook;
with Gtk.Scrolled_Window;    use Gtk.Scrolled_Window;
with Gtk.Stock;              use Gtk.Stock;
with Gtk.Tree_View;          use Gtk.Tree_View;
with Gtk.Tree_View_Column;   use Gtk.Tree_View_Column;
with Gtk.Tree_Selection;     use Gtk.Tree_Selection;
with Gtk.Tree_Store;         use Gtk.Tree_Store;
with Gtk.Tree_Model;         use Gtk.Tree_Model;
with Gtk.Widget;             use Gtk.Widget;
with Gtkada.Handlers;        use Gtkada.Handlers;
with Gtkada.MDI;             use Gtkada.MDI;

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Default_Preferences;    use Default_Preferences;
with Generic_Views;
with GPS.Kernel;             use GPS.Kernel;
with GPS.Kernel.Actions;     use GPS.Kernel.Actions;
with GPS.Kernel.Hooks;       use GPS.Kernel.Hooks;
with GPS.Kernel.MDI;         use GPS.Kernel.MDI;
with GPS.Kernel.Modules;     use GPS.Kernel.Modules;
with GPS.Kernel.Modules.UI;  use GPS.Kernel.Modules.UI;
with GPS.Kernel.Preferences; use GPS.Kernel.Preferences;
with GPS.Kernel.Standard_Hooks; use GPS.Kernel.Standard_Hooks;
with GPS.Kernel.Search;      use GPS.Kernel.Search;
with GPS.Intl;               use GPS.Intl;
with GPS.Search;             use GPS.Search;
with Histories;              use Histories;
with GUI_Utils;              use GUI_Utils;
with Src_Editor_Module;      use Src_Editor_Module;
with GNAT.Strings;           use GNAT.Strings;
with GNATCOLL.Traces;        use GNATCOLL.Traces;
with GNATCOLL.VFS;           use GNATCOLL.VFS;
with Tooltips;               use Tooltips;
with Commands.Interactive;   use Commands, Commands.Interactive;

package body Buffer_Views is
   Me : constant Trace_Handle := Create ("BUFFERS");

   Icon_Column : constant := 0;
   Name_Column : constant := 1;
   Data_Column : constant := 2;

   Untitled    : constant String := "Untitled";
   --  Label used for new window that is not yet saved

   History_Editors_Only : constant History_Key :=
     "Windows_View_Editors_Only";
   --  Used to store the current filter settings in histories

   History_Show_Notebooks : constant History_Key :=
     "Windows_View_Show_Notebooks";
   --  Used to store the current view settings in histories

   type Buffer_View_Record is new Generic_Views.View_Record with record
      Tree              : Gtk_Tree_View;
      File              : Virtual_File; -- current selected file (cache)
      Child_Selected_Id : Gtk.Handlers.Handler_Id;
   end record;
   overriding procedure Create_Menu
     (View    : not null access Buffer_View_Record;
      Menu    : not null access Gtk.Menu.Gtk_Menu_Record'Class);

   function Initialize
     (View   : access Buffer_View_Record'Class) return Gtk_Widget;
   --  Create a new Buffer view

   Module_Name : constant String := "Windows_View";

   package Generic_View is new Generic_Views.Simple_Views
     (Module_Name        => Module_Name,
      View_Name          => "Windows",
      Reuse_If_Exist     => True,
      Local_Toolbar      => True,
      Local_Config       => True,
      Formal_MDI_Child   => GPS_MDI_Child_Record,
      Formal_View_Record => Buffer_View_Record,
      Areas              => Gtkada.MDI.Sides_Only);
   use Generic_View;
   subtype Buffer_View_Access is Generic_View.View_Access;

   procedure Child_Selected (View : access Gtk_Widget_Record'Class);
   --  Called when a new child is selected

   procedure Preferences_Changed
     (Kernel : access Kernel_Handle_Record'Class;
      Data   : access Hooks_Data'Class);
   --  Called when the preferences change

   procedure Refresh (View : access Gtk_Widget_Record'Class);
   --  Refresh the contents of the Buffer view

   function Button_Press
     (View  : access GObject_Record'Class;
      Event : Gdk_Event_Button) return Boolean;
   --  Callback for the "button_press" event

   function Get_Path_At_Event
     (Tree  : Gtk_Tree_View;
      Event : Gdk_Event_Button) return Gtk_Tree_Path;
   --  Return the path at which Event has occured.
   --  User must free memory associated to the returned path.

   type Close_Command is new Interactive_Command with null record;
   overriding function Execute
     (Command : access Close_Command;
      Context : Interactive_Command_Context) return Command_Return_Type;
   --  Close the selected editors

   procedure View_Context_Factory
     (Context      : in out Selection_Context;
      Kernel       : access Kernel_Handle_Record'Class;
      Event_Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Object       : access Glib.Object.GObject_Record'Class;
      Event        : Gdk.Event.Gdk_Event;
      Menu         : Gtk.Menu.Gtk_Menu);
   --  Context factory when creating contextual menus

   ---------------
   -- Searching --
   ---------------

   type Opened_Windows_Search is new Kernel_Search_Provider with record
      Pattern : Search_Pattern_Access;
      Iter    : Child_Iterator;
   end record;
   type Opened_Windows_Search_Access is
      access all Opened_Windows_Search'Class;
   overriding procedure Set_Pattern
      (Self     : not null access Opened_Windows_Search;
       Pattern  : not null access GPS.Search.Search_Pattern'Class;
       Limit    : Natural := Natural'Last);
   overriding procedure Next
      (Self     : not null access Opened_Windows_Search;
       Result   : out GPS.Search.Search_Result_Access;
       Has_Next : out Boolean);
   overriding function Display_Name
      (Self     : not null access Opened_Windows_Search) return String
      is (Provider_Opened_Win);
   overriding function Documentation
      (Self     : not null access Opened_Windows_Search) return String;
   overriding function Complete_Suffix
     (Self      : not null access Opened_Windows_Search;
      Pattern   : not null access GPS.Search.Search_Pattern'Class)
      return String;

   type Opened_Windows_Result is new Kernel_Search_Result with null record;
   overriding procedure Execute
      (Self       : not null access Opened_Windows_Result;
       Give_Focus : Boolean);
   overriding function Full
      (Self       : not null access Opened_Windows_Result) return Gtk_Widget;

   --------------
   -- Tooltips --
   --------------

   type Buffer_View_Tooltips is new Tooltips.Tooltips with null record;
   overriding function Create_Contents
     (Tooltip  : not null access Buffer_View_Tooltips;
      Widget   : not null access Gtk.Widget.Gtk_Widget_Record'Class;
      X, Y     : Glib.Gint) return Gtk.Widget.Gtk_Widget;

   ---------------------
   -- Create_Contents --
   ---------------------

   overriding function Create_Contents
     (Tooltip  : not null access Buffer_View_Tooltips;
      Widget   : not null access Gtk.Widget.Gtk_Widget_Record'Class;
      X, Y     : Glib.Gint) return Gtk.Widget.Gtk_Widget
   is
      Tree  : constant Gtk_Tree_View := Gtk_Tree_View (Widget);
      Model : constant Gtk_Tree_Model := Get_Model (Tree);
      Iter  : Gtk_Tree_Iter;
      Area  : Gdk_Rectangle;
      Label : Gtk_Label;

   begin
      Initialize_Tooltips (Tree, X, Y, Area, Iter);

      if Iter /= Null_Iter then
         Tooltip.Set_Tip_Area (Area);

         declare
            Name : constant String :=
              Get_String (Model, Iter, Name_Column);
            Title : constant String :=
              Get_String (Model, Iter, Data_Column);
         begin
            Gtk_New
              (Label, "<b>Name:</b> "
               & Escape_Text (Name) & ASCII.LF
               & "<b>Title:</b> " & Escape_Text (Title));
            Label.Set_Use_Markup (True);
         end;
      end if;

      return Gtk_Widget (Label);
   end Create_Contents;

   -------------
   -- Execute --
   -------------

   overriding function Execute
     (Command : access Close_Command;
      Context : Interactive_Command_Context) return Command_Return_Type
   is
      pragma Unreferenced (Command);
      Kernel      : constant Kernel_Handle := Get_Kernel (Context.Context);
      View        : constant Buffer_View_Access :=
        Generic_View.Retrieve_View (Kernel);
      Model       : Gtk_Tree_Store;
      Child       : MDI_Child;
      Iter, Iter2 : Gtk_Tree_Iter;
      Count       : Natural := 0;
      CIter       : Child_Iterator := First_Child (Get_MDI (Kernel));
   begin
      if View = null then
         return Commands.Failure;
      end if;

      Model := -Get_Model (View.Tree);

      while Get (CIter) /= null loop
         Count := Count + 1;
         Next (CIter);
      end loop;

      declare
         Children : MDI_Child_Array (1 .. Count);
      begin
         Count := Children'First;

         Iter := Get_Iter_First (Get_Model (View.Tree));
         while Iter /= Null_Iter loop
            Iter2 := Gtk.Tree_Store.Children (Model, Iter);
            while Iter2 /= Null_Iter loop
               if Iter_Is_Selected (Get_Selection (View.Tree), Iter2) then
                  Child := Find_MDI_Child_By_Name
                    (Get_MDI (Kernel), Get_String (Model, Iter2, Data_Column));
                  if Child /= null then
                     Children (Count) := Child;
                     Count := Count + 1;
                  end if;
               end if;

               Next (Model, Iter2);
            end loop;

            if Iter_Is_Selected (Get_Selection (View.Tree), Iter) then
               Child := Find_MDI_Child_By_Name
                 (Get_MDI (Kernel), Get_String (Model, Iter, Data_Column));
               if Child /= null then
                  Children (Count) := Child;
                  Count := Count + 1;
               end if;
            end if;

            Next (Model, Iter);
         end loop;

         for C in Children'Range loop
            if Children (C) /= null then
               Close_Child (Children (C));
            end if;
         end loop;
      end;

      return Success;
   end Execute;

   -----------------------
   -- Get_Path_At_Event --
   -----------------------

   function Get_Path_At_Event
     (Tree  : Gtk_Tree_View;
      Event : Gdk_Event_Button) return Gtk_Tree_Path
   is
      Buffer_X  : Gint;
      Buffer_Y  : Gint;
      Row_Found : Boolean;
      Path      : Gtk_Tree_Path;
      Column    : Gtk_Tree_View_Column := null;
   begin
      Get_Path_At_Pos
        (Tree, Gint (Event.X), Gint (Event.Y),
         Path, Column, Buffer_X, Buffer_Y, Row_Found);
      return Path;
   end Get_Path_At_Event;

   ------------------
   -- Button_Press --
   ------------------

   function Button_Press
     (View  : access GObject_Record'Class;
      Event : Gdk_Event_Button) return Boolean
   is
      Explorer : constant Buffer_View_Access := Buffer_View_Access (View);
      Kernel   : constant Kernel_Handle := Explorer.Kernel;
      Model    : constant Gtk_Tree_Store := -Get_Model (Explorer.Tree);
      Path     : Gtk_Tree_Path;
      Iter     : Gtk_Tree_Iter;
      Child    : MDI_Child;
   begin
      Trace (Me, "Button_Press X=" & Event.X'Img & " Y=" & Event.Y'Img
             & " State=" & Event.State'Img);

      if Event.State /= 0 then
         --  If there is a ctrl or shift key modifier present, grab the focus
         --  on the tree so that ctrl-clicking and shift-clicking extend the
         --  multiple selection as expected.
         Grab_Focus (Explorer.Tree);
         return False;
      end if;

      Path := Get_Path_At_Event (Explorer.Tree, Event);
      if Path /= Null_Gtk_Tree_Path then
         Iter := Get_Iter (Model, Path);
         Path_Free (Path);

         --  Only for actual windows
         if Children (Model, Iter) = Null_Iter then

            Child := Find_MDI_Child_By_Name
              (Get_MDI (Kernel), Get_String (Model, Iter, Data_Column));
            Trace (Me, "Clicked on row for child " & Get_Title (Child));

            if Event.Button = 3 then
               --  Right click ?
               return False;

            elsif Event.Button = 1 then
               if Event.The_Type = Gdk_2button_Press then
                  Raise_Child (Child, Give_Focus => True);
               elsif Event.The_Type = Button_Press then
                  Child_Drag_Begin
                    (Child => Child, Event => Event,
                     Areas => Child.Get_Allowed_Areas);
                  Raise_Child (Child, Give_Focus => True);
                  Trace (Me, "Child should now have the focus");
               end if;

               return True;
            end if;
         end if;
      end if;

      return False;
   end Button_Press;

   --------------------
   -- Child_Selected --
   --------------------

   procedure Child_Selected (View : access Gtk_Widget_Record'Class) is
      V     : constant Buffer_View_Access := Buffer_View_Access (View);
      Model : constant Gtk_Tree_Store := -Get_Model (V.Tree);
      Child : constant MDI_Child := Get_Focus_Child (Get_MDI (V.Kernel));
      Iter  : Gtk_Tree_Iter := Get_Iter_First (Model);
      Iter2 : Gtk_Tree_Iter;
   begin
      Trace (Me, "Child_Selected " & Get_Title (Child));
      --  If we are in the buffers view, do not show it, since otherwise that
      --  breaks the selection of multiple lines

      if Child /= null
        and then Generic_View.Child_From_View (V) /= Child
      then
         declare
            Selected : constant String := Get_Title (Child);
         begin
            Unselect_All (Get_Selection (V.Tree));

            while Iter /= Null_Iter loop
               Iter2 := Children (Model, Iter);

               if Iter2 = Null_Iter then
                  if Get_String (Model, Iter, Data_Column) = Selected then
                     Select_Iter (Get_Selection (V.Tree), Iter);
                     exit;
                  end if;

               else
                  while Iter2 /= Null_Iter loop
                     if Get_String (Model, Iter2, Data_Column) =
                       Selected
                     then
                        Select_Iter (Get_Selection (V.Tree), Iter2);
                        return;
                     end if;
                     Next (Model, Iter2);
                  end loop;
               end if;

               Next (Model, Iter);
            end loop;
         end;
      end if;
   end Child_Selected;

   -------------
   -- Refresh --
   -------------

   procedure Refresh (View : access Gtk_Widget_Record'Class) is
      V       : constant Buffer_View_Access := Buffer_View_Access (View);
      Model   : constant Gtk_Tree_Store := -Get_Model (V.Tree);
      Editors_Only   : constant Boolean := Get_History
        (Get_History (V.Kernel).all, History_Editors_Only);
      Show_Notebooks : constant Boolean := Get_History
        (Get_History (V.Kernel).all, History_Show_Notebooks);

      Notebook_Index : Integer := -1;
      Iter           : Gtk_Tree_Iter := Null_Iter;

      procedure Show_Child (Parent : Gtk_Tree_Iter; Child : MDI_Child);
      --  Insert the line for Child in the view

      procedure Purify;
      --  Clean up the tree so that we do not show empty notebook or
      --  notebooks with a single child

      ------------
      -- Purify --
      ------------

      procedure Purify is
         Iter2 : Gtk_Tree_Iter;
      begin
         if Iter /= Null_Iter then
            Iter2 := Children (Model, Iter);

            if Iter2 = Null_Iter then
               --  If we had an empty notebook, remove it
               Remove (Model, Iter);

            elsif N_Children (Model, Iter) = 1 then
               --  Single child ?
               Set (Model, Iter, Icon_Column,
                    Get_C_Proxy (Model, Iter2, Icon_Column));
               Set (Model, Iter, Name_Column,
                    Get_String (Model, Iter2, Name_Column));
               Set (Model, Iter, Data_Column,
                    Get_String (Model, Iter2, Data_Column));
               Remove (Model, Iter2);

            else
               Notebook_Index := Notebook_Index + 1;
            end if;
         else
            Notebook_Index := Notebook_Index + 1;
         end if;
      end Purify;

      ----------------
      -- Show_Child --
      ----------------

      procedure Show_Child (Parent : Gtk_Tree_Iter; Child : MDI_Child) is
         Name : constant String := Get_Short_Title (Child);
         Iter : Gtk_Tree_Iter;
      begin
         if not Editors_Only
           or else Is_Source_Box (Child)
         then
            Append (Model, Iter, Parent);
            if Name = "" then
               Set (Model, Iter, Name_Column, Untitled);
               Set (Model, Iter, Data_Column, Untitled);
            else
               Set (Model, Iter, Icon_Column,
                    GObject (Get_Icon (Child)));
               Set (Model, Iter, Name_Column, Name);
               Set (Model, Iter, Data_Column, Get_Title (Child));
            end if;

            if Child = Get_Focus_Child (Get_MDI (V.Kernel)) then
               Select_Iter (Get_Selection (V.Tree), Iter);
            end if;
         end if;
      end Show_Child;

      I_Child          : Gtkada.MDI.Child_Iterator;
      Child            : MDI_Child;
      Column           : Gint;
      Current_Notebook : Gtk_Notebook;
      pragma Unreferenced (Column);

   begin
      Clear (Model);

      if Show_Notebooks then
         Column := Freeze_Sort (-Get_Model (V.Tree));
      else
         Thaw_Sort (-Get_Model (V.Tree), 1);
      end if;

      I_Child := First_Child
        (Get_MDI (V.Kernel), Group_By_Notebook => Show_Notebooks);

      loop
         Child := Get (I_Child);
         exit when Child = null;

         if Show_Notebooks then
            if Notebook_Index = -1
              or else Get_Notebook (I_Child) /= Current_Notebook
            then
               Purify;
               Current_Notebook := Get_Notebook (I_Child);
               Append (Model, Iter, Null_Iter);
               Set (Model, Iter, Name_Column,
                    -"Notebook" & Integer'Image (Notebook_Index));
            end if;

            Show_Child (Iter, Child);

         else
            Show_Child (Null_Iter, Child);
         end if;

         Next (I_Child);
      end loop;

      if Show_Notebooks then
         Purify;
      end if;

      Expand_All (V.Tree);
   end Refresh;

   -----------------
   -- Create_Menu --
   -----------------

   overriding procedure Create_Menu
     (View    : not null access Buffer_View_Record;
      Menu    : not null access Gtk.Menu.Gtk_Menu_Record'Class)
   is
      Check   : Gtk_Check_Menu_Item;
   begin
      Gtk_New (Check, Label => -"Show editors only");
      Associate (Get_History (View.Kernel).all, History_Editors_Only, Check);
      Widget_Callback.Object_Connect
        (Check, Signal_Toggled, Refresh'Access, Slot_Object => View);
      Menu.Add (Check);

      Gtk_New (Check, Label => -"Show notebooks");
      Associate (Get_History (View.Kernel).all, History_Show_Notebooks, Check);
      Widget_Callback.Object_Connect
        (Check, Signal_Toggled, Refresh'Access, Slot_Object => View);
      Menu.Add (Check);
   end Create_Menu;

   --------------------------
   -- View_Context_Factory --
   --------------------------

   procedure View_Context_Factory
     (Context      : in out Selection_Context;
      Kernel       : access Kernel_Handle_Record'Class;
      Event_Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Object       : access Glib.Object.GObject_Record'Class;
      Event        : Gdk.Event.Gdk_Event;
      Menu         : Gtk_Menu)
   is
      pragma Unreferenced (Event_Widget, Context, Kernel, Menu);
      V       : constant Buffer_View_Access := Buffer_View_Access (Object);
      Iter    : Gtk_Tree_Iter;
   begin
      --  Focus on the window, so that the selection is correctly taken into
      --  account. But do not process the usual callback, since we do not want
      --  to unselect everything and select the Windows View itself
      Handler_Block (Get_MDI (V.Kernel), V.Child_Selected_Id);
      Raise_Child (Generic_View.Child_From_View (V));
      Handler_Unblock (Get_MDI (V.Kernel), V.Child_Selected_Id);

      Iter := Find_Iter_For_Event (V.Tree, Event);

      if Iter /= Null_Iter then
         --  Nothing special in the context, just the module itself so that
         --  people can still add information if needed
         if not Iter_Is_Selected (Get_Selection (V.Tree), Iter) then
            Unselect_All (Get_Selection (V.Tree));
            Select_Iter (Get_Selection (V.Tree), Iter);
         end if;
      end if;
   end View_Context_Factory;

   ----------------
   -- Initialize --
   ----------------

   function Initialize
     (View   : access Buffer_View_Record'Class) return Gtk_Widget
   is
      Tooltip   : Tooltips.Tooltips_Access;
      Scrolled  : Gtk_Scrolled_Window;
   begin
      Initialize_Vbox (View, Homogeneous => False);

      Gtk_New (Scrolled);
      Scrolled.Set_Policy (Policy_Automatic, Policy_Automatic);
      View.Pack_Start (Scrolled, Expand => True, Fill => True);

      View.Tree := Create_Tree_View
        (Column_Types       => (Icon_Column => Gdk.Pixbuf.Get_Type,
                                Name_Column => GType_String,
                                Data_Column => GType_String),
         Column_Names       => (1 => null, 2 => null),
         Show_Column_Titles => False,
         Selection_Mode     => Selection_Multiple,
         Sortable_Columns   => True,
         Initial_Sort_On    => 2,
         Hide_Expander      => False);
      Scrolled.Add (View.Tree);

      Set_Font_And_Colors (View.Tree, Fixed_Font => True);

      Widget_Callback.Object_Connect
        (Get_MDI (View.Kernel), Signal_Child_Added,
         Refresh'Access, Slot_Object => View);
      Widget_Callback.Object_Connect
        (Get_MDI (View.Kernel), Signal_Child_Removed, Refresh'Access,
         Slot_Object => View);
      Widget_Callback.Object_Connect
        (Get_MDI (View.Kernel),
         Signal_Child_Title_Changed, Refresh'Access, View);
      View.Child_Selected_Id := Widget_Callback.Object_Connect
        (Get_MDI (View.Kernel), Signal_Child_Selected,
         Widget_Callback.To_Marshaller (Child_Selected'Access), View);
      Widget_Callback.Object_Connect
        (Get_MDI (View.Kernel), Signal_Child_Icon_Changed,
         Refresh'Access, View);
      Widget_Callback.Object_Connect
        (Get_MDI (View.Kernel), Signal_Float_Child, Refresh'Access, View);
      Widget_Callback.Object_Connect
        (Get_MDI (View.Kernel), Signal_Children_Reorganized, Refresh'Access,
         View);

      View.Tree.On_Button_Press_Event (Button_Press'Access, View);

      Register_Contextual_Menu
        (Kernel          => View.Kernel,
         Event_On_Widget => View.Tree,
         Object          => View,
         ID              => Generic_View.Get_Module,
         Context_Func    => View_Context_Factory'Access);

      Add_Hook (View.Kernel, Preference_Changed_Hook,
                Wrapper (Preferences_Changed'Access),
                Name => "windows view.preferences_changed",
                Watch => GObject (View));

      --  Initialize tooltips

      Tooltip := new Buffer_View_Tooltips;
      Tooltip.Set_Tooltip (View.Tree);

      Refresh (View);

      return Gtk_Widget (View.Tree);
   end Initialize;

   -----------------
   -- Set_Pattern --
   -----------------

   overriding procedure Set_Pattern
      (Self     : not null access Opened_Windows_Search;
       Pattern  : not null access GPS.Search.Search_Pattern'Class;
       Limit    : Natural := Natural'Last)
   is
      pragma Unreferenced (Limit);
   begin
      Self.Pattern := Search_Pattern_Access (Pattern);
      Self.Iter    := First_Child (Get_MDI (Self.Kernel));
   end Set_Pattern;

   ----------
   -- Next --
   ----------

   overriding procedure Next
      (Self     : not null access Opened_Windows_Search;
       Result   : out GPS.Search.Search_Result_Access;
       Has_Next : out Boolean)
   is
      C : Search_Context;
      L     : GNAT.Strings.String_Access;
      Child : constant MDI_Child := Get (Self.Iter);
   begin
      Result := null;

      if Child = null then
         Has_Next  := False;
      else
         C := Self.Pattern.Start (Child.Get_Short_Title);
         if C /= GPS.Search.No_Match then
            if Child.Get_Title /= Child.Get_Short_Title then
               L := new String'(Child.Get_Title);
            end if;
            Result := new Opened_Windows_Result'
               (Kernel   => Self.Kernel,
                Provider => Self,
                Score    => C.Score,
                Short    => new String'
                   (Self.Pattern.Highlight_Match
                      (Child.Get_Short_Title, Context => C)),
                Long     => L,
                Id       => new String'(Child.Get_Title));
            Self.Adjust_Score (Result);

         elsif Child.Get_Short_Title /= Child.Get_Title then
            C := Self.Pattern.Start (Child.Get_Title);
            if C /= GPS.Search.No_Match then
               L := new String'(Child.Get_Title);
               Result := new Opened_Windows_Result'
                  (Kernel   => Self.Kernel,
                   Provider => Self,
                   Score    => C.Score,
                   Short    => new String'(Child.Get_Short_Title),
                   Long     => new String'
                      (Self.Pattern.Highlight_Match
                         (Child.Get_Title, Context => C)),
                   Id       => new String'(Child.Get_Title));
               Self.Adjust_Score (Result);
            end if;
         end if;

         Next (Self.Iter);
         Has_Next := Get (Self.Iter) /= null;
      end if;
   end Next;

   ---------------------
   -- Complete_Suffix --
   ---------------------

   overriding function Complete_Suffix
     (Self      : not null access Opened_Windows_Search;
      Pattern   : not null access GPS.Search.Search_Pattern'Class)
      return String
   is
      Suffix      : Unbounded_String;
      Suffix_Last : Natural := 0;
      C           : Search_Context;
      Child       : MDI_Child;
   begin
      Self.Set_Pattern (Pattern);

      loop
         Child := Get (Self.Iter);
         exit when Child = null;

         C := Self.Pattern.Start (Child.Get_Short_Title);
         if C /= GPS.Search.No_Match then
            Self.Pattern.Compute_Suffix
              (C, Child.Get_Short_Title, Suffix, Suffix_Last);
            exit when Suffix_Last = 0;

         elsif Child.Get_Short_Title /= Child.Get_Title then
            C := Self.Pattern.Start (Child.Get_Title);
            if C /= GPS.Search.No_Match then
               Self.Pattern.Compute_Suffix
                 (C, Child.Get_Title, Suffix, Suffix_Last);
               exit when Suffix_Last = 0;
            end if;
         end if;

         Next (Self.Iter);
      end loop;

      return Slice (Suffix, 1, Suffix_Last);
   end Complete_Suffix;

   -------------------
   -- Documentation --
   -------------------

   overriding function Documentation
      (Self     : not null access Opened_Windows_Search) return String
   is
      pragma Unreferenced (Self);
   begin
      return "Search amongst opened windows";
   end Documentation;

   -------------
   -- Execute --
   -------------

   overriding procedure Execute
      (Self       : not null access Opened_Windows_Result;
       Give_Focus : Boolean)
   is
      C : constant MDI_Child :=
         Find_MDI_Child_By_Name (Get_MDI (Self.Kernel), Self.Id.all);
   begin
      if C /= null then
         Raise_Child (C, Give_Focus => Give_Focus);
      end if;
   end Execute;

   ----------
   -- Full --
   ----------

   overriding function Full
      (Self       : not null access Opened_Windows_Result) return Gtk_Widget
   is
      pragma Unreferenced (Self);
   begin
      return null;
   end Full;

   -------------------------
   -- Preferences_Changed --
   -------------------------

   procedure Preferences_Changed
     (Kernel : access Kernel_Handle_Record'Class;
      Data   : access Hooks_Data'Class)
   is
      View  : constant Buffer_View_Access :=
        Generic_View.Retrieve_View (Kernel);
   begin
      if View /= null then
         Set_Font_And_Colors
           (View.Tree, Fixed_Font => True, Pref => Get_Pref (Data));
      end if;
   end Preferences_Changed;

   ---------------------
   -- Register_Module --
   ---------------------

   procedure Register_Module
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
   is
      P : Opened_Windows_Search_Access;
   begin
      Generic_View.Register_Module (Kernel);

      Create_New_Boolean_Key_If_Necessary
        (Get_History (Kernel).all, History_Editors_Only, True);
      Create_New_Boolean_Key_If_Necessary
        (Get_History (Kernel).all, History_Show_Notebooks, False);

      Register_Action
        (Kernel, "Windows view close selected",
         new Close_Command,
         -"Close all windows currently selected in the Windows view",
         Stock_Id => Stock_Close,
         Category => -"Windows view");

      P := new Opened_Windows_Search;
      Register_Provider_And_Action (Kernel, P);
   end Register_Module;

end Buffer_Views;
