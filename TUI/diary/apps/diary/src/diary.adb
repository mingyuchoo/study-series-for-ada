with Ada.Calendar;
with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Diary_App;
with Diary_Dates;
with Diary_File_Repositories;

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
   Directory : Unbounded_String;
   Store     : Diary_File_Repositories.File_Repository;
   Now       : constant Ada.Calendar.Time := Ada.Calendar.Clock;
   procedure Usage is
   begin
      Ada.Text_IO.Put_Line ("Usage: diary [--data-dir PATH] [--help]");
      Ada.Text_IO.Put_Line
        ("Calendar: arrows, [/] month, T today; N new, E edit, D delete, Q quit.");
      Ada.Text_IO.Put_Line
        ("Editor: Tab field, Ctrl+S save, Esc cancel, Ctrl+A/E line start/end.");
   end Usage;
begin
   if Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) in "--help" | "-h"
   then
      Usage;
      return;
   elsif Ada.Command_Line.Argument_Count = 2
     and then Ada.Command_Line.Argument (1) = "--data-dir"
     and then Ada.Command_Line.Argument (2) /= ""
   then
      Directory := To_Unbounded_String (Ada.Command_Line.Argument (2));
   elsif Ada.Command_Line.Argument_Count = 0 then
      Directory := To_Unbounded_String (Default_Directory);
   else
      Usage;
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   Diary_File_Repositories.Open (Store, To_String (Directory));
   Diary_App.Run
     (Store,
      Diary_Dates.Create
        (Ada.Calendar.Year (Now),
         Ada.Calendar.Month (Now),
         Ada.Calendar.Day (Now)));
   Diary_File_Repositories.Close (Store);
exception
   when Error : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "Diary: " & Ada.Exceptions.Exception_Message (Error));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Diary;
