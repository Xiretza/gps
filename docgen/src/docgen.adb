with Ada.Command_Line;          use Ada.Command_Line;
with Ada.Text_IO;               use Ada.Text_IO;
with GNAT.OS_Lib;               use GNAT.OS_Lib;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with Language;                  use Language;
with Language.Ada;              use Language.Ada;
with String_Utils;              use String_Utils;
with Ada.Characters.Handling;   use Ada.Characters.Handling;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Exceptions;
with Ada.IO_Exceptions;


with Generic_List;
with Work_on_File;              use Work_on_File;
with Work_on_Source;            use Work_on_Source;
with Doc_Types;                 use Doc_Types;

with Html_Output;               use Html_Output;
with Texi_Output;               use Texi_Output;

procedure docgen is

   package ASU renames Ada.Strings.Unbounded;
   package TSFL renames Type_Source_File_List;

   Help_Requested : exception;
   --raised when the help option was used. no need to go on!
   Command_Line_Error : exception;
   --this is a  second comment

   Version      : constant String := "0.1";

   Source_File_List   : Type_Source_File_List.List;
   Prj_File_Name      : String_Access;
   Options            : All_Options;

   type Package_Info is record
      Package_Name : String_Access;
      Line         : Integer;
   end record;


   ----------------------
   -- Get_Package_Name --
   ----------------------

   function Get_Package_Name
     (File_Name : String) return Package_Info is
      --extracts the package name from the given source file
      File                 : File_Type;
      Last, Index1, Index2 : Natural;
      Line_Nr              : Integer;
      Line_From_File       : String (1..Max_Line_Length);
      Package_Name_Found   : Boolean;
      Result               : Package_Info;
   begin
      Package_Name_Found := false;
      Open (File, In_File, File_Name);
      Line_Nr := 1;

      --look for the first word "package" in the file
      --and return the identifier behind
      while not Package_Name_Found and not End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line_From_File, Last);
         declare
            New_Line : String := Line_From_File (1 .. Last);
         begin
            Line_Nr := Line_Nr + 1;
            Index1 := Get_String_Index (To_Lower(New_Line), 1, "package");
            Index2 := Get_String_Index (New_Line, 1, "--");
            if (Index1 > 0) and
              ((Index2 = 0) or (Index1 < Index2)) then
               Index1 := Index1 + 7;
               Skip_Blanks (New_Line, Index1, 1);
               Index2 := Index1;
               Skip_To_Char (New_Line, Index2, ' ');
                Put_Line ("Package name found:   *" &
                              New_Line (Index1 .. Index2-1) & "*");
               if Options.Info_Output then
                  Put_Line ("Package name found:   *" &
                              New_Line (Index1 .. Index2-1) & "*");
               end if;
               close (File);

               Result := (Package_Name => new String'(New_Line
                         (Index1 .. Index2-1)), Line => Line_Nr - 1);
               return Result;
            end if;
         end;
      end loop;
      close (File);
      Put_Line ("ERROR: Package Definition not found!!!");  --later exception!
      return Result;
   end Get_Package_Name;


   -------------------------
   -- Handle_Command_Line --
   -------------------------

   procedure Handle_Command_Line
     (Quit : out Boolean)
   is
      use Ada.Command_Line;

      File_Name_Set    : Boolean     := False;
      J                : Natural     := 1;
      N                : Natural     := Argument_Count;
      Print_Version    : Boolean     := False;
      Source_File_Node : Source_File_Information;
      New_Package      : Package_Info;

   begin
      if N = 0 then raise Help_Requested;
      end if;
      Quit := False;
      while J <= N loop
         declare
            S : String := Argument (J);
         begin

            --if options for other output formats, define here!
            Options.Doc_Subprogram := Doc_HTML_Create'Access;
            Options.Doc_Suffix     := new String'(".htm");
            Options.Doc_One_File   := false;

            if S = "-h"    or else S = "-?" or else
               S = "-help" or else S = "--help"
            then
               raise Help_Requested;
            elsif S = "-texi" then
               Options.Doc_Subprogram := Doc_TEXI_Create'Access;
               Options.Doc_Suffix     := new String'(".texi");
               Options.Doc_One_File   := true;
            elsif S = "-body" then
               Options.Process_Body_Files := true;
            elsif S = "-ic" then
               Options.Ignorable_Comments := true;
            elsif S = "-under" then
               Options.Comments_Under := true;
            elsif S = "-info" then
               Options.Info_Output := true;
            elsif S = "-private" then
               Options.Show_Private := true;
            elsif S (1..9) = "-docpath=" and S'Last > 9 then
               Options.Doc_Directory := new String '(S (10 .. S'Last));
            elsif S'Length > 5 then
               if S (S'Last - 3 .. S'Last) = ".gpr" then
                  if Prj_File_Name /= null then
                     raise Help_Requested;
                  else
                     Prj_File_Name := new String'(S);
                  end if;
               elsif S (S'Last - 3 .. S'Last) = ".ads" then
                     if Prj_File_Name /= null then
                        Source_File_Node.File_Name := new String'(S);
                        Source_File_Node.Prj_File_Name := Prj_File_Name;
                        New_Package                   := Get_Package_Name(S);
                        Source_File_Node.Package_Name :=
                           New_Package.Package_Name;
                        Source_File_Node.Def_In_Line  := New_Package.Line;

                        Source_File_Node.Other_File_Found := true;
                     Type_Source_File_List.Append (Source_File_List,
                                                   Source_File_Node);
                     else
                        raise Command_Line_Error;
                  end if;
	       end if;
            end if;
         end;
         J := J + 1;
      end loop;

      --check if at least one source_file_name exist
      if Type_Source_File_List.Length (Source_File_List) = 0 then
         raise Command_Line_Error;
      end if;


   exception
      when Command_Line_Error =>
         --Check the remaining arguments if there's a help option
         --somewhere. If so, translate this into a Help_Requested.
         J := J + 1;
         while J <= N loop
            declare
               S : String := Argument (J);
            begin
               exit when S = "-?"    or else S = "-h" or else
                         S = "-help" or else S = "--help";
            end;
            J := J + 1;
         end loop;
         if J <= N then
            raise Help_Requested;
         else
            raise;
         end if;
   end Handle_Command_Line;


   --------------------
   -- Add_Body_Files --
   --------------------

   procedure Add_Body_Files
     (Source_File_List : in out Type_Source_File_List.List) is
      --add to the list the body files of the spec files in the list

      Source_File_Node : Type_Source_File_List.List_Node;
      New_Node         : Source_File_Information;
      New_Filename     : ASU.Unbounded_String;
      New_Package      : Package_Info;
      --add a .adb file for each .ads file found in the list
   begin
      Source_File_Node := TSFL.First (Source_File_List);
      for J in 1..Type_Source_File_List.Length(Source_File_List) loop

         --only if the .adb file really exists
         if TSFL.Data (Source_File_Node).Other_File_Found then

            New_Filename := ASU.To_Unbounded_String
              (TSFL.Data (Source_File_Node).File_Name.all);
            New_Filename := ASU.Replace_Slice
              (New_Filename,
               ASU.Index(New_Filename, "."),
               ASU.Index(New_Filename, ".") + 3, ".adb");
            if Options.Info_Output then
               Put_Line ("Adding file: " & ASU.To_String(New_Filename));
            end if;

            New_Node.File_Name         :=
              new String'(ASU.To_String(New_Filename));
            New_Node.Prj_File_Name     :=
              new String'(TSFL.Data (Source_File_Node).Prj_File_Name.all);
            New_Package := Get_Package_Name
              (TSFL.Data (Source_File_Node).File_Name.all);
            New_Node.Package_Name      := New_Package.Package_Name;
            New_Node.Def_In_Line       := New_Package.Line;
            Type_Source_File_List.Append (Source_File_List, New_Node);

         end if;

         Source_File_Node := TSFL.Next (Source_File_Node);
      end loop;

      if Options.Info_Output then
         Put_Line ("The files in the file list are now: ");
         Source_File_Node := TSFL.First (Source_File_List);
         for J in 1..Type_Source_File_List.Length(Source_File_List) loop
            Put_Line (File_Name(TSFL.Data (Source_File_Node).File_Name.all));
            Source_File_Node := TSFL.Next (Source_File_Node);
         end loop;
      end if;
   end Add_Body_Files;


   --------------------
   -- Get_Source_Dir --
   --------------------
   function Get_Source_Dir
     (Source_File_List   : TSFL.List) return String is
      --return the path of the first source file in the list

      Node : TSFL.List_Node;
   begin
      Node := TSFL.First (Source_File_List);
      return Dir_Name (TSFL.Data (Node).File_Name.all);
   end Get_Source_Dir;


begin -- DocGen

   Parse_Command_Line :
   declare
     Quit : Boolean := false;
   begin
      Handle_Command_Line (Quit);
      if Quit then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
         return;
      end if;
   end Parse_Command_Line;

   --AD.User_Tags.Verify;

   if Options.Info_Output then
      Put_Line("--------------------------------------------------------");
      Put_Line("--------------------------------------------------------");
      Put_Line("--------------------------------------------------------");
   end if;

   if not TSFL.Is_Empty (Source_File_List) then

      --if Process_Body (-body) option was set, add all .adb files to the list
      if Options.Process_Body_Files then
         Add_Body_Files (Source_File_List);
      end if;

      --if not path for the doc was set, take the path of the sources
      if Options.Doc_Directory = null then
         Options.Doc_Directory :=
           new String '(Get_Source_Dir (Source_File_List));
      end if;

      --Process all files listed or all files from the project file
      Process_Files (Source_File_List, Options);
   end if;

exception
   when Command_Line_Error =>
       Put_Line (Current_Error,
                "Type ""docgen -?"" for more information.");

   when Help_Requested =>
      New_Line (Current_Error);
      Put_Line (Current_Error, "NAME");
      New_Line (Current_Error);
      Put_Line (Current_Error, "   Docgen - Ada95 documentation generator");
      New_Line (Current_Error);
      Put_Line (Current_Error, "SYNOPSIS");
      New_Line (Current_Error);
      Put_Line (Current_Error, "   docgen (-h | -help | --help | -?)");
      Put_Line (Current_Error, "   docgen  .gpr-file  .ads-file " &
                               "{ .ads-files }");
      Put_Line (Current_Error, "   [ -info ] [ -ic ] [ -under]" &
                "[ -private] [ -texi ] ");
      Put_Line (Current_Error, "   [ -docpath=DIR ]");
      New_Line (Current_Error);
      Put_Line (Current_Error, "DESCRIPTION");
      New_Line (Current_Error);
      New_Line (Current_Error);
      Put_Line (Current_Error, "OPTIONS");
      New_Line (Current_Error);
      Put_Line (Current_Error, "   -help     Shows information about Docgen");
      Put_Line (Current_Error, "   -info     Gives further information" &
                " while processing");
      Put_Line (Current_Error, "   -body     Create also output files" &
                " for the body files");
      Put_Line (Current_Error, "   -ic       Comment starting with ""--!""" &
                " should be ignored ");
      Put_Line (Current_Error, "   -under    use comments under" &
                " the entity headers ");
      Put_Line (Current_Error, "   -private  Process also the entites" &
                " declared as Private");
      Put_Line (Current_Error, "   -texi     The output format should" &
                " be TexInfo.");
      Put_Line (Current_Error, "   -docpath=DIR   the subdirectory for the" &
                " doc files");
      Put_Line (Current_Error, "                  The last character is ""/"" or ""\""");
      New_Line (Current_Error);


end DocGen;
