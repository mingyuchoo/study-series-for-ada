with Ada.Assertions;
with Ada.Containers;
with Ada.Characters.Latin_1;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Release_Test_Files;
with Release_Test_Fixtures;
with Release_Test_Processes;

procedure Release_Tests is
   use Ada.Characters.Latin_1;
   use type Ada.Containers.Count_Type;
   use Ada.Directories;
   use Ada.Strings.Fixed;
   use Ada.Strings.Unbounded;
   use Release_Test_Files;
   use Release_Test_Fixtures;
   use Release_Test_Processes;

   Skip_Test : exception;

   function Contains (Value, Fragment : String) return Boolean
   is (Index (Value, Fragment) /= 0);

   function Ends_With (Value, Suffix : String) return Boolean
   is (Value'Length >= Suffix'Length
       and then Value (Value'Last - Suffix'Length + 1 .. Value'Last) = Suffix);

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Ada.Assertions.Assertion_Error with Message;
      end if;
   end Check;

   function Passed (Process : Result) return String is
   begin
      Check (Process.Status = 0, Command_Output (Process));
      return To_String (Process.Output);
   end Passed;

   function Single_File (Location, Pattern : String) return String is
      Files : constant Names.Vector := Matching_Files (Location, Pattern);
   begin
      Check
        (Files.Length = 1,
         "Expected one file matching " & Pattern & " in " & Location);
      return Files.First_Element;
   end Single_File;

   function Binary_Archive (Location : String) return String is
      Archive : Unbounded_String;
   begin
      for Name of Matching_Files (Location, "*.tar.gz") loop
         if not Ends_With (Name, "-source.tar.gz") then
            Check (Length (Archive) = 0, "Multiple binary archives");
            Archive := To_Unbounded_String (Name);
         end if;
      end loop;
      Check (Length (Archive) > 0, "Missing binary archive");
      return To_String (Archive);
   end Binary_Archive;

   function Entries (Test : Fixture; Archive : String) return Names.Vector
   is (Lines (Passed (Run ([+"tar", +"-tzf", +Archive], Directory (Test)))));

   function Has_Entry (Members : Names.Vector; Suffix : String) return Boolean
   is (for some Name of Members => Ends_With (Name, Suffix));

   procedure Check_Help (Test : Fixture) is
      Process : constant Result := Run_Release (Test, [+"--help"]);
   begin
      Check
        (Contains (Passed (Process), "--bundle-only"),
         "Help omits the bundle option");
      Check (not Exists (Log (Test)), "Help ran the toolchain");
   end Check_Help;

   procedure Check_Invalid_Arguments (Test : Fixture) is
      procedure Reject (Options : Arguments) is
         Process : constant Result := Run_Release (Test, Options);
      begin
         Check
           (Process.Status /= 0,
            "Accepted invalid argument " & To_String (Options (Options'Last)));
         Check
           (not Exists (Log (Test)), "Invalid arguments ran the toolchain");
      end Reject;
   begin
      Reject ([+"--version", +"../bad"]);
      Reject ([+"--unknown"]);
      Reject ([+"--output"]);
      Reject ([+"--version", +("1.0.0" & LF)]);
   end Check_Invalid_Arguments;

   procedure Check_Early_Failure (Test : Fixture) is
      Process : constant Result :=
        Run_Release
          (Test,
           [+"--output", +Output (Test), +"--bundle-only"],
           Fail_On => "gnatformat -P");
   begin
      Check
        (Process.Status /= 0, "A formatter failure did not stop the release");
      declare
         Commands : constant String := Read_File (Log (Test));
      begin
         Check
           (Contains (Commands, "gnatformat -P"),
            "Release never reached formatting"
            & LF
            & Command_Output (Process));
         Check
           (not Contains (Commands, "build --release --"),
            "Release built the application after formatting failed");
      end;
      Check
        (Matching_Files (Output (Test), "*.tar.gz").Is_Empty,
         "Release bundled outputs after formatting failed");
   end Check_Early_Failure;

   procedure Check_Relative_Output (Test : Fixture) is
      Output_Name : constant String := "relative output";
      Process     : constant Result :=
        Run_Release (Test, [+"--output", +Output_Name, +"--bundle-only"]);
   begin
      Check (Process.Status = 0, Command_Output (Process));
      Check
        (Matching_Files (Directory (Test) & "/" & Output_Name, "*.tar.gz")
           .Length
         = 2,
         "Release did not resolve relative output from the calling directory");
   end Check_Relative_Output;

   procedure Check_Archive_Permissions (Test : Fixture) is
      Process     : constant Result :=
        Run_Release
          (Test,
           [+"--output", +Output (Test), +"--bundle-only"],
           Mask => "077");
      Directories : Natural := 0;
   begin
      Check (Process.Status = 0, Command_Output (Process));
      declare
         Archive : constant String :=
           Output (Test) & "/" & Binary_Archive (Output (Test));
         Listing : constant String :=
           Passed (Run ([+"tar", +"-tvzf", +Archive], Directory (Test)));
      begin
         for Line of Lines (Listing) loop
            if Line'Length > 0 and then Line (Line'First) = 'd' then
               Directories := Directories + 1;
               Check
                 (Line'Length >= 10
                  and then Line (5) = 'r'
                  and then Line (7) in 'x' | 's'
                  and then Line (8) = 'r'
                  and then Line (10) in 'x' | 't',
                  "Archive directory is private under a restrictive umask: "
                  & Line);
            end if;
         end loop;
      end;
      Check (Directories > 0, "Binary archive contains no directories");
   end Check_Archive_Permissions;

   function Compute_SHA_256 (Test : Fixture; Path : String) return String is
      Use_SHA256sum : constant Boolean := Find_Executable ("sha256sum") /= "";
      Command       : constant Arguments :=
        (if Use_SHA256sum then [+"sha256sum"] else [+"shasum", +"-a", +"256"]);
      Digest        : constant String :=
        Passed (Run (Command & [+Path], Directory (Test)));
   begin
      Check
        (Digest'Length > 64 and then Digest (65) = ' ',
         "Unexpected independent checksum output");
      return Digest (1 .. 64);
   end Compute_SHA_256;

   procedure Check_Checksums (Test : Fixture; Archives : Names.Vector) is
      Manifest : constant String := Single_File (Output (Test), "*SHA256SUMS");
      Recorded : Names.Vector;
   begin
      for Line of Lines (Read_File (Output (Test) & "/" & Manifest)) loop
         Check
           (Line'Length > 66 and then Line (65 .. 66) = "  ",
            "Malformed SHA-256 manifest entry: " & Line);
         declare
            Name : constant String := Line (67 .. Line'Last);
         begin
            Check
              (Archives.Contains (Name),
               "Checksum manifest names an unexpected artifact: " & Name);
            Check
              (not Recorded.Contains (Name),
               "Duplicate checksum manifest entry: " & Name);
            Check
              (Compute_SHA_256 (Test, Output (Test) & "/" & Name)
               = Line (1 .. 64),
               "Incorrect SHA-256 for " & Name);
            Recorded.Append (Name);
         end;
      end loop;
      Check
        (Recorded.Length = Archives.Length,
         "Checksum manifest does not cover every archive");
   end Check_Checksums;

   procedure Check_Source_Archive (Test : Fixture; Archive : String) is
      Members  : constant Names.Vector := Entries (Test, Archive);
      Manifest : Unbounded_String;
   begin
      Check
        (Has_Entry (Members, "/dependencies/malef/src/example.ads"),
         "Source archive omits the pinned dependency");
      Check
        (Has_Entry (Members, "/scripts/prepare.sh"),
         "Source archive omits the preparation script");
      Check
        (Has_Entry (Members, "/tools.gpr"),
         "Source archive omits the standalone tooling project");
      Check
        (Has_Entry (Members, "/apps/tools/src/diary_tools.adb"),
         "Source archive omits the tooling executable sources");
      Check
        (Has_Entry (Members, "/packages/tooling/diary_tooling.gpr"),
         "Source archive omits the tooling workspace package");
      for Name of Members loop
         Check
           (not Contains (Name, "/obj/") and then not Contains (Name, "/bin/"),
            "Source archive includes outputs: " & Name);
         if Count (Name, "/") = 1 and then Ends_With (Name, "/alire.toml") then
            Manifest := To_Unbounded_String (Name);
         end if;
      end loop;
      Check (Length (Manifest) > 0, "Source archive has no root manifest");
      declare
         Source : constant String :=
           Passed
             (Run ([+"tar", +"-xOzf", +Archive, Manifest], Directory (Test)));
      begin
         Check
           (Contains (Source, "malef = { path = ""dependencies/malef"" }"),
            "Source manifest has no local Malef pin");
      end;
   end Check_Source_Archive;

   procedure Check_Bundles (Test : Fixture) is
      Process : constant Result :=
        Run_Release (Test, [+"--output", +Output (Test), +"--bundle-only"]);
   begin
      Check (Process.Status = 0, Command_Output (Process));
      declare
         Archives : constant Names.Vector :=
           Matching_Files (Output (Test), "*.tar.gz");
         Binary   : constant Names.Vector :=
           Entries
             (Test, Output (Test) & "/" & Binary_Archive (Output (Test)));
         Source   : constant String :=
           Output (Test)
           & "/"
           & Single_File (Output (Test), "*-source.tar.gz");
      begin
         Check (Archives.Length = 2, "Expected two archives");
         Check
           (Has_Entry (Binary, "/bin/diary"),
            "Binary archive omits the diary");
         Check
           (Has_Entry (Binary, "/LICENSE"),
            "Binary archive omits the diary license");
         Check
           (Has_Entry (Binary, "/MALEF-LICENSE"),
            "Binary archive omits the Malef license");
         Check
           ((for all Name of Binary => not Contains (Name, "domain_tests")),
            "Binary archive includes development executables");
         Check_Source_Archive (Test, Source);
         Check_Checksums (Test, Archives);
      end;
      Check
        (Contains (Read_File (Log (Test)), "-O2"),
         "Release did not request an optimized build");
      Check
        (Matching_Files (Output (Test), "*.deb").Is_Empty
         and then Matching_Files (Output (Test), "*.rpm").Is_Empty
         and then Matching_Files (Output (Test), "*.pkg").Is_Empty,
         "Bundle-only release created a native installer");
   end Check_Bundles;

   procedure Check_Missing_Packager (Test : Fixture) is
   begin
      Configure_Darwin (Test, Isolate_Path => True);
      declare
         Process : constant Result :=
           Run_Release
             (Test, [+"--output", +Output (Test)], Isolate_Path => True);
      begin
         Check
           (Process.Status /= 0,
            "Release succeeded with a required packager missing");
         Check
           (Contains (To_String (Process.Errors), "pkgbuild"),
            Command_Output (Process));
         Check
           (not Exists (Log (Test)),
            "Release started the toolchain with a required packager missing");
      end;
   end Check_Missing_Packager;

   procedure Check_Native_Prerelease (Test : Fixture) is
      Host : constant String :=
        Passed (Run ([+"uname", +"-s"], Directory (Test)));
   begin
      if not Contains (Host, "Linux")
        or else Find_Executable ("dpkg-deb") = ""
        or else Find_Executable ("rpmbuild") = ""
      then
         raise Skip_Test with "requires Linux, dpkg-deb, and rpmbuild";
      end if;
      declare
         Process : constant Result :=
           Run_Release
             (Test,
              [+"--output",
               +Output (Test),
               +"--version",
               +"1.2.3-rc.1-alpha"]);
      begin
         Check (Process.Status = 0, Command_Output (Process));
         declare
            Package_File : constant String :=
              Output (Test) & "/" & Single_File (Output (Test), "*.deb");
            Version      : constant String :=
              Passed
                (Run
                   ([+"dpkg-deb", +"--field", +Package_File, +"Version"],
                    Directory (Test)));
         begin
            Check
              (Version = "1.2.3~rc.1-alpha" & LF,
               "Unexpected Debian version: " & Version);
            Check
              (Matching_Files (Output (Test), "*.rpm").Length = 1,
               "Release did not create an RPM");
         end;
      end;
   end Check_Native_Prerelease;

   procedure Check_Darwin_Preparation (Test : Fixture) is
      Source            : constant String :=
        Project (Test) & "/dependencies/malef/src";
      Terminal          : constant String :=
        Source & "/subsystems/ansi/malef-platform-terminal-input.adb";
      Reader            : constant String :=
        Source
        & "/subsystems/ansi/posix/malef-platform-terminal-input-get_byte_immediate.adb";
      Terminal_Contents : Unbounded_String;
      Reader_Contents   : Unbounded_String;
   begin
      Configure_Darwin (Test);
      Create_Dependency (Project (Test) & "/dependencies/malef");
      declare
         Process : constant Result := Run_Prepare (Test);
      begin
         Check (Process.Status = 0, Command_Output (Process));
      end;
      Terminal_Contents := To_Unbounded_String (Read_File (Terminal));
      Reader_Contents := To_Unbounded_String (Read_File (Reader));
      Check
        (Contains (To_String (Terminal_Contents), "16#40087468#"),
         "Preparation did not set Darwin's TIOCGWINSZ");
      Check
        (Contains
           (To_String (Reader_Contents), "External_Name => ""__stdinp"""),
         "Preparation used the wrong stdin symbol");
      declare
         Process : constant Result := Run_Prepare (Test);
      begin
         Check (Process.Status = 0, Command_Output (Process));
         Check
           (To_String (Terminal_Contents) = Read_File (Terminal),
            "Darwin terminal preparation is not idempotent");
         Check
           (To_String (Reader_Contents) = Read_File (Reader),
            "Darwin stdin preparation is not idempotent");
      end;
   end Check_Darwin_Preparation;

   function Project_Root return String is
      Command    : constant String := Ada.Command_Line.Command_Name;
      Executable : constant String :=
        (if Exists (Command) then Command else Find_Executable (Command));
   begin
      return
        Containing_Directory
          (Containing_Directory (GNAT.OS_Lib.Normalize_Pathname (Executable)));
   end Project_Root;

   Failures : Natural := 0;

   procedure Run_Test
     (Name : String; Test_Case : not null access procedure (Test : Fixture)) is
   begin
      declare
         Test : constant Fixture := Create (Project_Root);
      begin
         Test_Case (Test);
      end;
      Ada.Text_IO.Put_Line ("PASS " & Name);
   exception
      when Reason : Skip_Test =>
         Ada.Text_IO.Put_Line
           ("SKIP "
            & Name
            & " ("
            & Ada.Exceptions.Exception_Message (Reason)
            & ")");
      when Error : others =>
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "FAIL "
            & Name
            & LF
            & Ada.Exceptions.Exception_Information (Error));
   end Run_Test;

begin
   Run_Test ("help bypasses the toolchain", Check_Help'Access);
   Run_Test
     ("invalid arguments bypass the toolchain",
      Check_Invalid_Arguments'Access);
   Run_Test ("formatting failure stops release", Check_Early_Failure'Access);
   Run_Test
     ("relative output follows the caller", Check_Relative_Output'Access);
   Run_Test
     ("archive directories stay readable under a restrictive umask",
      Check_Archive_Permissions'Access);
   Run_Test
     ("binary and source bundles contain the expected payload and checksums",
      Check_Bundles'Access);
   Run_Test
     ("missing packager bypasses the toolchain",
      Check_Missing_Packager'Access);
   Run_Test
     ("native prerelease packages accept hyphens",
      Check_Native_Prerelease'Access);
   Run_Test
     ("Darwin dependency preparation uses the host terminal settings",
      Check_Darwin_Preparation'Access);
   if Failures /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Release_Tests;
