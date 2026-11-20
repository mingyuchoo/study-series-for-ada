with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Diary_App;
with Diary_Bindings;
with Diary_Config;
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
   Settings   : Diary_Bindings.Preferences;
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
        ("Keymap: --keymap > DIARY_KEYMAP > ~/.ada_tui_diary/config.toml > emacs.");
      Ada.Text_IO.Put_Line
        ("Calendar: arrows, [/] month, T today; N new, E edit, D delete, S settings, Q quit.");
      Ada.Text_IO.Put_Line
        ("Emacs: C-x C-s save, C-x k close, C-s/r search, C-k kill, C-y/M-y yank, C-/ undo.");
      Ada.Text_IO.Put_Line
        ("Helix: i/a/o insert, Esc normal, 3w, f/t find, r replace, /? search, :w, :q.");
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
   Settings := Diary_Config.Load_Settings;
   if not Keymap_Set then
      if Ada.Environment_Variables.Value ("DIARY_KEYMAP", "") /= "" then
         Keymap :=
           Parse_Keymap (Ada.Environment_Variables.Value ("DIARY_KEYMAP"));
      else
         Keymap := Settings.Keymap;
      end if;
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
      Keymap,
      Settings.Bindings);
   Diary_File_Repositories.Close (Store);
exception
   when Error : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "Diary: " & Ada.Exceptions.Exception_Message (Error));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Diary;
