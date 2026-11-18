with Ada.Directories;
with Ada.Strings.Unbounded;
with Tui_Tooling_Files;
with Tui_Tooling_Patches;

package body Tui_Tooling_Preparation is
   procedure Prepare (Root, Platform : String) is
      use Ada.Strings.Unbounded;
      use type Ada.Directories.File_Kind;
      Local  : constant String := Root & "/dependencies/malef/src";
      Source : constant String :=
        (if Ada.Directories.Exists (Local)
           and then Ada.Directories.Kind (Local) = Ada.Directories.Directory
         then Local
         else Root & "/alire/cache/pins/malef_79b20b6b/src");
      Names  : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("drawing/malef-groups.ads"),
         To_Unbounded_String ("drawing/malef-groups.adb"),
         To_Unbounded_String ("widgets/malef-styles.ads"),
         To_Unbounded_String ("widgets/malef-styles-classes.ads"),
         To_Unbounded_String ("widgets/malef-styles-sheets.ads"),
         To_Unbounded_String ("drawing/malef-window.adb"),
         To_Unbounded_String ("drawing/malef-palettes.adb"),
         To_Unbounded_String ("private/malef-groups-composers.adb"),
         To_Unbounded_String
           ("subsystems/ansi/posix/__malef-platform-terminal-input-implementation.c"),
         To_Unbounded_String
           ("subsystems/ansi/posix/malef-platform-terminal-input-get_byte_immediate.adb"),
         To_Unbounded_String
           ("subsystems/ansi/malef-platform-terminal-input.adb")];
   begin
      if Platform /= "linux" and then Platform /= "macos" then
         raise Constraint_Error
           with "Unknown preparation platform: " & Platform;
      end if;
      if not Ada.Directories.Exists (Source) then
         raise Program_Error with "Pinned Malef sources are missing";
      end if;
      for Name of Names loop
         declare
            Path     : constant String := Source & "/" & To_String (Name);
            Original : constant String := Tui_Tooling_Files.Read_File (Path);
            Updated  : constant String :=
              Tui_Tooling_Patches.Transform
                (To_String (Name), Original, Platform);
         begin
            if Original /= Updated then
               Tui_Tooling_Files.Write_File (Path, Updated);
            end if;
         end;
      end loop;
   end Prepare;
end Tui_Tooling_Preparation;
