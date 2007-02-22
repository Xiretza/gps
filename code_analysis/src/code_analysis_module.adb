-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                      Copyright (C) 2006-2007                      --
--                              AdaCore                              --
--                                                                   --
-- GPS is Free  software;  you can redistribute it and/or modify  it --
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

with Ada.Exceptions;             use Ada.Exceptions;
with Ada.Strings.Less_Case_Insensitive;
with Ada.Strings.Equal_Case_Insensitive;
with GNAT.OS_Lib;                use GNAT.OS_Lib;

with Glib;                       use Glib;
with Glib.Properties;
with Gtk.Cell_Renderer;
with Gtk.Cell_Renderer_Text;     use Gtk.Cell_Renderer_Text;
with Gtk.Cell_Renderer_Pixbuf;   use Gtk.Cell_Renderer_Pixbuf;
with Gtk.Cell_Renderer_Progress; use Gtk.Cell_Renderer_Progress;
with Gtk.Scrolled_Window;        use Gtk.Scrolled_Window;
with Gtk.Enums;                  use Gtk.Enums;
with Gtk.Window;                 use Gtk.Window;
with Gtk.Menu_Item;              use Gtk.Menu_Item;
with Gtk.Tree_Selection;         use Gtk.Tree_Selection;
with Gtkada.MDI;                 use Gtkada.MDI;
with Gtkada.Handlers;            use Gtkada.Handlers;

with GPS.Kernel.Project;         use GPS.Kernel.Project;
with GPS.Kernel.Styles;          use GPS.Kernel.Styles;
with GPS.Kernel.Standard_Hooks;  use GPS.Kernel.Standard_Hooks;
with GPS.Kernel.Contexts;        use GPS.Kernel.Contexts;
with GPS.Kernel.Console;
with GPS.Location_View;          use GPS.Location_View;

with Basic_Types;                use Basic_Types;
with Projects;                   use Projects;
with Projects.Registry;          use Projects.Registry;
with Language_Handlers;          use Language_Handlers;
with Language;                   use Language;
with Language.Tree;              use Language.Tree;
with Language.Tree.Database;     use Language.Tree.Database;
with Entities;                   use Entities;
with Code_Coverage;              use Code_Coverage;
with Code_Analysis_Tree_Model;   use Code_Analysis_Tree_Model;

package body Code_Analysis_Module is

   Src_File_Cst : aliased constant String := "src";
   --  Constant String that represents the name of the source file parameter
   --  of the GPS.CodeAnalysis.add_gcov_file_info subprogram
   Cov_File_Cst : aliased constant String := "cov";
   --  Constant String that represents the name of the .gcov file parameter
   --  of the GPS.CodeAnalysis.add_gcov_file_info subprogram
   Prj_File_Cst : aliased constant String := "prj";
   --  Constant String that represents the name of the .gpr file parameter
   --  of the GPS.CodeAnalysis.add_gcov_project_info subprogram
   Gcov_Extension_Cst : constant String := ".gcov";
   --  Constant String that represents the extension of GCOV files

   Progress_Bar_Width_Cst : constant Gint := 150;
   --  Constant used to set the width of the progress bars of the analysis
   --  report

   ------------
   -- Create --
   ------------

   procedure Create
     (Data    : in out Callback_Data'Class;
      Command : String)
   is
      pragma Unreferenced (Command);
      Property : constant Code_Analysis_Property
        := new Code_Analysis_Property_Record;
      Instance  : Class_Instance;
      Date      : Time;
   begin
      Instance := Nth_Arg (Data, 1, Code_Analysis_Module_ID.Class);
      Date := Clock;
      Property.Date := Date;
      Property.Instance_Name :=
        new String'("Analysis" & Integer'Image
                    (Integer (Code_Analysis_Module_ID.Instances.Length + 1)));
      Property.Projects := new Project_Maps.Map;
      GPS.Kernel.Scripts.Set_Property
        (Instance, Code_Analysis_Cst_Str,
         Instance_Property_Record (Property.all));
      Code_Analysis_Module_ID.Instances.Insert (Instance);

      if Code_Analysis_Module_ID.Project_Pixbuf = null then
         Code_Analysis_Module_ID.Project_Pixbuf := Render_Icon
           (Get_Main_Window (Code_Analysis_Module_ID.Kernel),
            "gps-project-closed", Gtk.Enums.Icon_Size_Menu);
         Code_Analysis_Module_ID.File_Pixbuf := Render_Icon
           (Get_Main_Window (Code_Analysis_Module_ID.Kernel),
            "gps-file", Gtk.Enums.Icon_Size_Menu);
         Code_Analysis_Module_ID.Subp_Pixbuf := Render_Icon
           (Get_Main_Window (Code_Analysis_Module_ID.Kernel),
            "gps-entity-subprogram", Gtk.Enums.Icon_Size_Menu);
         Code_Analysis_Module_ID.Warn_Pixbuf := Render_Icon
           (Get_Main_Window (Code_Analysis_Module_ID.Kernel),
            "gps-warning", Gtk.Enums.Icon_Size_Menu);
      end if;
   end Create;

   ----------------------
   -- Create_From_Menu --
   ----------------------

   procedure Create_From_Menu
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class)
   is
      pragma Unreferenced (Widget);
      Property : constant Code_Analysis_Property
        := new Code_Analysis_Property_Record;
      Scripts  : constant Scripting_Language_Array :=
                   Get_Scripting_Languages (Code_Analysis_Module_ID.Kernel);
      Instance : Class_Instance := New_Instance
        (Scripts (Scripts'First), Code_Analysis_Module_ID.Class);
      Date     : Time;
   begin
      Date := Clock;
      Property.Date := Date;
      Property.Instance_Name :=
        new String'("Analysis" & Integer'Image
                    (Integer (Code_Analysis_Module_ID.Instances.Length + 1)));
      Property.Projects := new Project_Maps.Map;
      GPS.Kernel.Scripts.Set_Property
        (Instance, Code_Analysis_Cst_Str,
         Instance_Property_Record (Property.all));
      Code_Analysis_Module_ID.Instances.Insert (Instance);

      if Code_Analysis_Module_ID.Project_Pixbuf = null then
         Code_Analysis_Module_ID.Project_Pixbuf := Render_Icon
           (Get_Main_Window (Code_Analysis_Module_ID.Kernel),
            "gps-project-closed", Gtk.Enums.Icon_Size_Menu);
         Code_Analysis_Module_ID.File_Pixbuf := Render_Icon
           (Get_Main_Window (Code_Analysis_Module_ID.Kernel),
            "gps-file", Gtk.Enums.Icon_Size_Menu);
         Code_Analysis_Module_ID.Subp_Pixbuf := Render_Icon
           (Get_Main_Window (Code_Analysis_Module_ID.Kernel),
            "gps-entity-subprogram", Gtk.Enums.Icon_Size_Menu);
         Code_Analysis_Module_ID.Warn_Pixbuf := Render_Icon
           (Get_Main_Window (Code_Analysis_Module_ID.Kernel),
            "gps-warning", Gtk.Enums.Icon_Size_Menu);
      end if;
   end Create_From_Menu;

   -------------------------------------
   -- Add_Gcov_File_Info_From_Context --
   -------------------------------------

   procedure Add_Gcov_File_Info_From_Context
     (Widget      : access Glib.Object.GObject_Record'Class;
      Cont_N_Inst : Context_And_Instance)
   is
      pragma Unreferenced (Widget);
      Property     : Code_Analysis_Property_Record;
      Project_Name : constant Project_Type :=
                       Project_Information (Cont_N_Inst.Context);
      Project_Node : Project_Access;
      Src_File     : constant VFS.Virtual_File :=
                       File_Information (Cont_N_Inst.Context);
      Cov_File     : VFS.Virtual_File;
   begin
      Property     := Code_Analysis_Property_Record
        (Get_Property (Cont_N_Inst.Instance, Code_Analysis_Cst_Str));
      Project_Node := Get_Or_Create (Property.Projects, Project_Name);
      Cov_File     := Create (Object_Path (Project_Name, False, False) &
                              "/" & Base_Name (Src_File) & Gcov_Extension_Cst);

      if not Is_Regular_File (Cov_File) then
         GPS.Kernel.Console.Insert
           (Code_Analysis_Module_ID.Kernel,
            "There is no loadable GCOV information" &
            " associated with " & Base_Name (Src_File),
            Mode => GPS.Kernel.Console.Error);
         return;
      end if;

      Add_Gcov_File_Info (Src_File, Cov_File, Project_Node);
      Compute_Project_Coverage (Project_Node);
   end Add_Gcov_File_Info_From_Context;

   -----------------------------------
   -- Add_Gcov_File_Info_From_Shell --
   -----------------------------------

   procedure Add_Gcov_File_Info_From_Shell
     (Data    : in out Callback_Data'Class;
      Command : String)
   is
      pragma Unreferenced (Command);
      Property     : Code_Analysis_Property_Record;
      Instance     : Class_Instance;
      Src_Instance : Class_Instance;
      Cov_Instance : Class_Instance;
      Src_File     : VFS.Virtual_File;
      Cov_File     : VFS.Virtual_File;
      Project_Name : Project_Type;
      Project_Node : Project_Access;
   begin
      Instance := Nth_Arg (Data, 1, Code_Analysis_Module_ID.Class);
      Property := Code_Analysis_Property_Record
        (Get_Property (Instance, Code_Analysis_Cst_Str));
      Name_Parameters (Data, (2 => Src_File_Cst'Access,
                              3 => Cov_File_Cst'Access));
      Src_Instance := Nth_Arg
           (Data, 2, Get_File_Class (Code_Analysis_Module_ID.Kernel),
            Default => No_Class_Instance, Allow_Null => True);

      if Src_Instance = No_Class_Instance then
         Src_File := VFS.No_File;
      else
         Src_File := Get_Data (Src_Instance);
      end if;

      if not Is_Regular_File (Src_File) then
         Set_Error_Msg (Data, "The name given for 'src' file is wrong");
         return;
      end if;

      Cov_Instance := Nth_Arg
           (Data, 3, Get_File_Class (Code_Analysis_Module_ID.Kernel),
            Default => No_Class_Instance, Allow_Null => True);

      if Cov_Instance = No_Class_Instance then
         Cov_File := VFS.No_File;
      else
         Cov_File := Get_Data (Cov_Instance);
      end if;

      if not Is_Regular_File (Cov_File) then
         Set_Error_Msg (Data, "The name given for 'cov' file is wrong");
         return;
      end if;

      Project_Name  := Get_Project_From_File
        (Get_Registry (Code_Analysis_Module_ID.Kernel).all, Src_File);
      Project_Node  := Get_Or_Create (Property.Projects, Project_Name);
      Add_Gcov_File_Info (Src_File, Cov_File, Project_Node);
      Compute_Project_Coverage (Project_Node);
      GPS.Kernel.Scripts.Set_Property (Instance, Code_Analysis_Cst_Str,
                                       Instance_Property_Record (Property));
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end Add_Gcov_File_Info_From_Shell;

   ------------------------
   -- Add_Gcov_File_Info --
   ------------------------

   procedure Add_Gcov_File_Info
     (Src_File     : VFS.Virtual_File;
      Cov_File     : VFS.Virtual_File;
      Project_Node : Project_Access)
   is
      File_Contents : GNAT.Strings.String_Access := Read_File (Cov_File);
      File_Node     : constant Code_Analysis.File_Access :=
                        Get_Or_Create (Project_Node, Src_File);
      Handler       : constant Language_Handler
        := Get_Language_Handler (Code_Analysis_Module_ID.Kernel);
      Database      : constant Construct_Database_Access
        := Get_Construct_Database (Code_Analysis_Module_ID.Kernel);
      Tree_Lang     : constant Tree_Language_Access
        := Get_Tree_Language_From_File (Handler, File_Node.Name, False);
      Data_File     : constant Structured_File_Access :=
                        Language.Tree.Database.Get_Or_Create
                          (Db   => Database,
                           File => File_Node.Name,
                           Lang => Tree_Lang);
   begin
      File_Node.Analysis_Data.Coverage_Data := new Node_Coverage;
      Add_File_Info (File_Node, File_Contents,
                      Node_Coverage
                        (File_Node.Analysis_Data.Coverage_Data.all).Children,
                     File_Node.Analysis_Data.Coverage_Data.Coverage);

      if Project_Node.Analysis_Data.Coverage_Data = null then
         Project_Node.Analysis_Data.Coverage_Data := new Subprogram_Coverage;
         Subprogram_Coverage
           (Project_Node.Analysis_Data.Coverage_Data.all).Called :=
           Get_Runs_Info_From_File (File_Node, File_Contents);
      end if;
      --  Check for project Called info

      Add_Subprogram_Info (Data_File, File_Node);
      Free (File_Contents);
   end Add_Gcov_File_Info;

   ----------------------------------------
   -- Add_Gcov_Project_Info_From_Context --
   ----------------------------------------

   procedure Add_Gcov_Project_Info_From_Context
     (Widget      : access Glib.Object.GObject_Record'Class;
      Cont_N_Inst : Context_And_Instance)
   is
      pragma Unreferenced (Widget);
      Property : Code_Analysis_Property_Record;
      Prj_Name : constant Project_Type :=
                   Project_Information (Cont_N_Inst.Context);
      Prj_Node : Project_Access;
   begin
      Property     := Code_Analysis_Property_Record
        (Get_Property (Cont_N_Inst.Instance, Code_Analysis_Cst_Str));
      Prj_Node := Get_Or_Create (Property.Projects, Prj_Name);
      Add_Gcov_Project_Info (Prj_Node);
   end Add_Gcov_Project_Info_From_Context;

   --------------------------------------
   -- Add_Gcov_Project_Info_From_Shell --
   --------------------------------------

   procedure Add_Gcov_Project_Info_From_Shell
     (Data    : in out Callback_Data'Class;
      Command : String)
   is
      pragma Unreferenced (Command);
      Property : Code_Analysis_Property_Record;
      Instance : Class_Instance;
      Prj_Inst : Class_Instance;
      Prj_File : VFS.Virtual_File;
      Prj_Name : Project_Type;
      Prj_Node : Project_Access;
   begin
      Instance := Nth_Arg (Data, 1, Code_Analysis_Module_ID.Class);
      Property := Code_Analysis_Property_Record
        (Get_Property (Instance, Code_Analysis_Cst_Str));
      Name_Parameters (Data, (2 => Prj_File_Cst'Access));
      Prj_Inst := Nth_Arg
        (Data, 2, Get_File_Class (Code_Analysis_Module_ID.Kernel),
         Default => No_Class_Instance, Allow_Null => True);

      if Prj_Inst = No_Class_Instance then
         Prj_File := VFS.No_File;
      else
         Prj_File := Get_Data (Prj_Inst);
      end if;

      if not Is_Regular_File (Prj_File) then
         Set_Error_Msg (Data, "The name given for 'prj' file is wrong");
         return;
      end if;

      Prj_Name  := Load_Or_Find
        (Get_Registry (Code_Analysis_Module_ID.Kernel).all,
         Locale_Full_Name (Prj_File));
      Prj_Node  := Get_Or_Create (Property.Projects, Prj_Name);
      Add_Gcov_Project_Info (Prj_Node);
      GPS.Kernel.Scripts.Set_Property (Instance, Code_Analysis_Cst_Str,
                                       Instance_Property_Record (Property));
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end Add_Gcov_Project_Info_From_Shell;

   ---------------------------
   -- Add_Gcov_Project_Info --
   ---------------------------

   procedure Add_Gcov_Project_Info
     (Project_Node : Project_Access)
   is
      Src_Files : VFS.File_Array_Access;
      Src_File  : VFS.Virtual_File;
      Cov_File  : VFS.Virtual_File;
   begin
      --  get every source files of the project
      --  check if they are associated with gcov info
      --  load their info
      Src_Files := Get_Source_Files (Project_Node.Name, Recursive => False);

      for J in Src_Files'First .. Src_Files'Last loop
         Src_File := Src_Files (J);
         Cov_File := Create (Object_Path (Project_Node.Name, False, False) &
                             "/" & Base_Name (Src_File) & Gcov_Extension_Cst);

         if Is_Regular_File (Cov_File) then
            Add_Gcov_File_Info (Src_File, Cov_File, Project_Node);
         end if;
      end loop;

      Compute_Project_Coverage (Project_Node);
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end Add_Gcov_Project_Info;

   ---------------------------------------
   -- List_Lines_Not_Covered_From_Shell --
   ---------------------------------------

   procedure List_Lines_Not_Covered_From_Shell
     (Data    : in out Callback_Data'Class;
      Command : String)
   is
      pragma Unreferenced (Command);
      use Project_Maps;
      Property : Code_Analysis_Property_Record;
      Instance : Class_Instance;
      Map_Cur  : Project_Maps.Cursor;
   begin
      Instance := Nth_Arg (Data, 1, Code_Analysis_Module_ID.Class);
      Property := Code_Analysis_Property_Record
        (Get_Property (Instance, Code_Analysis_Cst_Str));
      declare
         Sort_Arr : Project_Array (1 .. Integer (Property.Projects.Length));
      begin
         Map_Cur  := Property.Projects.First;

         for J in Sort_Arr'Range loop
            Sort_Arr (J) := Element (Map_Cur);
            Next (Map_Cur);
         end loop;

         Sort_Projects (Sort_Arr);

         for J in Sort_Arr'Range loop
            List_Lines_Not_Covered_In_Project (Sort_Arr (J));
         end loop;
      end;
   end List_Lines_Not_Covered_From_Shell;

   -------------------------------------
   -- Show_Analysis_Report_From_Shell --
   -------------------------------------

   procedure Show_Analysis_Report_From_Shell
     (Data    : in out Callback_Data'Class;
      Command : String)
   is
      pragma Unreferenced (Command);
      Instance : Class_Instance;
      Property : Code_Analysis_Property_Record;
   begin
      Instance := Nth_Arg (Data, 1, Code_Analysis_Module_ID.Class);
      Property := Code_Analysis_Property_Record
        (Get_Property (Instance, Code_Analysis_Cst_Str));
      Show_Analysis_Report (Instance, Property);
   end Show_Analysis_Report_From_Shell;

   ---------------------------------
   -- Show_Tree_View_From_Context --
   ---------------------------------

   procedure Show_Analysis_Report_From_Context
     (Widget      : access Glib.Object.GObject_Record'Class;
      Cont_N_Inst : Context_And_Instance)
   is
      pragma Unreferenced (Widget);
      Property : Code_Analysis_Property_Record := Code_Analysis_Property_Record
        (Get_Property (Cont_N_Inst.Instance, Code_Analysis_Cst_Str));
   begin
      Show_Analysis_Report
        (Cont_N_Inst.Instance, Property, Cont_N_Inst.Context);
   end Show_Analysis_Report_From_Context;

   ------------------------------------
   -- Show_Analysis_Report_From_Menu --
   ------------------------------------

   procedure Show_Analysis_Report_From_Menu
     (Widget      : access Glib.Object.GObject_Record'Class;
      Cont_N_Inst : Context_And_Instance)
   is
      pragma Unreferenced (Widget);
      Property : Code_Analysis_Property_Record := Code_Analysis_Property_Record
        (Get_Property (Cont_N_Inst.Instance, Code_Analysis_Cst_Str));
   begin
      Show_Analysis_Report (Cont_N_Inst.Instance, Property);
   end Show_Analysis_Report_From_Menu;

   --------------------------
   -- Show_Analysis_Report --
   --------------------------

   procedure Show_Analysis_Report
     (Instance : Class_Instance;
      Property : in out Code_Analysis_Property_Record;
      Context  : Selection_Context := No_Context)
   is
      Project_Node : Project_Access;
      Scrolled     : Gtk_Scrolled_Window;
      Text_Render  : Gtk_Cell_Renderer_Text;
      Pixbuf_Rend  : Gtk_Cell_Renderer_Pixbuf;
      Bar_Render   : Gtk_Cell_Renderer_Progress;
      Iter         : Gtk_Tree_Iter;
      Path         : Gtk_Tree_Path;
      C            : Context_And_Instance :=
                       (Context => Context, Instance => Instance);
      Num_Col      : Gint;
      pragma Unreferenced (Project_Node);
   begin

      if Property.View = null then
         Property.View := new Code_Analysis_View_Record;
         Initialize_Hbox (Property.View);
         Property.View.Projects := Property.Projects;
         Gtk_New (Property.View.Model, GType_Array'
             (Pix_Col     => Gdk.Pixbuf.Get_Type,
              Name_Col    => GType_String,
              Node_Col    => GType_Pointer,
              File_Col    => GType_Pointer,
              Cov_Col     => GType_String,
              Cov_Sort    => GType_Int,
              Cov_Bar_Txt => GType_String,
              Cov_Bar_Val => GType_Int));
         Gtk_New (Property.View.Tree, Gtk_Tree_Model (Property.View.Model));
         Set_Name (Property.View.Tree, "Code Analysis Tree"); --  For testsuite

         -----------------
         -- Node column --
         -----------------

         Gtk_New (Property.View.Node_Column);
         Gtk_New (Pixbuf_Rend);
         Pack_Start (Property.View.Node_Column, Pixbuf_Rend, False);
         Add_Attribute
           (Property.View.Node_Column, Pixbuf_Rend, "pixbuf", Pix_Col);
         Gtk_New (Text_Render);
         Pack_Start (Property.View.Node_Column, Text_Render, False);
         Add_Attribute
           (Property.View.Node_Column, Text_Render, "text", Name_Col);
         Num_Col := Append_Column
           (Property.View.Tree, Property.View.Node_Column);
         Set_Title (Property.View.Node_Column, -"Entities");
         Set_Resizable (Property.View.Node_Column, True);
         Set_Sort_Column_Id (Property.View.Node_Column, Name_Col);

         ----------------------
         -- Coverage columns --
         ----------------------

         Gtk_New (Property.View.Cov_Column);
         Num_Col :=
           Append_Column (Property.View.Tree, Property.View.Cov_Column);
         Gtk_New (Text_Render);
         Pack_Start (Property.View.Cov_Column, Text_Render, False);
         Add_Attribute
           (Property.View.Cov_Column, Text_Render, "text", Cov_Col);
         Set_Title (Property.View.Cov_Column, -"Coverage");
         Set_Sort_Column_Id (Property.View.Cov_Column, Cov_Sort);
         Gtk_New (Property.View.Cov_Percent);
         Num_Col :=
           Append_Column (Property.View.Tree, Property.View.Cov_Percent);
         Gtk_New (Bar_Render);
         Glib.Properties.Set_Property
           (Bar_Render,
            Gtk.Cell_Renderer.Width_Property,
            Progress_Bar_Width_Cst);
         Pack_Start (Property.View.Cov_Percent, Bar_Render, False);
         Add_Attribute
           (Property.View.Cov_Percent, Bar_Render, "text", Cov_Bar_Txt);
         Add_Attribute
           (Property.View.Cov_Percent, Bar_Render, "value", Cov_Bar_Val);
         Set_Title (Property.View.Cov_Percent, -"Coverage Percentage");
         Set_Sort_Column_Id (Property.View.Cov_Percent, Cov_Bar_Val);
         Gtk_New (Scrolled);
         Set_Policy
           (Scrolled, Gtk.Enums.Policy_Automatic, Gtk.Enums.Policy_Automatic);
         Add (Scrolled, Property.View.Tree);
         Add (Property.View, Scrolled);

         ---------------
         -- MDI child --
         ---------------

         GPS.Kernel.MDI.Gtk_New
           (Property.Child, Property.View,
            Group  => Group_VCS_Explorer,
            Module => Code_Analysis_Module_ID);
         Set_Title
           (Property.Child, -("Report of " & Property.Instance_Name.all));
         Register_Contextual_Menu
           (Code_Analysis_Module_ID.Kernel,
            Event_On_Widget => Property.View.Tree,
            Object          => Property.View,
            ID              => Module_ID (Code_Analysis_Module_ID),
            Context_Func    => Context_Func'Access);
         Gtkada.Handlers.Return_Callback.Object_Connect
           (Property.View.Tree,
            "button_press_event",
            Gtkada.Handlers.Return_Callback.To_Marshaller
              (On_Double_Click'Access),
            Property.View,
            After => False);
         Context_And_Instance_CB.Connect
           (Property.View, "destroy", Context_And_Instance_CB.To_Marshaller
              (On_Destroy'Access), C);
         Put (Get_MDI (Code_Analysis_Module_ID.Kernel), Property.Child);
         GPS.Kernel.Scripts.Set_Property
           (Instance, Code_Analysis_Cst_Str,
            Instance_Property_Record (Property));
      end if;

      Clear (Property.View.Model);
      Iter := Get_Iter_First (Property.View.Model);
      Fill_Iter (Property.View.Model, Iter, Property.Projects);

      -------------------------------------
      -- Selection of the context caller --
      -------------------------------------

      Iter := Get_Iter_First (Property.View.Model);

      if Context /= No_Context then
         --  So we have some project information
         Num_Col := 1;

         loop
            exit when Get_String (Property.View.Model, Iter, Num_Col) =
              Project_Name (Project_Information (Context));
            Next (Property.View.Model, Iter);
         end loop;
         --  Find in the tree the context's project

         if Has_File_Information (Context) then
            --  So we also have file information
            Iter := Children (Property.View.Model, Iter);

            loop
               exit when Get_String (Property.View.Model, Iter, Num_Col) =
                 Base_Name (File_Information (Context));
               Next (Property.View.Model, Iter);
            end loop;
         end if;
         --  Find in the tree the context's file

         if Has_Entity_Name_Information (Context) and then
           Is_Subprogram (Get_Entity (Context)) then
            --  So we have a subprogram information accordingly to
            --  Filter_Matches_Primitives
            Iter := Children (Property.View.Model, Iter);

            loop
               exit when Get_String (Property.View.Model, Iter, Num_Col) =
                 Entity_Name_Information (Context);
               Next (Property.View.Model, Iter);
            end loop;
         end if;
         --  Find in the tree the context's subprogram
      end if;

      Path := Get_Path (Property.View.Model, Iter);
      Collapse_All (Property.View.Tree);
      Expand_To_Path (Property.View.Tree, Path);
      Select_Path (Get_Selection (Property.View.Tree), Path);
      Path_Free (Path);
      Raise_Child (Property.Child);
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end Show_Analysis_Report;

   -------------
   -- Destroy --
   -------------

   procedure Destroy
     (Data    : in out Callback_Data'Class;
      Command : String)
   is
      pragma Unreferenced (Command);
      Instance : Class_Instance;
      Property : Code_Analysis_Property_Record;
   begin
      Instance      := Nth_Arg (Data, 1, Code_Analysis_Module_ID.Class);
      Property      := Code_Analysis_Property_Record
        (Get_Property (Instance, Code_Analysis_Cst_Str));
      Free_Code_Analysis (Property.Projects);
      Unchecked_Free (Property.View);

      if Code_Analysis_Module_ID.Instances.Contains (Instance) then
         Code_Analysis_Module_ID.Instances.Delete (Instance);
      end if;

      GNAT.Strings.Free (Property.Instance_Name);
   end Destroy;

   ----------------
   -- On_Destroy --
   ----------------

   procedure On_Destroy (Widget      : access Glib.Object.GObject_Record'Class;
                         Cont_N_Inst : Context_And_Instance) is
      Property : Code_Analysis_Property_Record := Code_Analysis_Property_Record
        (Get_Property (Cont_N_Inst.Instance, Code_Analysis_Cst_Str));
      pragma Unreferenced (Widget);
   begin
      Property.View := null;
      GPS.Kernel.Scripts.Set_Property (Cont_N_Inst.Instance,
                                       Code_Analysis_Cst_Str,
                                       Instance_Property_Record (Property));
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end On_Destroy;

   ---------------------
   -- On_Double_Click --
   ---------------------

   function On_Double_Click (View  : access Gtk_Widget_Record'Class;
                             Event : Gdk_Event) return Boolean
   is
      V         : constant Code_Analysis_View := Code_Analysis_View (View);
      Iter      : Gtk_Tree_Iter;
      Model     : Gtk_Tree_Model;
      Path      : Gtk_Tree_Path;
      use GType_File;
   begin
      if Get_Button (Event) = 1
        and then Get_Event_Type (Event) = Gdk_2button_Press
      then
         Get_Selected (Get_Selection (V.Tree), Model, Iter);
         Path := Get_Path (Model, Iter);

         if Get_Depth (Path) = 1 and then not Has_Child (V.Model, Iter) then
            if GType_File.Get (Gtk_Tree_Store (Model), Iter, Node_Col) =
              GType_File.Get (Gtk_Tree_Store (Model), Iter, File_Col)
            then
               Open_File_Editor_On_File (Model, Iter);
            else
               Open_File_Editor_On_Subprogram (Model, Iter);
            end if;
         elsif Get_Depth (Path) = 2 then
            Open_File_Editor_On_File (Model, Iter);
         elsif Get_Depth (Path) = 3 then
            Open_File_Editor_On_Subprogram (Model, Iter);
         end if;

         return True;
      end if;

      return False;
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
         return False;
   end On_Double_Click;

   ------------------------------
   -- Open_File_Editor_On_File --
   ------------------------------

   procedure Open_File_Editor_On_File
     (Model : Gtk_Tree_Model; Iter : Gtk_Tree_Iter)
   is
      File_Node : constant File_Access := File_Access
        (GType_File.Get (Gtk_Tree_Store (Model), Iter, Node_Col));
   begin
      Open_File_Editor
        (Code_Analysis_Module_ID.Kernel, File_Node.Name);
   end Open_File_Editor_On_File;

   ------------------------------------
   -- Open_File_Editor_On_Subprogram --
   ------------------------------------

   procedure Open_File_Editor_On_Subprogram
     (Model : Gtk_Tree_Model; Iter : Gtk_Tree_Iter)
   is
      File_Node : constant File_Access := File_Access
        (GType_File.Get (Gtk_Tree_Store (Model), Iter, File_Col));
      Subp_Node : constant Subprogram_Access := Subprogram_Access
        (GType_Subprogram.Get (Gtk_Tree_Store (Model), Iter, Node_Col));
   begin
      Open_File_Editor
        (Code_Analysis_Module_ID.Kernel,
         File_Node.Name,
         Subp_Node.Line,
         Basic_Types.Visible_Column_Type (Subp_Node.Column));
   end Open_File_Editor_On_Subprogram;

   ------------------------------------------
   -- Add_Coverage_Annotations_From_Report --
   ------------------------------------------

   procedure Add_Coverage_Annotations_From_Report
     (Object : access Gtk_Widget_Record'Class)
   is
      View      : constant Code_Analysis_View := Code_Analysis_View (Object);
      Iter      : Gtk_Tree_Iter;
      Path      : Gtk_Tree_Path;
      File_Node : Code_Analysis.File_Access;
      use GType_File;
   begin
      Get_Selected
        (Get_Selection (View.Tree), Gtk_Tree_Model (View.Model), Iter);
      Path := Get_Path (View.Model, Iter);

      if Get_Depth (Path) = 1 and then not Has_Child (View.Model, Iter) then
         if GType_File.Get (Gtk_Tree_Store (View.Model), Iter, Node_Col) =
           GType_File.Get (Gtk_Tree_Store (View.Model), Iter, File_Col)
         then
            Open_File_Editor_On_File (Gtk_Tree_Model (View.Model), Iter);
         else
            Open_File_Editor_On_Subprogram (Gtk_Tree_Model (View.Model), Iter);
         end if;
      elsif Get_Depth (Path) = 2 then
         Open_File_Editor_On_File (Gtk_Tree_Model (View.Model), Iter);
      elsif Get_Depth (Path) = 3 then
         Open_File_Editor_On_Subprogram (Gtk_Tree_Model (View.Model), Iter);
      end if;

      File_Node := Code_Analysis.File_Access
        (GType_File.Get (Gtk_Tree_Store (View.Model), Iter, File_Col));
      Add_Coverage_Annotations (File_Node);
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end Add_Coverage_Annotations_From_Report;

   -------------------------------------------
   -- Add_Coverage_Annotations_From_Context --
   -------------------------------------------

   procedure Add_Coverage_Annotations_From_Context
     (Widget      : access Glib.Object.GObject_Record'Class;
      Cont_N_Inst : Context_And_Instance)
   is
      Property     : Code_Analysis_Property_Record
        := Code_Analysis_Property_Record
          (Get_Property (Cont_N_Inst.Instance, Code_Analysis_Cst_Str));
      Project_Node : Project_Access;
      File_Node    : Code_Analysis.File_Access;
      pragma Unreferenced (Widget);
   begin
      Project_Node := Get_Or_Create
        (Property.Projects, Project_Information (Cont_N_Inst.Context));
      File_Node := Get_Or_Create
        (Project_Node, File_Information (Cont_N_Inst.Context));
      Open_File_Editor (Code_Analysis_Module_ID.Kernel, File_Node.Name);
      Add_Coverage_Annotations (File_Node);
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end Add_Coverage_Annotations_From_Context;

   ------------------------------
   -- Add_Coverage_Annotations --
   ------------------------------

   procedure Add_Coverage_Annotations
     (File_Node : Code_Analysis.File_Access) is
      Line_Info      : Line_Information_Data;
      Line_Info_Cst  : constant String := "Coverage Analysis";
      Line_Icons     : Line_Information_Data;
      Line_Icons_Cst : constant String := "Coverage Icons";

   begin
      Line_Info  := new Line_Information_Array (File_Node.Lines'Range);
      Line_Icons := new Line_Information_Array (File_Node.Lines'Range);

      for J in File_Node.Lines'Range loop
         if File_Node.Lines (J) /= Null_Line then
            Line_Info (J).Text := Line_Coverage_Info
              (File_Node.Lines (J).Analysis_Data.Coverage_Data);

            if File_Node.Lines (J).Analysis_Data.Coverage_Data.Coverage
              = 0 then
               Line_Icons (J).Image := Code_Analysis_Module_ID.Warn_Pixbuf;
            end if;
         end if;
      end loop;

      Create_Line_Information_Column
        (Code_Analysis_Module_ID.Kernel,
         File_Node.Name, Line_Icons_Cst);
      Add_Line_Information
        (Code_Analysis_Module_ID.Kernel,
         File_Node.Name, Line_Icons_Cst,
         Line_Icons);
      Create_Line_Information_Column
        (Code_Analysis_Module_ID.Kernel,
         File_Node.Name, Line_Info_Cst);
      Add_Line_Information
        (Code_Analysis_Module_ID.Kernel,
         File_Node.Name, Line_Info_Cst,
         Line_Info);
      Unchecked_Free (Line_Info);
      Unchecked_Free (Line_Icons);
   end Add_Coverage_Annotations;

   ---------------------------------------------
   -- Remove_Coverage_Annotations_From_Report --
   ---------------------------------------------

   procedure Remove_Coverage_Annotations_From_Report
     (Object : access Gtk_Widget_Record'Class)
   is
      View      : constant Code_Analysis_View := Code_Analysis_View (Object);
      Iter      : Gtk_Tree_Iter;
      File_Node : Code_Analysis.File_Access;
   begin
      Get_Selected
        (Get_Selection (View.Tree), Gtk_Tree_Model (View.Model), Iter);
      File_Node := Code_Analysis.File_Access
        (GType_File.Get (Gtk_Tree_Store (View.Model), Iter, File_Col));
      Open_File_Editor (Code_Analysis_Module_ID.Kernel, File_Node.Name);
      Remove_Coverage_Annotations (File_Node);
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end Remove_Coverage_Annotations_From_Report;

   ----------------------------------------------
   -- Remove_Coverage_Annotations_From_Context --
   ----------------------------------------------

   procedure Remove_Coverage_Annotations_From_Context
     (Widget      : access Glib.Object.GObject_Record'Class;
      Cont_N_Inst : Context_And_Instance)
   is
      Property     : Code_Analysis_Property_Record
        := Code_Analysis_Property_Record
          (Get_Property (Cont_N_Inst.Instance, Code_Analysis_Cst_Str));
      Project_Node : Project_Access;
      File_Node    : Code_Analysis.File_Access;
      pragma Unreferenced (Widget);
   begin
      Project_Node := Get_Or_Create
        (Property.Projects, Project_Information (Cont_N_Inst.Context));
      File_Node := Get_Or_Create
        (Project_Node, File_Information (Cont_N_Inst.Context));
      Open_File_Editor (Code_Analysis_Module_ID.Kernel, File_Node.Name);
      Remove_Coverage_Annotations (File_Node);
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end Remove_Coverage_Annotations_From_Context;

   ---------------------------------
   -- Remove_Coverage_Annotations --
   ---------------------------------

   procedure Remove_Coverage_Annotations
     (File_Node : Code_Analysis.File_Access) is
   begin
      Remove_Line_Information_Column
        (Code_Analysis_Module_ID.Kernel,
         File_Node.Name,
         "Coverage Icons");
      Remove_Line_Information_Column
        (Code_Analysis_Module_ID.Kernel,
         File_Node.Name,
         "Coverage Analysis");
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end Remove_Coverage_Annotations;

   ---------------------------------------------------
   -- List_Lines_Not_Covered_In_Project_From_Report --
   ---------------------------------------------------

   procedure List_Lines_Not_Covered_In_Project_From_Report
     (Object : access Gtk_Widget_Record'Class)
   is
      View  : constant Code_Analysis_View := Code_Analysis_View (Object);
      Iter  : Gtk_Tree_Iter;
      Project_Node : Project_Access;
   begin
      Get_Selected
        (Get_Selection (View.Tree), Gtk_Tree_Model (View.Model), Iter);
      Project_Node := Project_Access
        (GType_Project.Get (Gtk_Tree_Store (View.Model), Iter, Node_Col));
      List_Lines_Not_Covered_In_Project (Project_Node);
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end List_Lines_Not_Covered_In_Project_From_Report;

   ----------------------------------------------------
   -- List_Lines_Not_Covered_In_Project_From_Context --
   ----------------------------------------------------

   procedure List_Lines_Not_Covered_In_Project_From_Context
     (Widget      : access Glib.Object.GObject_Record'Class;
      Cont_N_Inst : Context_And_Instance)
   is
      Property     : Code_Analysis_Property_Record
        := Code_Analysis_Property_Record
          (Get_Property (Cont_N_Inst.Instance, Code_Analysis_Cst_Str));
      Project_Node : Project_Access;
      pragma Unreferenced (Widget);
   begin
      Project_Node := Get_Or_Create
        (Property.Projects, Project_Information (Cont_N_Inst.Context));
      List_Lines_Not_Covered_In_Project (Project_Node);
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end List_Lines_Not_Covered_In_Project_From_Context;

   ------------------------------------------------
   -- List_Lines_Not_Covered_In_File_From_Report --
   ------------------------------------------------

   procedure List_Lines_Not_Covered_In_File_From_Report
     (Object : access Gtk_Widget_Record'Class)
   is
      View      : constant Code_Analysis_View := Code_Analysis_View (Object);
      Iter      : Gtk_Tree_Iter;
      File_Node : Code_Analysis.File_Access;
   begin
      Get_Selected
        (Get_Selection (View.Tree), Gtk_Tree_Model (View.Model), Iter);
      File_Node := Code_Analysis.File_Access
        (GType_File.Get (Gtk_Tree_Store (View.Model), Iter, File_Col));
      Open_File_Editor (Code_Analysis_Module_ID.Kernel, File_Node.Name);
      List_Lines_Not_Covered_In_File (File_Node);
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end List_Lines_Not_Covered_In_File_From_Report;

   -------------------------------------------------
   -- List_Lines_Not_Covered_In_File_From_Context --
   -------------------------------------------------

   procedure List_Lines_Not_Covered_In_File_From_Context
     (Widget      : access Glib.Object.GObject_Record'Class;
      Cont_N_Inst : Context_And_Instance)
   is
      Property     : Code_Analysis_Property_Record
        := Code_Analysis_Property_Record
          (Get_Property (Cont_N_Inst.Instance, Code_Analysis_Cst_Str));
      Project_Node : Project_Access;
      File_Node    : Code_Analysis.File_Access;
      pragma Unreferenced (Widget);
   begin
      Project_Node := Get_Or_Create
        (Property.Projects, Project_Information (Cont_N_Inst.Context));
      File_Node := Get_Or_Create
        (Project_Node, File_Information (Cont_N_Inst.Context));
      Open_File_Editor (Code_Analysis_Module_ID.Kernel, File_Node.Name);
      List_Lines_Not_Covered_In_File (File_Node);
   exception
      when E : others =>
         Trace (Exception_Handle,
                "Unexpected exception: " & Exception_Information (E));
   end List_Lines_Not_Covered_In_File_From_Context;

   ---------------------------------------
   -- List_Lines_Not_Covered_In_Project --
   ---------------------------------------

   procedure List_Lines_Not_Covered_In_Project
     (Project_Node : Project_Access)
   is
      use File_Maps;
      Map_Cur  : File_Maps.Cursor := Project_Node.Files.First;
      Sort_Arr : Code_Analysis.File_Array
        (1 .. Integer (Project_Node.Files.Length));
   begin
      for J in Sort_Arr'Range loop
         Sort_Arr (J) := Element (Map_Cur);
         Next (Map_Cur);
      end loop;

      Sort_Files (Sort_Arr);

      for J in Sort_Arr'Range loop
         if Sort_Arr (J).Analysis_Data.Coverage_Data /= null then
            List_Lines_Not_Covered_In_File (Sort_Arr (J));
         end if;
      end loop;
   end List_Lines_Not_Covered_In_Project;

   ------------------------------------
   -- List_Lines_Not_Covered_In_File --
   ------------------------------------

   procedure List_Lines_Not_Covered_In_File
     (File_Node : Code_Analysis.File_Access) is
   begin
      for J in File_Node.Lines'Range loop
         if File_Node.Lines (J) /= Null_Line then
            if File_Node.Lines (J).Analysis_Data.Coverage_Data.Coverage
              = 0 then
               Insert_Location
                 (Kernel    => Code_Analysis_Module_ID.Kernel,
                  Category  => Coverage_Category,
                  File      => File_Node.Name,
                  Text      => File_Node.Lines (J).Contents.all,
                  Line      => J,
                  Column    => 1,
                  Highlight => True,
                  Highlight_Category => Builder_Warnings_Style);
            end if;
         end if;
      end loop;
   end List_Lines_Not_Covered_In_File;

   ----------------------------
   -- Expand_All_From_Report --
   ----------------------------

   procedure Expand_All_From_Report (Object : access Gtk_Widget_Record'Class)
   is
      View : constant Code_Analysis_View := Code_Analysis_View (Object);
   begin
      Expand_All (View.Tree);
   end Expand_All_From_Report;

   ------------------------------
   -- Collapse_All_From_Report --
   ------------------------------

   procedure Collapse_All_From_Report (Object : access Gtk_Widget_Record'Class)
   is
      View : constant Code_Analysis_View := Code_Analysis_View (Object);
   begin
      Collapse_All (View.Tree);
   end Collapse_All_From_Report;

   --------------------
   -- Show_Full_Tree --
   --------------------

   procedure Show_Full_Tree (Object : access Gtk_Widget_Record'Class)
   is
      View : constant Code_Analysis_View := Code_Analysis_View (Object);
      Iter : Gtk_Tree_Iter := Get_Iter_First (View.Model);
      Path : Gtk_Tree_Path;
   begin
      Clear (View.Model);
      Fill_Iter (View.Model, Iter, View.Projects);
      Iter := Get_Iter_First (View.Model);
      Path := Get_Path (View.Model, Iter);
      Collapse_All (View.Tree);
      Expand_To_Path (View.Tree, Path);
      Select_Path (Get_Selection (View.Tree), Path);
      Path_Free (Path);
   end Show_Full_Tree;

   -----------------------------
   -- Show_Flat_List_Of_Files --
   -----------------------------

   procedure Show_Flat_List_Of_Files (Object : access Gtk_Widget_Record'Class)
   is
      View : constant Code_Analysis_View := Code_Analysis_View (Object);
      Iter : Gtk_Tree_Iter := Get_Iter_First (View.Model);
   begin
      Clear (View.Model);
      Fill_Iter_With_Files (View.Model, Iter, View.Projects);
   end Show_Flat_List_Of_Files;

   -----------------------------------
   -- Show_Flat_List_Of_Subprograms --
   -----------------------------------

   procedure Show_Flat_List_Of_Subprograms
     (Object : access Gtk_Widget_Record'Class)
   is
      View : constant Code_Analysis_View := Code_Analysis_View (Object);
      Iter : Gtk_Tree_Iter := Get_Iter_First (View.Model);
   begin
      Clear (View.Model);
      Fill_Iter_With_Subprograms (View.Model, Iter, View.Projects);
   end Show_Flat_List_Of_Subprograms;

   -----------------------------
   -- Contextual menu entries --
   -----------------------------

   ------------------
   -- Context_Func --
   ------------------

   procedure Context_Func
     (Context      : in out Selection_Context;
      Kernel       : access Kernel_Handle_Record'Class;
      Event_Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Object       : access Glib.Object.GObject_Record'Class;
      Event        : Gdk_Event;
      Menu         : Gtk_Menu)
   is
      pragma Unreferenced (Kernel, Event_Widget, Context);
      View      : constant Code_Analysis_View := Code_Analysis_View (Object);
      X         : constant Gdouble := Get_X (Event);
      Y         : constant Gdouble := Get_Y (Event);
      Path      : Gtk_Tree_Path;
      Column    : Gtk_Tree_View_Column;
      Buffer_X  : Gint;
      Buffer_Y  : Gint;
      Row_Found : Boolean;
      Item      : Gtk_Menu_Item;
      Iter      : constant Gtk_Tree_Iter := Get_Iter_First (View.Model);
   begin

      Get_Path_At_Pos
        (View.Tree,
         Gint (X),
         Gint (Y),
         Path,
         Column,
         Buffer_X,
         Buffer_Y,
         Row_Found);

      if Path /= null then
         Select_Path (Get_Selection (View.Tree), Path);

         if Get_Depth (Path) > 1 or else not Has_Child (View.Model, Iter) then
            Gtk_New (Item, -"Add coverage annotations");
            Gtkada.Handlers.Widget_Callback.Object_Connect
              (Item, "activate", Add_Coverage_Annotations_From_Report'Access,
               View, After => False);
            Append (Menu, Item);
            Gtk_New (Item, -"Remove coverage annotations");
            Gtkada.Handlers.Widget_Callback.Object_Connect
              (Item, "activate",
               Remove_Coverage_Annotations_From_Report'Access,
               View, After => False);
            Append (Menu, Item);
         end if;

         if Get_Depth (Path) = 1 and then Has_Child (View.Model, Iter) then
            Gtk_New (Item, -"List lines not covered");
            Gtkada.Handlers.Widget_Callback.Object_Connect
              (Item, "activate",
               List_Lines_Not_Covered_In_Project_From_Report'Access,
               View, After => False);
            Append (Menu, Item);
         else
            Gtk_New (Item, -"List lines not covered");
            Gtkada.Handlers.Widget_Callback.Object_Connect
              (Item, "activate",
               List_Lines_Not_Covered_In_File_From_Report'Access,
               View, After => False);
            Append (Menu, Item);
         end if;

         Gtk_New (Item);
         Append (Menu, Item);
      end if;

      Gtk_New (Item, -"Show flat list of files");
      Gtkada.Handlers.Widget_Callback.Object_Connect
        (Item, "activate", Show_Flat_List_Of_Files'Access,
         View, After => False);
      Append (Menu, Item);
      Gtk_New (Item, -"Show flat list of subprograms");
      Gtkada.Handlers.Widget_Callback.Object_Connect
        (Item, "activate", Show_Flat_List_Of_Subprograms'Access,
         View, After => False);
      Append (Menu, Item);

      if not Has_Child (View.Model, Iter) then
         Gtk_New (Item, -"Show full tree");
         Gtkada.Handlers.Widget_Callback.Object_Connect
           (Item, "activate", Show_Full_Tree'Access,
            View, After => False);
         Append (Menu, Item);
      else
         Gtk_New (Item);
         Append (Menu, Item);
         Gtk_New (Item, -"Expand all");
         Gtkada.Handlers.Widget_Callback.Object_Connect
           (Item, "activate", Expand_All_From_Report'Access,
            View, After => False);
         Append (Menu, Item);
         Gtk_New (Item, -"Collapse all");
         Gtkada.Handlers.Widget_Callback.Object_Connect
           (Item, "activate", Collapse_All_From_Report'Access,
            View, After => False);
         Append (Menu, Item);
      end if;
   end Context_Func;

   ------------------------------
   -- Filter_Matches_Primitive --
   ------------------------------

   function Filter_Matches_Primitive
     (Filter  : access Has_Coverage_Filter;
      Context : Selection_Context) return Boolean
   is
      pragma Unreferenced (Filter);
   begin
      return (Has_Project_Information (Context) or else
        Has_File_Information (Context) or else
          (Has_Entity_Name_Information (Context) and then
           Is_Subprogram (Get_Entity (Context))));
   end Filter_Matches_Primitive;

   --------------------
   -- Append_To_Menu --
   --------------------

   procedure Append_To_Menu
     (Factory : access Code_Analysis_Contextual_Menu;
      Object  : access Glib.Object.GObject_Record'Class;
      Context : Selection_Context;
      Menu    : access Gtk.Menu.Gtk_Menu_Record'Class)
   is
      use Code_Analysis_Class_Instance_Sets;
      pragma Unreferenced (Factory, Object);
      Cont_N_Inst  : Context_And_Instance;
      Property     : Code_Analysis_Property_Record;
      Project_Node : Project_Access;
      Submenu      : Gtk_Menu;
      Item         : Gtk_Menu_Item;
      Cur          : Cursor := Code_Analysis_Module_ID.Instances.First;
   begin
      Cont_N_Inst.Context := Context;

      loop
         exit when Cur = No_Element;

         Cont_N_Inst.Instance := Element (Cur);
         Property             := Code_Analysis_Property_Record
           (Get_Property (Cont_N_Inst.Instance, Code_Analysis_Cst_Str));
         Project_Node         := Get_Or_Create
           (Property.Projects, Project_Information (Cont_N_Inst.Context));

         if Code_Analysis_Module_ID.Instances.Length > 1 then
            Gtk_New (Item, -(Property.Instance_Name.all));
            Append (Menu, Item);
            Gtk_New (Submenu);
            Set_Submenu (Item, Submenu);
            Set_Sensitive (Item, True);
            Append_To_Contextual_Submenu (Cont_N_Inst, Submenu, Project_Node);
         else
            Append_To_Contextual_Submenu (Cont_N_Inst, Menu, Project_Node);
         end if;

         Next (Cur);
      end loop;
   end Append_To_Menu;

   ----------------------------------
   -- Append_To_Contextual_Submenu --
   ----------------------------------

   procedure Append_To_Contextual_Submenu
     (Cont_N_Inst  : Context_And_Instance;
      Submenu      : access Gtk_Menu_Record'Class;
      Project_Node : Project_Access) is
   begin
      if Has_File_Information (Cont_N_Inst.Context) then
         declare
            File_Node : constant Code_Analysis.File_Access := Get_Or_Create
              (Project_Node, File_Information (Cont_N_Inst.Context));
         begin
            Append_File_Menu_Entries (Cont_N_Inst, Submenu, File_Node);
         end;
      else
            Append_Project_Menu_Entries (Cont_N_Inst, Submenu, Project_Node);
      end if;
   end Append_To_Contextual_Submenu;

   ------------------------------
   -- Append_File_Menu_Entries --
   ------------------------------

   procedure Append_File_Menu_Entries
     (Cont_N_Inst   : Context_And_Instance;
      Submenu       : access Gtk_Menu_Record'Class;
      File_Node     : Code_Analysis.File_Access;
      Is_Contextual : Boolean := True)
   is
      Item : Gtk_Menu_Item;
   begin
      if File_Node.Analysis_Data.Coverage_Data /= null then
         Gtk_New (Item, -"Reload data for " &
                  Locale_Base_Name (File_Information (Cont_N_Inst.Context)));
         Append (Submenu, Item);
         Context_And_Instance_CB.Connect
           (Item, "activate", Context_And_Instance_CB.To_Marshaller
              (Add_Gcov_File_Info_From_Context'Access), Cont_N_Inst);
         Gtk_New (Item, -"Add coverage annotations");
         Append (Submenu, Item);
         Context_And_Instance_CB.Connect
           (Item, "activate", Context_And_Instance_CB.To_Marshaller
              (Add_Coverage_Annotations_From_Context'Access), Cont_N_Inst);
         Gtk_New (Item, -"Remove coverage annotations");
         Append (Submenu, Item);
         Context_And_Instance_CB.Connect
           (Item, "activate", Context_And_Instance_CB.To_Marshaller
              (Remove_Coverage_Annotations_From_Context'Access), Cont_N_Inst);
         Gtk_New (Item, -"List lines not covered");
         Append (Submenu, Item);
         Context_And_Instance_CB.Connect
           (Item, "activate", Context_And_Instance_CB.To_Marshaller
              (List_Lines_Not_Covered_In_File_From_Context'Access),
            Cont_N_Inst);

         if Is_Contextual then
            Append_Show_Analysis_Report_To_Context (Cont_N_Inst, Submenu);
         end if;
      else
         Gtk_New (Item, -"Load data for " &
                  Locale_Base_Name (File_Information (Cont_N_Inst.Context)));
         Append (Submenu, Item);
         Context_And_Instance_CB.Connect
           (Item, "activate", Context_And_Instance_CB.To_Marshaller
              (Add_Gcov_File_Info_From_Context'Access), Cont_N_Inst);
      end if;
   end Append_File_Menu_Entries;

   ---------------------------------
   -- Append_Project_Menu_Entries --
   ---------------------------------

   procedure Append_Project_Menu_Entries
     (Cont_N_Inst  : Context_And_Instance;
      Submenu      : access Gtk_Menu_Record'Class;
      Project_Node : Project_Access;
      Is_Contextual : Boolean := True)
   is
      Item : Gtk_Menu_Item;
   begin
      if Project_Node.Analysis_Data.Coverage_Data /= null then
         Gtk_New (Item, -"Reload data for project " &
                  Project_Name (Project_Information (Cont_N_Inst.Context)));
         Append (Submenu, Item);
         Context_And_Instance_CB.Connect
           (Item, "activate", Context_And_Instance_CB.To_Marshaller
              (Add_Gcov_Project_Info_From_Context'Access), Cont_N_Inst);
         Gtk_New (Item, -"List lines not covered");
         Append (Submenu, Item);
         Context_And_Instance_CB.Connect
           (Item, "activate", Context_And_Instance_CB.To_Marshaller
              (List_Lines_Not_Covered_In_Project_From_Context'Access),
            Cont_N_Inst);

         if Is_Contextual then
            Append_Show_Analysis_Report_To_Context (Cont_N_Inst, Submenu);
         else
            Append_Show_Analysis_Report_To_Menu (Cont_N_Inst, Submenu);
         end if;
      else
         Gtk_New (Item, -"Load data for project " &
                  Project_Name (Project_Information (Cont_N_Inst.Context)));
         Append (Submenu, Item);
         Context_And_Instance_CB.Connect
           (Item, "activate", Context_And_Instance_CB.To_Marshaller
              (Add_Gcov_Project_Info_From_Context'Access), Cont_N_Inst);
      end if;
   end Append_Project_Menu_Entries;

   ------------------
   -- Menu entries --
   ------------------

   --------------------------------
   -- Dynamic_Tools_Menu_Factory --
   --------------------------------

   procedure Dynamic_Tools_Menu_Factory
     (Kernel  : access Kernel_Handle_Record'Class;
      Context : Selection_Context;
      Menu    : access Gtk.Menu.Gtk_Menu_Record'Class)
   is
      use Code_Analysis_Class_Instance_Sets;
      Cont_N_Inst  : Context_And_Instance;
      Property     : Code_Analysis_Property_Record;
      Project_Node : Project_Access;
      Submenu      : Gtk_Menu;
      Item         : Gtk_Menu_Item;
      Cur          : Cursor := Code_Analysis_Module_ID.Instances.First;
   begin

      if Context = No_Context then
         Cont_N_Inst.Context := Get_Current_Context (Kernel);
      else
         Cont_N_Inst.Context := Context;
      end if;

      loop
         exit when Cur = No_Element;
         Cont_N_Inst.Instance := Element (Cur);
         Property             := Code_Analysis_Property_Record
           (Get_Property (Cont_N_Inst.Instance, Code_Analysis_Cst_Str));
         Project_Node         := Get_Or_Create
           (Property.Projects, Get_Project (Code_Analysis_Module_ID.Kernel));

         if Code_Analysis_Module_ID.Instances.Length > 1 then
            Gtk_New (Item, -(Property.Instance_Name.all));
            Append (Menu, Item);
            Gtk_New (Submenu);
            Set_Submenu (Item, Submenu);
            Set_Sensitive (Item, True);
            Append_To_Submenu (Cont_N_Inst, Submenu, Project_Node);
         else
            Append_To_Submenu (Cont_N_Inst, Menu, Project_Node);
         end if;

         Next (Cur);
      end loop;

      Gtk_New (Item, -"Create code analysis instance");
      Append (Menu, Item);
      Gtkada.Handlers.Widget_Callback.Connect
        (Item, "activate", Create_From_Menu'Access);
   end Dynamic_Tools_Menu_Factory;

   --------------------------------
   -- Dynamic_Views_Menu_Factory --
   --------------------------------

   procedure Dynamic_Views_Menu_Factory
     (Kernel  : access Kernel_Handle_Record'Class;
      Context : Selection_Context;
      Menu    : access Gtk.Menu.Gtk_Menu_Record'Class)
   is
      use Code_Analysis_Class_Instance_Sets;

      procedure Has_Coverage_Information
        (Cont_N_Inst : Context_And_Instance;
         Property    : Code_Analysis_Property_Record;
         Menu        : access Gtk.Menu.Gtk_Menu_Record'Class);
      --  Check if coverage informations are stored in the given Instance and
      --  and fills the given Gtk_Menu with different contents following the
      --  case

      ------------------------------
      -- Has_Coverage_Information --
      ------------------------------

      procedure Has_Coverage_Information
        (Cont_N_Inst : Context_And_Instance;
         Property    : Code_Analysis_Property_Record;
         Menu        : access Gtk.Menu.Gtk_Menu_Record'Class)
      is
         Project_Node : Code_Analysis.Project_Access;
         Item         : Gtk_Menu_Item;
      begin
         Project_Node := Get_Or_Create
           (Property.Projects, Project_Information (Cont_N_Inst.Context));

         if Project_Node.Analysis_Data.Coverage_Data /= null then
            Append_Show_Analysis_Report_To_Menu (Cont_N_Inst, Menu);
         else
            Gtk_New (Item, -"You should load information in this coverage" &
                     " instance using the Tools/Coverage menu before.");
            Append (Menu, Item);
         end if;
      end Has_Coverage_Information;

      Cont_N_Inst : Context_And_Instance;
      Property    : Code_Analysis_Property_Record;
      Submenu     : Gtk_Menu;
      Item        : Gtk_Menu_Item;
      Cur         : Cursor := Code_Analysis_Module_ID.Instances.First;
   begin

      if Context = No_Context then
         Cont_N_Inst.Context := Get_Current_Context (Kernel);
      else
         Cont_N_Inst.Context := Context;
      end if;

      if Cur = No_Element then
         Gtk_New (Item, -"You should create a coverage instance using the" &
                  " Tools/Coverage menu before.");
         Append (Menu, Item);
         return;
      end if;

      loop
         exit when Cur = No_Element;
         Cont_N_Inst.Instance := Element (Cur);
         Property             := Code_Analysis_Property_Record
           (Get_Property (Cont_N_Inst.Instance, Code_Analysis_Cst_Str));

         if Code_Analysis_Module_ID.Instances.Length > 1 then
            Gtk_New (Item, -(Property.Instance_Name.all));
            Append (Menu, Item);
            Gtk_New (Submenu);
            Set_Submenu (Item, Submenu);
            Set_Sensitive (Item, True);
            Has_Coverage_Information (Cont_N_Inst, Property, Submenu);
         else
            Has_Coverage_Information (Cont_N_Inst, Property, Menu);
         end if;

         Next (Cur);
      end loop;
   end Dynamic_Views_Menu_Factory;

   -----------------------
   -- Append_To_Submenu --
   -----------------------

   procedure Append_To_Submenu
     (Cont_N_Inst  : Context_And_Instance;
      Submenu      : access Gtk_Menu_Record'Class;
      Project_Node : Project_Access) is
   begin
      Append_Project_Menu_Entries (Cont_N_Inst, Submenu, Project_Node, False);

      if Has_File_Information (Cont_N_Inst.Context) then
         declare
            File_Node : constant Code_Analysis.File_Access := Get_Or_Create
              (Project_Node, File_Information (Cont_N_Inst.Context));
            Item      : Gtk_Menu_Item;
         begin
            Gtk_New (Item);
            Append (Submenu, Item);
            Append_File_Menu_Entries (Cont_N_Inst, Submenu, File_Node, False);
         end;
      end if;
   end Append_To_Submenu;

   --------------------------------------------
   -- Append_Show_Analysis_Report_To_Context --
   --------------------------------------------

   procedure Append_Show_Analysis_Report_To_Context
     (Cont_N_Inst : Context_And_Instance;
      Submenu     : access Gtk_Menu_Record'Class)
   is
      Item : Gtk_Menu_Item;
   begin
      Gtk_New (Item, -"Show Analysis Report");
      Append (Submenu, Item);
      Context_And_Instance_CB.Connect
        (Item, "activate", Context_And_Instance_CB.To_Marshaller
           (Show_Analysis_Report_From_Context'Access), Cont_N_Inst);
   end Append_Show_Analysis_Report_To_Context;

   -----------------------------------------
   -- Append_Show_Analysis_Report_To_Menu --
   -----------------------------------------

   procedure Append_Show_Analysis_Report_To_Menu
     (Cont_N_Inst : Context_And_Instance;
      Submenu     : access Gtk_Menu_Record'Class)
   is
      Item : Gtk_Menu_Item;
   begin
      Gtk_New (Item, -"Show Analysis Report");
      Append (Submenu, Item);
      Context_And_Instance_CB.Connect
        (Item, "activate", Context_And_Instance_CB.To_Marshaller
           (Show_Analysis_Report_From_Menu'Access), Cont_N_Inst);
   end Append_Show_Analysis_Report_To_Menu;

   ---------------------------
   -- Less_Case_Insensitive --
   ---------------------------

   function Less_Case_Insensitive (Left, Right : Class_Instance) return Boolean
   is
      Property_Left      : Code_Analysis_Property_Record;
      Property_Right     : Code_Analysis_Property_Record;
      Miss_Instance_Name : exception;
   begin
      Property_Left := Code_Analysis_Property_Record
        (Get_Property (Left, Code_Analysis_Cst_Str));
      Property_Right := Code_Analysis_Property_Record
        (Get_Property (Right, Code_Analysis_Cst_Str));

      if Property_Left.Instance_Name = null then
         raise Miss_Instance_Name with "Property_Left.Instance_Name is null";
      end if;

      if Property_Right.Instance_Name = null then
         raise Miss_Instance_Name with "Property_Right.Instance_Name is null";
      end if;

      return Ada.Strings.Less_Case_Insensitive
        (Property_Left.Instance_Name.all, Property_Right.Instance_Name.all);
   end Less_Case_Insensitive;

   ----------------------------
   -- Equal_Case_Insensitive --
   ----------------------------

   function Equal_Case_Insensitive
     (Left, Right : Class_Instance) return Boolean
   is
      Property_Left      : Code_Analysis_Property_Record;
      Property_Right     : Code_Analysis_Property_Record;
      Miss_Instance_Name : exception;
   begin
      Property_Left := Code_Analysis_Property_Record
        (Get_Property (Left, Code_Analysis_Cst_Str));
      Property_Right := Code_Analysis_Property_Record
        (Get_Property (Right, Code_Analysis_Cst_Str));

      if Property_Left.Instance_Name = null then
         raise Miss_Instance_Name with "Property_Left.Instance_Name is null";
      end if;

      if Property_Right.Instance_Name = null then
         raise Miss_Instance_Name with "Property_Right.Instance_Name is null";
      end if;

      return Ada.Strings.Equal_Case_Insensitive
        (Property_Left.Instance_Name.all, Property_Right.Instance_Name.all);
   end Equal_Case_Insensitive;

   ---------------------
   -- Register_Module --
   ---------------------

   procedure Register_Module
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
   is
      Code_Analysis_Class : constant Class_Type :=
                              New_Class (Kernel, Code_Analysis_Cst_Str);
      Contextual_Menu     : Code_Analysis_Contextual_Menu_Access;
   begin
      Code_Analysis_Module_ID := new Code_Analysis_Module_ID_Record;
      Code_Analysis_Module_ID.Kernel := Kernel_Handle (Kernel);
      Code_Analysis_Module_ID.Class  := Code_Analysis_Class;
      Contextual_Menu := new Code_Analysis_Contextual_Menu;
      Register_Contextual_Submenu
        (Kernel  => Code_Analysis_Module_ID.Kernel,
         Name    => -"Coverage",
         Filter  => new Has_Coverage_Filter,
         Submenu => Submenu_Factory (Contextual_Menu));
      Register_Dynamic_Menu
        (Kernel      => Kernel,
         Parent_Path => '/' & (-"Tools"),
         Text        => -"Covera_ge",
         Ref_Item    => -"Documentation",
         Add_Before  => False,
         Factory     => Dynamic_Tools_Menu_Factory'Access);
      Register_Dynamic_Menu
        (Kernel      => Kernel,
         Parent_Path => '/' & (-"Tools" & ('/' & (-"Views"))),
         Text        => -"Covera_ge",
         Ref_Item    => -"Clipboard",
         Add_Before  => False,
         Factory     => Dynamic_Views_Menu_Factory'Access);
      Register_Module
        (Module      => Code_Analysis_Module_ID,
         Kernel      => Kernel,
         Module_Name => Code_Analysis_Cst_Str);
      Register_Command
        (Kernel, Constructor_Method,
         Class        => Code_Analysis_Class,
         Handler      => Create'Access);
      Register_Command
        (Kernel, "add_gcov_project_info",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Class        => Code_Analysis_Class,
         Handler      => Add_Gcov_Project_Info_From_Shell'Access);
      Register_Command
        (Kernel, "add_gcov_file_info",
         Minimum_Args => 2,
         Maximum_Args => 2,
         Class        => Code_Analysis_Class,
         Handler      => Add_Gcov_File_Info_From_Shell'Access);
      Register_Command
        (Kernel, "list_lines_not_covered",
         Class        => Code_Analysis_Class,
         Handler      => List_Lines_Not_Covered_From_Shell'Access);
      Register_Command
        (Kernel, "show_analysis_report",
         Class        => Code_Analysis_Class,
         Handler      => Show_Analysis_Report_From_Shell'Access);
      Register_Command
        (Kernel, Destructor_Method,
         Class        => Code_Analysis_Class,
         Handler      => Destroy'Access);
   end Register_Module;

end Code_Analysis_Module;
