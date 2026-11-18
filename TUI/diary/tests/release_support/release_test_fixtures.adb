with Ada.Characters.Latin_1;
with Ada.Directories;
with Ada.Environment_Variables;
with GNAT.OS_Lib;
with Interfaces.C;
with Interfaces.C.Strings;
with Release_Test_Files;

package body Release_Test_Fixtures is
   use Ada.Characters.Latin_1;
   use Ada.Directories;
   use Ada.Strings.Unbounded;
   use Interfaces.C;
   use Interfaces.C.Strings;
   use Release_Test_Files;
   use Release_Test_Processes;

   function Make_Temporary_Directory (Template : chars_ptr) return chars_ptr
   with Import, Convention => C, External_Name => "mkdtemp";
   function Set_Permissions (Path : char_array; Mode : unsigned) return int
   with Import, Convention => C, External_Name => "chmod";

   function Temporary_Directory return String is
      Parent   : constant String :=
        Ada.Environment_Variables.Value ("TMPDIR", "/tmp");
      Template : chars_ptr :=
        New_String (Full_Name (Parent) & "/diary release test XXXXXX");
      Location : constant chars_ptr := Make_Temporary_Directory (Template);
   begin
      if Location = Null_Ptr then
         Free (Template);
         raise Use_Error
           with "Cannot create a temporary directory in " & Parent;
      end if;
      return Path : constant String := Value (Location) do
         Free (Template);
      end return;
   end Temporary_Directory;

   function Directory (Test : Fixture) return String
   is (To_String (Test.Root));
   function Project (Test : Fixture) return String
   is (Directory (Test) & "/project with spaces");
   function Output (Test : Fixture) return String
   is (Directory (Test) & "/output with spaces");
   function Log (Test : Fixture) return String
   is (Directory (Test) & "/commands.log");
   function Tools (Test : Fixture) return String
   is (Directory (Test) & "/tools");

   procedure Copy (Source, Target : String) is
      Success : Boolean;
   begin
      GNAT.OS_Lib.Copy_File
        (Source, Target, Success, Preserve => GNAT.OS_Lib.Full);
      if not Success then
         raise Use_Error with "Cannot copy " & Source & " to " & Target;
      end if;
   end Copy;

   procedure Copy_Tree (Source, Target : String) is
      procedure Copy_Entry (Item : Directory_Entry_Type) is
         Name : constant String := Simple_Name (Item);
      begin
         case Kind (Item) is
            when Ada.Directories.Directory =>
               if Name /= "."
                 and then Name /= ".."
                 and then Name /= "obj"
                 and then Name /= "alire"
                 and then Name /= "config"
                 and then Name /= "bin"
               then
                  Copy_Tree (Full_Name (Item), Target & "/" & Name);
               end if;

            when Ordinary_File             =>
               Copy (Full_Name (Item), Target & "/" & Name);

            when Special_File              =>
               raise Use_Error
                 with "Cannot copy special file " & Full_Name (Item);
         end case;
      end Copy_Entry;

   begin
      Create_Directory (Target);
      Search (Source, "", [others => True], Copy_Entry'Access);
   end Copy_Tree;

   procedure Write_Executable (Path, Content : String) is
   begin
      Write_File (Path, "#!/bin/sh" & LF & Content);
      if Set_Permissions (To_C (Path), 8#755#) /= 0 then
         raise Use_Error with "Cannot make " & Path & " executable";
      end if;
   end Write_Executable;

   procedure Copy_Command (Name, Target : String) is
      Source : constant String := Find_Executable (Name);
   begin
      if Source = "" then
         raise Use_Error with "Required test command not found: " & Name;
      end if;
      Copy (Source, Target);
   end Copy_Command;

   procedure Create_Dependency (Location : String) is
      Source : constant String := Location & "/src";
   begin
      for Name of
        Arguments'
          [+"drawing", +"widgets", +"private", +"subsystems/ansi/posix"]
      loop
         Create_Path (Source & "/" & To_String (Name));
      end loop;
      for Name of
        Arguments'
          [+"drawing/malef-groups.ads",
           +"drawing/malef-groups.adb",
           +"widgets/malef-styles.ads",
           +"widgets/malef-styles-classes.ads",
           +"widgets/malef-styles-sheets.ads",
           +"drawing/malef-window.adb",
           +"drawing/malef-palettes.adb",
           +"private/malef-groups-composers.adb",
           +"subsystems/ansi/posix/__malef-platform-terminal-input-implementation.c"]
      loop
         Write_File (Source & "/" & To_String (Name), "");
      end loop;
      Write_File
        (Source
         & "/subsystems/ansi/posix/malef-platform-terminal-input-get_byte_immediate.adb",
         "External_Name => ""stdin"";" & LF);
      Write_File
        (Source & "/subsystems/ansi/malef-platform-terminal-input.adb",
         "TIOCGWINSZ : constant Interfaces.C.unsigned_long := 16#5413#;" & LF);
      Write_File
        (Source & "/example.ads", "package Example is end Example;" & LF);
      Write_File (Location & "/LICENSE", "Malef GPL-3.0-or-later" & LF);
   end Create_Dependency;

   function Create (Project_Root : String) return Fixture is
   begin
      return Test : Fixture do
         Test.Root := +Temporary_Directory;
         Create_Directory (Project (Test));
         for Name of Arguments'[+"scripts", +"apps", +"packages", +"tests"]
         loop
            Copy_Tree
              (Project_Root & "/" & To_String (Name),
               Project (Test) & "/" & To_String (Name));
         end loop;
         for Name of
           Arguments'
             [+"alire.toml",
              +"diary.gpr",
              +"tools.gpr",
              +"Makefile",
              +"README.md",
              +"LICENSE",
              +".gitattributes"]
         loop
            Copy
              (Project_Root & "/" & To_String (Name),
               Project (Test) & "/" & To_String (Name));
         end loop;
         Create_Directory (Project (Test) & "/packages/tooling/obj");
         Write_File (Project (Test) & "/packages/tooling/obj/generated", "");
         Create_Dependency
           (Project (Test) & "/alire/cache/pins/malef_79b20b6b");
         Create_Directory (Project (Test) & "/bin");
         Copy
           (Project_Root & "/bin/diary_tools",
            Project (Test) & "/bin/diary_tools");
         for Main of
           Arguments'
             [+"diary",
              +"domain_tests",
              +"editor_tests",
              +"codec_tests",
              +"tooling_tests",
              +"tooling_file_tests",
              +"patch_tests",
              +"run_storage_tests",
              +"release_tests",
              +"tui_smoke"]
         loop
            Copy_Command ("true", Project (Test) & "/bin/" & To_String (Main));
         end loop;
         Create_Directory (Tools (Test));
         Write_Executable
           (Tools (Test) & "/alr",
            "printf '%s\n' ""$*"" >> ""$RELEASE_TEST_LOG"""
            & LF
            & "if [ -n ""${RELEASE_TEST_FAIL:-}"" ]; then"
            & LF
            & "    case ""$*"" in *""$RELEASE_TEST_FAIL""*) exit 42 ;; esac"
            & LF
            & "fi"
            & LF);
         for Name of Arguments'[+"python", +"python3"] loop
            Write_Executable
              (Tools (Test) & "/" & To_String (Name),
               "printf '%s\n' 'Release invoked Python' >&2"
               & LF
               & "exit 81"
               & LF);
         end loop;
      end return;
   end Create;

   overriding
   procedure Finalize (Test : in out Fixture) is
   begin
      if Length (Test.Root) /= 0 then
         Delete_Tree (Directory (Test));
      end if;
   end Finalize;

   procedure Configure_Darwin (Test : Fixture; Isolate_Path : Boolean := False)
   is
   begin
      Write_Executable
        (Tools (Test) & "/uname",
         "case ""$1"" in -s) echo Darwin ;; -m) echo arm64 ;; *) exit 2 ;; esac"
         & LF);
      if Isolate_Path then
         for Name of Arguments'[+"dirname", +"tar", +"strip"] loop
            Copy_Command
              (To_String (Name), Tools (Test) & "/" & To_String (Name));
         end loop;
         Copy_Command ("true", Tools (Test) & "/otool");
      end if;
   end Configure_Darwin;

   function Run_Release
     (Test         : Fixture;
      Options      : Arguments;
      Fail_On      : String := "";
      Mask         : String := "022";
      Isolate_Path : Boolean := False) return Result
   is
      Path    : constant String :=
        Tools (Test)
        & (if Isolate_Path
           then ""
           else ":" & Ada.Environment_Variables.Value ("PATH"));
      Command : constant Arguments :=
        [+"/bin/sh",
         +"-c",
         +"export PATH=""$1"" RELEASE_TEST_LOG=""$2"" RELEASE_TEST_FAIL=""$3"" TMPDIR=""$4""; "
         & "umask ""$5""; shift 5; exec /bin/bash ""$@""",
         +"release-test",
         +Path,
         +Log (Test),
         +Fail_On,
         +Directory (Test),
         +Mask,
         +(Project (Test) & "/scripts/release.sh")]
        & Options;
   begin
      return Run (Command, Directory (Test));
   end Run_Release;

   function Run_Prepare (Test : Fixture) return Result is
      Path : constant String :=
        Tools (Test) & ":" & Ada.Environment_Variables.Value ("PATH");
   begin
      return
        Run
          ([+"env",
            +("PATH=" & Path),
            +(Project (Test) & "/bin/diary_tools"),
            +"prepare",
            +Project (Test),
            +"macos"],
           Directory (Test),
           Timeout => 5.0);
   end Run_Prepare;
end Release_Test_Fixtures;
