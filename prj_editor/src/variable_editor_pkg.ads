with Gtk.Window; use Gtk.Window;
with Gtk.Box; use Gtk.Box;
with Gtk.Scrolled_Window; use Gtk.Scrolled_Window;
with Gtk.Viewport; use Gtk.Viewport;
with Gtk.Table; use Gtk.Table;
with Gtk.Label; use Gtk.Label;
with Gtk.Separator; use Gtk.Separator;
with Gtk.Hbutton_Box; use Gtk.Hbutton_Box;
with Gtk.Button; use Gtk.Button;
with Gtk.Object; use Gtk.Object;
package Variable_Editor_Pkg is

   type Variable_Editor_Record is new Gtk_Window_Record with record
      Vbox31 : Gtk_Vbox;
      Scrolledwindow3 : Gtk_Scrolled_Window;
      Viewport2 : Gtk_Viewport;
      List_Variables : Gtk_Table;
      Label52 : Gtk_Label;
      Label53 : Gtk_Label;
      Label54 : Gtk_Label;
      Hseparator3 : Gtk_Hseparator;
      Hbuttonbox2 : Gtk_Hbutton_Box;
      Add_Button : Gtk_Button;
      Close_Button : Gtk_Button;
   end record;
   type Variable_Editor_Access is access all Variable_Editor_Record'Class;

   procedure Gtk_New (Variable_Editor : out Variable_Editor_Access);
   procedure Initialize (Variable_Editor : access Variable_Editor_Record'Class);

   Variable_Editor : Variable_Editor_Access;

end Variable_Editor_Pkg;
