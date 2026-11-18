with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Diary_App;
with Diary_Dates;
with Diary_File_Repositories;
with Diary_Keymaps;

procedure Diary is
   use Ada.Strings.Unbounded;
   function Default_Directory return String is
   begin
      if Ada.Environment_Variables.Exists ("XDG_DATA_HOME")
        and then Ada.Environment_Variables.Value ("XDG_DATA_HOME") /= ""
      then
         return
           Ada.Environment_Variables.Value ("XDG_DATA_HOME") & "/ada-diary";
      elsif Ada.Environment_Variables.Exists ("HOME")
        and then Ada.Environment_Variables.Value ("HOME") /= ""
      then
         return
           Ada.Environment_Variables.Value ("HOME")
           & "/.local/share/ada-diary";
      end if;
      raise Constraint_Error
        with "Set HOME or XDG_DATA_HOME, or pass --data-dir PATH";
   end Default_Directory;
   Directory  : Unbounded_String;
   Keymap     : Diary_Keymaps.Kind := Diary_Keymaps.Emacs;
   Keymap_Set : Boolean := False;
   Index      : Positive := 1;
   Store      : Diary_File_Repositories.File_Repository;
   Now        : constant Ada.Calendar.Time := Ada.Calendar.Clock;
   function Parse_Keymap (Name : String) return Diary_Keymaps.Kind is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Name);
   begin
      if Lower = "emacs" then
         return Diary_Keymaps.Emacs;
      elsif Lower in "helix" | "hx" then
         return Diary_Keymaps.Helix;
      end if;
      raise Constraint_Error
        with "Unknown keymap """ & Name & """; use emacs or helix";
   end Parse_Keymap;
   procedure Usage is
   begin
      Ada.Text_IO.Put_Line
        ("Usage: diary [--data-dir PATH] [--keymap emacs|helix] [--help]");
      Ada.Text_IO.Put_Line
        ("Keymap: --keymap or DIARY_KEYMAP; default emacs; M switches in the calendar.");
      Ada.Text_IO.Put_Line
        ("Calendar: arrows, [/] month, T today; N new, E edit, D delete, Q quit.");
      Ada.Text_IO.Put_Line
        ("Emacs editor: Tab field, Ctrl+S save, Esc cancel, C-a/C-e, C-k, C-y, C-/.");
      Ada.Text_IO.Put_Line
        ("Helix editor: i/a/o insert, Esc normal, hjkl, w/b/e, x, d/c/y/p, u/U, :w, :q.");
   end Usage;
begin
   while Index <= Ada.Command_Line.Argument_Count loop
      if Ada.Command_Line.Argument (Index) in "--help" | "-h" then
         Usage;
         return;
      elsif Index < Ada.Command_Line.Argument_Count
        and then Ada.Command_Line.Argument (Index) = "--data-dir"
        and then Ada.Command_Line.Argument (Index + 1) /= ""
      then
         Directory :=
           To_Unbounded_String (Ada.Command_Line.Argument (Index + 1));
      elsif Index < Ada.Command_Line.Argument_Count
        and then Ada.Command_Line.Argument (Index) = "--keymap"
      then
         Keymap := Parse_Keymap (Ada.Command_Line.Argument (Index + 1));
         Keymap_Set := True;
      else
         Usage;
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;
      Index := Index + 2;
   end loop;
   if not Keymap_Set
     and then Ada.Environment_Variables.Exists ("DIARY_KEYMAP")
     and then Ada.Environment_Variables.Value ("DIARY_KEYMAP") /= ""
   then
      Keymap :=
        Parse_Keymap (Ada.Environment_Variables.Value ("DIARY_KEYMAP"));
   end if;
   if Length (Directory) = 0 then
      Directory := To_Unbounded_String (Default_Directory);
   end if;
   Diary_File_Repositories.Open (Store, To_String (Directory));
   Diary_App.Run
     (Store,
      Diary_Dates.Create
        (Ada.Calendar.Year (Now),
         Ada.Calendar.Month (Now),
         Ada.Calendar.Day (Now)),
      Keymap);
   Diary_File_Repositories.Close (Store);
exception
   when Error : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "Diary: " & Ada.Exceptions.Exception_Message (Error));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Diary;
