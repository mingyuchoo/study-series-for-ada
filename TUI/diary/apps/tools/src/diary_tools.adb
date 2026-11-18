with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with Diary_Tooling_Files;
with Diary_Tooling_Host;
with Diary_Tooling_Preparation;
with Diary_Tooling_Release;

procedure Diary_Tools is
   use Ada.Command_Line;
   procedure Require_Arguments (Count : Natural) is
   begin
      if Argument_Count /= Count then
         raise Constraint_Error with "Invalid argument count";
      end if;
   end Require_Arguments;
begin
   if Argument_Count = 0 then
      raise Constraint_Error
        with
          "Usage: diary_tools prepare|version|pin-manifest|validate-dependencies|license|checksums";
   end if;
   declare
      Command : constant String := Argument (1);
   begin
      if Command = "prepare" then
         if Argument_Count not in 2 .. 3 then
            raise Constraint_Error
              with "Usage: diary_tools prepare ROOT [linux|macos]";
         end if;
         Diary_Tooling_Preparation.Prepare
           (Argument (2),
            (if Argument_Count = 3
             then Argument (3)
             else Diary_Tooling_Host.Platform));
      elsif Command = "version" then
         Require_Arguments (2);
         Ada.Text_IO.Put_Line
           (Diary_Tooling_Release.Manifest_Version
              (Diary_Tooling_Files.Read_File (Argument (2))));
      elsif Command = "pin-manifest" then
         Require_Arguments (2);
         Diary_Tooling_Files.Write_File
           (Argument (2),
            Diary_Tooling_Release.Pin_Manifest
              (Diary_Tooling_Files.Read_File (Argument (2))));
      elsif Command = "validate-dependencies" then
         Require_Arguments (3);
         if not Diary_Tooling_Release.Dependencies_Allowed
                  (Diary_Tooling_Files.Read_File (Argument (3)), Argument (2))
         then
            raise Constraint_Error
              with
                "Unbundled or missing runtime dependency in " & Argument (3);
         end if;
      elsif Command = "license" then
         Require_Arguments (2);
         Ada.Text_IO.Put_Line
           (Diary_Tooling_Files.License_Path (Argument (2)));
      elsif Command = "checksums" then
         Require_Arguments (3);
         Diary_Tooling_Files.Write_Checksums (Argument (2), Argument (3));
      else
         raise Constraint_Error with "Unknown tooling command: " & Command;
      end if;
   end;
exception
   when Error : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "Diary tooling failed: " & Ada.Exceptions.Exception_Message (Error));
      Set_Exit_Status (Failure);
end Diary_Tools;
