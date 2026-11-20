with Ada.Characters.Latin_1;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Test_Fixtures;
with Test_Processes;
with Test_Terminals;

procedure TUI_Smoke is
   use Ada.Characters.Latin_1;
   use Ada.Strings.Fixed;
   use Ada.Strings.Unbounded;
   use Test_Fixtures;
   use Test_Processes;
   use Test_Terminals;

   Diary     : constant String := Sibling_Executable ("diary");
   Test_Home : Temporary_Directory;

   function Ctrl (Key : Character) return Character
   is (Character'Val (Character'Pos (Key) mod 32));

   Save_Emacs : constant String := [Ctrl ('X'), Ctrl ('S')];
   Save_Close : constant String := Save_Emacs & Ctrl ('X') & "k";

   function UTF8 (Value : Wide_Wide_String) return String
   is (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Value));

   procedure Check_Content (Directory : String; Expected : String) is
      Saved      : constant String := Read_File (Only_Diary_File (Directory));
      Body_Start : constant Positive := Index (Saved, "" & LF) + 1;
      Content    : constant String := Saved (Body_Start .. Saved'Last);
   begin
      Check
        (Body_Start > 1 and then Content = Expected,
         "Expected entry content " & Expected & "; found " & Content);
   end Check_Content;

   procedure Start_Diary
     (App : in out Session; Directory : String; Options : Arguments := []) is
   begin
      Open
        (App,
         Diary,
         [Argument ("--data-dir"), Argument (Directory)] & Options);
   end Start_Diary;

   procedure Check_Command_Line is
      Help           : constant Captured_Result :=
        Capture (Diary, [Argument ("--help")]);
      Unknown_Option : constant Captured_Result :=
        Capture (Diary, [Argument ("--unknown")]);
      Unknown_Keymap : constant Captured_Result :=
        Capture (Diary, [Argument ("--keymap"), Argument ("vim")]);
   begin
      Check (Help.Exit_Status = 0, "Help command failed");
      Check (Index (Help.Output, "Usage: diary") > 0, "Help lacks usage");
      Check
        (Index (Help.Output, "--keymap emacs|helix") > 0,
         "Help lacks keymap options");
      Check (Unknown_Option.Exit_Status /= 0, "Accepted an unknown option");
      Check
        (Unknown_Keymap.Exit_Status /= 0
         and then Index (Unknown_Keymap.Errors, "Unknown keymap") > 0,
         "Unknown keymap was not rejected with an error");
   end Check_Command_Line;

   procedure Check_No_Home is
      Directory : Temporary_Directory;
      App       : Session;
   begin
      Create (Directory, "ada-diary-no-home-");
      Ada.Environment_Variables.Clear ("HOME");
      Start_Diary (App, Path (Directory));
      Expect (App, "Keymap: Emacs");
      Send (App, "q");
      Finish (App);
      Ada.Environment_Variables.Set ("HOME", Path (Test_Home));
   end Check_No_Home;

   procedure Check_Emacs is
      Directory : Temporary_Directory;
      App       : Session;
   begin
      Create (Directory, "ada-diary-emacs-");
      Start_Diary (App, Path (Directory));
      Expect (App, "Keymap: Emacs");
      Send (App, "n");
      Send (App, "one two three");
      Send (App, Ctrl ('A') & ESC & "f" & ESC & "d");
      Send (App, Save_Emacs);
      Expect (App, "Entry saved");
      Expect (App, "EDIT ENTRY");
      Check_Content (Path (Directory), "one three" & LF);
      Send (App, [Ctrl ('Y')]);
      Send (App, Save_Emacs);
      Check_Content (Path (Directory), "one two three" & LF);
      Send (App, [US]);
      Send (App, Ctrl ('E') & ESC & DEL);
      Send (App, Ctrl ('B') & Ctrl ('B') & Ctrl ('D'));
      Send (App, Save_Emacs);
      Check_Content (Path (Directory), "on " & LF);
      Send (App, Ctrl ('X') & "u");
      Send (App, Save_Emacs);
      Check_Content (Path (Directory), "one " & LF);
      Send (App, HT & "first" & CR & "second");
      Send (App, Ctrl ('P') & Ctrl ('A') & NUL & Ctrl ('N') & Ctrl ('W'));
      Send (App, Ctrl ('Y') & Ctrl ('Y'));
      Send
        (App,
         ESC & "<" & NUL & ESC & "f" & ESC & "w" & ESC & ">" & Ctrl ('Y'));
      Send (App, Save_Close);
      Expect (App, "Entry saved");
      Check_Content
        (Path (Directory),
         "one " & LF & "first" & LF & "first" & LF & "secondfirst");
      Send (App, Ctrl ('F') & Ctrl ('N') & Ctrl ('P') & Ctrl ('B'));
      Send (App, "e");
      Send (App, Ctrl ('X') & "k");
      Send (App, "q");
      Finish (App);
   end Check_Emacs;

   procedure Check_Helix is
      Directory : Temporary_Directory;
   begin
      Create (Directory, "ada-diary-helix-");
      declare
         App : Session;
      begin
         Start_Diary
           (App,
            Path (Directory),
            [Argument ("--keymap"), Argument ("helix")]);
         Expect (App, "Keymap: Helix");
         Send (App, "n");
         Expect (App, "NOR");
         Send (App, "ihello world" & ESC);
         Send (App, ":w" & CR);
         Expect (App, "Entry saved");
         Check_Content (Path (Directory), "hello world" & LF);
         Send (App, "ggwd");
         Send (App, ":w" & CR);
         Check_Content (Path (Directory), "world" & LF);
         Send (App, "u");
         Send (App, "A!" & ESC);
         Send (App, HT & "o" & UTF8 ("한 줄") & CR & "two" & ESC);
         Send (App, "ggxyp");
         Send (App, "geb;vbd");
         Send (App, "uU");
         Send (App, ":q" & CR);
         Expect (App, "Unsaved changes");
         Send (App, ":wq" & CR);
         Check_Content
           (Path (Directory),
            "hello world!"
            & LF
            & LF
            & UTF8 ("한 줄")
            & LF
            & LF
            & UTF8 ("한 wo"));
         Send (App, "i");
         Expect (App, "EDIT ENTRY");
         Send (App, HT & "%c" & UTF8 ("새 본문") & ESC & ":x" & CR);
         Check_Content
           (Path (Directory), "hello world!" & LF & UTF8 ("새 본문"));
         Send (App, "e" & HT & "ggdd:q!" & CR);
         Expect (App, "Changes discarded");
         Check_Content
           (Path (Directory), "hello world!" & LF & UTF8 ("새 본문"));
         Send (App, "hl");
         Send (App, "m");
         Expect (App, "Keymap: Emacs");
         Send (App, "m");
         Send (App, ":q" & CR);
         Finish (App);
      end;
      declare
         App : Session;
      begin
         Ada.Environment_Variables.Set ("DIARY_KEYMAP", "helix");
         Start_Diary (App, Path (Directory));
         Ada.Environment_Variables.Clear ("DIARY_KEYMAP");
         Expect (App, "Keymap: Helix");
         Send (App, "q");
         Finish (App);
      end;
   end Check_Helix;

   procedure Check_Custom_Bindings is
      Directory : Temporary_Directory;
      Config    : constant String :=
        Path (Test_Home) & "/.ada_tui_diary/config.toml";
   begin
      Create (Directory, "ada-diary-bindings-");
      declare
         App : Session;
      begin
         Start_Diary (App, Path (Directory));
         Send (App, "sb");
         Expect (App, "EDIT KEYBINDINGS");
         Send (App, CR & Ctrl ('U') & "C-x s" & CR);
         Expect (App, "Binding updated");
         Ada.Directories.Create_Path (Path (Test_Home) & "/.ada_tui_diary");
         Ada.Directories.Create_Directory (Config & ".tmp");
         Send (App, "S");
         Expect (App, "Cannot save settings");
         Check
           (not Ada.Directories.Exists (Config),
            "Failed custom save created config");
         Ada.Directories.Delete_Directory (Config & ".tmp");
         Send (App, "S");
         Expect (App, "Settings saved");
         Check
           (Index (Read_File (Config), "save_entry = ""C-x s""") > 0,
            "Custom Emacs key was not saved");
         Send (App, "ncustom" & Ctrl ('X') & "s");
         Check_Content (Path (Directory), "custom" & LF);
         Send (App, "!");
         Send (App, Save_Emacs);
         Check_Content (Path (Directory), "custom" & LF);
         Send (App, Ctrl ('X') & "s");
         Check_Content (Path (Directory), "custom!" & LF);
         Send (App, Ctrl ('X') & "kq");
         Finish (App);
      end;
      declare
         App : Session;
      begin
         Start_Diary (App, Path (Directory));
         Send (App, "e!" & Ctrl ('X') & "s");
         Check_Content (Path (Directory), "custom!!" & LF);
         Send (App, Ctrl ('X') & "k");
         Send (App, "s2b" & CR & Ctrl ('U') & "h" & CR);
         Expect (App, "Key conflict");
         Send (App, Ctrl ('U') & "C-s" & CR);
         Expect (App, "Binding updated");
         Send (App, "S");
         Send (App, "eA?" & ESC);
         Send (App, [Ctrl ('S')]);
         Check_Content (Path (Directory), "custom!!?" & LF);
         Send (App, ":q" & CR & "q");
         Finish (App);
         Check
           (Index (Read_File (Config), "[bindings.emacs]") > 0
            and then Index (Read_File (Config), "[bindings.helix]") > 0,
            "Saving Helix discarded Emacs overrides");
      end;
      declare
         App : Session;
      begin
         Start_Diary
           (App,
            Path (Directory),
            [Argument ("--keymap"), Argument ("emacs")]);
         Send (App, "sb" & CR & Ctrl ('U') & "C-x v" & CR);
         Send (App, [ESC]);
         Send (App, [ESC]);
         Send (App, "e!" & Ctrl ('X') & "s");
         Check_Content (Path (Directory), "custom!!?!" & LF);
         Send (App, Ctrl ('X') & "k");
         Send (App, "sbRS");
         Send (App, "e!" & Save_Emacs);
         Check_Content (Path (Directory), "custom!!?!!" & LF);
         Send (App, Ctrl ('X') & "kq");
         Finish (App);
      end;
      declare
         File : Ada.Text_IO.File_Type;
         App  : Session;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Config);
         Ada.Text_IO.Put_Line (File, "[editor]");
         Ada.Text_IO.Put_Line (File, "keymap = 'emacs'");
         Ada.Text_IO.Put_Line (File, "[bindings.emacs]");
         Ada.Text_IO.Put_Line (File, "move_left = '#' # a literal hash key");
         Ada.Text_IO.Put_Line (File, "[bindings.helix]");
         Ada.Text_IO.Put_Line (File, "insert_before = 'Z'");
         Ada.Text_IO.Put_Line (File, "save_entry = 'C-s'");
         Ada.Text_IO.Close (File);
         Start_Diary (App, Path (Directory));
         Send (App, "e#X");
         Send (App, Save_Emacs);
         Check_Content (Path (Directory), "custom!!?!X!" & LF);
         Send (App, Ctrl ('X') & "k");
         Send (App, "s" & CR);
         Check
           (Index (Read_File (Config), "move_left = ""#""") > 0,
            "Hash key did not round-trip through TOML");
         Send (App, "meggiZHELIX" & ESC & Ctrl ('S'));
         Check_Content (Path (Directory), "HELIXcustom!!?!X!" & LF);
         Send (App, ":q" & CR & "q");
         Finish (App);
      end;
      declare
         File : Ada.Text_IO.File_Type;
         App  : Session;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Config);
         Ada.Text_IO.Put_Line (File, "[editor]");
         Ada.Text_IO.Put_Line (File, "keymap = 'emacs'");
         Ada.Text_IO.Put_Line (File, "[bindings.emacs]");
         Ada.Text_IO.Put_Line (File, "calendar_quit = ''");
         Ada.Text_IO.Put_Line (File, "word_forward = ''");
         Ada.Text_IO.Close (File);
         Start_Diary (App, Path (Directory));
         Send (App, "Q");
         Send (App, "e" & Ctrl ('A') & ESC & "FX" & Save_Emacs);
         Check_Content (Path (Directory), "XHELIXcustom!!?!X!" & LF);
         Send (App, Ctrl ('X') & "ksbDSq");
         Finish (App);
      end;
      declare
         Bad_Values : constant Arguments :=
           [Argument ("save_entry = 'g'" & LF & "move_left = 'g g'"),
            Argument ("save_entry = 'C-j'"),
            Argument ("save_entry = 'M-['"),
            Argument ("save_entry = 'M-z Esc'"),
            Argument ("not_an_action = 'x'"),
            Argument ("save_entry = 'M-s'" & LF & "save_entry = 'M-s'")];
         File       : Ada.Text_IO.File_Type;
      begin
         for Bad of Bad_Values loop
            Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Config);
            Ada.Text_IO.Put_Line (File, "[bindings.emacs]");
            Ada.Text_IO.Put_Line (File, To_String (Bad));
            Ada.Text_IO.Close (File);
            declare
               Before : constant String := Read_File (Config);
               Result : constant Captured_Result :=
                 Capture
                   (Diary,
                    [Argument ("--data-dir"), Argument (Path (Directory))]);
            begin
               Check
                 (Result.Exit_Status /= 0
                  and then Index (Result.Errors, "config.toml") > 0,
                  "Invalid custom binding was accepted: " & To_String (Bad));
               Check
                 (Read_File (Config) = Before,
                  "Invalid custom config was overwritten");
            end;
         end loop;
      end;
      Ada.Directories.Delete_File (Config);
   end Check_Custom_Bindings;

   procedure Check_Settings is
      Directory : Temporary_Directory;
      Config    : constant String :=
        Path (Test_Home) & "/.ada_tui_diary/config.toml";
   begin
      Create (Directory, "ada-diary-settings-");
      declare
         App : Session;
      begin
         Start_Diary (App, Path (Directory));
         Send (App, "s");
         Expect (App, "KEYBINDING SETTINGS");
         Send (App, "2" & CR);
         Expect (App, "Settings saved");
         Check
           (Index (Read_File (Config), "keymap = ""helix""") > 0,
            "Settings did not persist Helix");
         Send (App, "q");
         Finish (App);
      end;
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Config);
         Ada.Text_IO.Put_Line (File, HT & "[editor] # keymap preference");
         Ada.Text_IO.Put_Line
           (File, HT & "keymap" & HT & "=" & HT & "'helix' # saved");
         Ada.Text_IO.Close (File);
      end;
      declare
         App : Session;
      begin
         Start_Diary (App, Path (Directory));
         Expect (App, "Keymap: Helix");
         Send (App, "s1");
         Send (App, [ESC]);
         Expect (App, "Keymap: Helix");
         Check
           (Index (Read_File (Config), "helix") > 0,
            "Cancelled settings changed config");
         Send (App, "q");
         Finish (App);
      end;
      declare
         App : Session;
      begin
         Ada.Environment_Variables.Set ("DIARY_KEYMAP", "emacs");
         Start_Diary (App, Path (Directory));
         Expect (App, "Keymap: Emacs");
         Send (App, "q");
         Finish (App);
         Start_Diary
           (App,
            Path (Directory),
            [Argument ("--keymap"), Argument ("helix")]);
         Ada.Environment_Variables.Clear ("DIARY_KEYMAP");
         Expect (App, "Keymap: Helix");
         Send (App, "q");
         Finish (App);
         Check
           (Index (Read_File (Config), "helix") > 0,
            "Runtime override rewrote config");
      end;
      declare
         App : Session;
      begin
         Start_Diary (App, Path (Directory));
         Send (App, "s1" & CR);
         Expect (App, "Settings saved");
         Check
           (Index (Read_File (Config), "emacs") > 0,
            "Cannot replace saved settings");
         Send (App, "s2" & CR);
         Expect (App, "Settings saved");
         Send (App, "q");
         Finish (App);
      end;
      -- A directory at the temp path forces a real atomic-save failure.
      Ada.Directories.Create_Directory (Config & ".tmp");
      declare
         App : Session;
      begin
         Start_Diary (App, Path (Directory));
         Send (App, "s1" & CR);
         Expect (App, "Cannot save settings");
         Check
           (Index (Read_File (Config), "helix") > 0,
            "Failed save damaged original config");
         Send (App, [ESC]);
         Send (App, "q");
         Finish (App);
      end;
      Ada.Directories.Delete_Directory (Config & ".tmp");
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Config);
         Ada.Text_IO.Put_Line (File, "[editor]");
         Ada.Text_IO.Put_Line (File, "keymap = ""vim""");
         Ada.Text_IO.Close (File);
      end;
      declare
         Result : constant Captured_Result :=
           Capture
             (Diary, [Argument ("--data-dir"), Argument (Path (Directory))]);
      begin
         Check
           (Result.Exit_Status /= 0
            and then Index (Result.Errors, "config.toml") > 0,
            "Malformed config was not reported");
         Check
           (Index (Read_File (Config), "vim") > 0,
            "Malformed config was overwritten");
      end;
   end Check_Settings;

   procedure Check_Emacs_Extended is
      Directory : Temporary_Directory;
      App       : Session;
   begin
      Create (Directory, "ada-diary-emacs-extended-");
      Start_Diary
        (App, Path (Directory), [Argument ("--keymap"), Argument ("emacs")]);
      Send (App, "nalpha beta alpha");
      Send (App, Ctrl ('A') & Ctrl ('S') & "beta" & CR & "!");
      Send (App, Save_Emacs);
      Check_Content (Path (Directory), "alpha beta! alpha" & LF);
      Send (App, Ctrl ('R') & "alpha" & Ctrl ('G') & "?");
      Send (App, Save_Emacs);
      Check_Content (Path (Directory), "alpha beta!? alpha" & LF);
      Send (App, Ctrl ('A') & ESC & "d");
      Send (App, Ctrl ('E') & ESC & DEL);
      Send (App, Ctrl ('Y') & ESC & "y");
      Send (App, Save_Emacs);
      Check_Content (Path (Directory), " beta!? alpha" & LF);
      Send (App, Ctrl ('A') & NUL & Ctrl ('E') & Ctrl ('W') & "one two three");
      Send (App, Ctrl ('A') & ESC & "d" & ESC & "d" & Ctrl ('Y'));
      Send (App, Save_Emacs);
      Check_Content (Path (Directory), "one two three" & LF);
      Send (App, Ctrl ('A') & ESC & "d" & Ctrl ('E') & ESC & DEL);
      Send (App, Ctrl ('Y') & ESC & "y");
      Send (App, Save_Emacs);
      Check_Content (Path (Directory), " two one" & LF);
      Send (App, HT & UTF8 ("첫째 줄") & CR & UTF8 ("가나다 줄"));
      Send (App, ESC & "<" & Ctrl ('S') & UTF8 ("가나다") & CR & "!");
      Send (App, Save_Emacs);
      Check_Content
        (Path (Directory),
         " two one" & LF & UTF8 ("첫째 줄") & LF & UTF8 ("가나다! 줄"));
      Send (App, HT & Ctrl ('A') & NUL & Ctrl ('E') & Ctrl ('W') & "abc");
      Send (App, NUL & Ctrl ('A') & Ctrl ('D') & Ctrl ('W'));
      Send (App, Save_Emacs);
      Check_Content
        (Path (Directory),
         "bc" & LF & UTF8 ("첫째 줄") & LF & UTF8 ("가나다! 줄"));
      Send (App, Ctrl ('A') & NUL & Ctrl ('E') & Ctrl ('W') & "ababa");
      Send
        (App,
         Ctrl ('A')
         & Ctrl ('F')
         & Ctrl ('F')
         & Ctrl ('F')
         & Ctrl ('R')
         & "aba"
         & CR
         & "!");
      Send (App, Save_Emacs);
      Check_Content
        (Path (Directory),
         "!ababa" & LF & UTF8 ("첫째 줄") & LF & UTF8 ("가나다! 줄"));
      Send (App, Ctrl ('A') & NUL & Ctrl ('E') & Ctrl ('W') & "aaa");
      Send (App, Ctrl ('A') & Ctrl ('S') & "a" & Ctrl ('S') & CR & "!");
      Send (App, Save_Emacs);
      Check_Content
        (Path (Directory),
         "aa!a" & LF & UTF8 ("첫째 줄") & LF & UTF8 ("가나다! 줄"));
      Send (App, Ctrl ('X') & "kq");
      Finish (App);
   end Check_Emacs_Extended;

   procedure Check_Helix_Extended is
      Directory : Temporary_Directory;
      App       : Session;
   begin
      Create (Directory, "ada-diary-helix-extended-");
      Start_Diary
        (App, Path (Directory), [Argument ("--keymap"), Argument ("helix")]);
      Send (App, "niabcdef abcdef" & ESC);
      Send (App, "gg3lrx:w" & CR);
      Check_Content (Path (Directory), "abcxef abcdef" & LF);
      Send (App, "ggfed:w" & CR);
      Check_Content (Path (Directory), "f abcdef" & LF);
      Send (App, "/abc" & CR & "cXYZ" & ESC & ":w" & CR);
      Check_Content (Path (Directory), "f XYZdef" & LF);
      Send (App, "gg99" & ESC);
      Send (App, "lr!:w" & CR);
      Check_Content (Path (Directory), "f!XYZdef" & LF);
      Send (App, "%cone two three" & ESC & "gg2wd:w" & CR);
      Check_Content (Path (Directory), "three" & LF);
      Send (App, "%y3p/three" & CR & "nNrX:w" & CR);
      Check_Content (Path (Directory), "XXXXXthreethreethree" & LF);
      Send (App, HT & "i" & UTF8 ("가나") & CR & UTF8 ("다라가") & ESC);
      Send (App, "ggf" & UTF8 ("다") & "d:w" & CR);
      Check_Content
        (Path (Directory), "XXXXXthreethreethree" & LF & UTF8 ("라가"));
      Send (App, HT & "%caxbxc" & ESC & "ggtx" & ESC & ".d:w" & CR);
      Check_Content (Path (Directory), "xc" & LF & UTF8 ("라가"));
      Send (App, "%cabc" & ESC & "hrx:w" & CR);
      Check_Content (Path (Directory), "axc" & LF & UTF8 ("라가"));
      Send (App, ":q" & CR & "q");
      Finish (App);
   end Check_Helix_Extended;

   procedure Check_Calendar is
      Directory  : Temporary_Directory;
      Saved_File : Unbounded_String;
      Saved      : constant String :=
        "ADA-DIARY-1"
        & LF
        & UTF8 ("한글 제목")
        & LF
        & UTF8 ("첫 번째 줄")
        & LF
        & UTF8 ("두 번째 줄");
   begin
      Create (Directory, "ada-diary-tui-");
      declare
         App : Session;
      begin
         Start_Diary (App, Path (Directory));
         Expect (App, "ADA DIARY");
         Send (App, "n");
         Expect (App, "NEW ENTRY");
         Send (App, Save_Emacs);
         Expect (App, "Enter a nonblank title");
         Check
           (Diary_File_Count (Path (Directory)) = 0,
            "Blank title created a file");
         Send
           (App,
            UTF8 ("한글 제목")
            & HT
            & UTF8 ("첫 번째 줄")
            & CR
            & UTF8 ("두 번째 줄"));
         Send (App, ESC & "[3~" & ESC & "[1;5C");
         Send (App, Save_Close);
         Expect (App, "Entry saved");
         Saved_File :=
           To_Unbounded_String (Only_Diary_File (Path (Directory)));
         Check
           (Read_File (To_String (Saved_File)) = Saved,
            "Saved Unicode entry differs");
         Send (App, "q");
         Finish (App);
      end;
      declare
         App  : Session;
         File : constant String := To_String (Saved_File);
      begin
         Start_Diary (App, Path (Directory));
         Resize (App, 12, 40);
         Expect (App, "Resize terminal");
         Send (App, "dy");
         Check
           (Ada.Directories.Exists (File),
            "Small-screen commands deleted entry");
         Resize (App, 30, 110);
         Send (App, "e");
         Expect (App, "EDIT ENTRY");
         Resize (App, 12, 40);
         Send (App, "invisible" & Ctrl ('S') & ESC & "y");
         Check (Read_File (File) = Saved, "Small-screen input changed entry");
         Resize (App, 30, 110);
         Send (App, Ctrl ('E') & "!");
         Send (App, Save_Close);
         Check
           (Index (Read_File (File), UTF8 ("한글 제목!")) > 0,
            "Updated title was not saved");
         Send (App, "e");
         Send (App, "x" & ESC);
         Expect (App, "Discard changes?");
         Send (App, "n");
         Send (App, [ESC]);
         Send (App, "y");
         Check
           (Index (Read_File (File), UTF8 ("한글 제목!")) > 0,
            "Discard changed the saved title");
         Send (App, "d");
         Expect (App, "Delete this entry?");
         Send (App, "n");
         Check
           (Ada.Directories.Exists (File), "Declined deletion removed entry");
         Send (App, ESC & "[D");
         Send (App, ESC & "[C");
         Send (App, "d");
         Send (App, "y");
         Check
           (not Ada.Directories.Exists (File),
            "Confirmed deletion left entry");
         Resize (App, 12, 40);
         Expect (App, "Resize terminal");
         Resize (App, 30, 110);
         Send (App, "q");
         Finish (App);
      end;
      Check
        (not Ada.Directories.Exists (Path (Directory) & "/.lock"),
         "Diary left a lock");
   end Check_Calendar;
begin
   Create (Test_Home, "ada-diary-home-");
   Ada.Environment_Variables.Set ("HOME", Path (Test_Home));
   Ada.Environment_Variables.Set ("TERM", "xterm-256color");
   Ada.Environment_Variables.Set ("COLORTERM", "truecolor");
   Ada.Environment_Variables.Clear ("DIARY_KEYMAP");
   if Ada.Command_Line.Argument_Count > 0 then
      case Ada.Command_Line.Argument (1) (1) is
         when 's'    =>
            Check_Settings;

         when 'e'    =>
            Check_Emacs_Extended;

         when 'h'    =>
            Check_Helix_Extended;

         when 'c'    =>
            Check_Custom_Bindings;

         when others =>
            raise Program_Error with "Unknown smoke scenario";
      end case;
      return;
   end if;
   Check_Command_Line;
   Check_No_Home;
   Check_Emacs;
   Check_Helix;
   Check_Calendar;
   Check_Emacs_Extended;
   Check_Helix_Extended;
   Check_Custom_Bindings;
   Check_Settings;
   Ada.Text_IO.Put_Line
     ("PASS TUI calendar, Unicode CRUD, restart, confirmations, resize and both keymaps");
end TUI_Smoke;
