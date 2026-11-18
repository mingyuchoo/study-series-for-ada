with Ada.Characters.Latin_1;
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

   Diary : constant String := Sibling_Executable ("diary");

   function Ctrl (Key : Character) return Character
   is (Character'Val (Character'Pos (Key) mod 32));

   Save_Emacs : constant String := [Ctrl ('X'), Ctrl ('S')];

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
      Send (App, [Ctrl ('S')]);
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
         Send (App, [Ctrl ('S')]);
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
         Send (App, [Ctrl ('S')]);
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
         Send (App, [Ctrl ('S')]);
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
   Ada.Environment_Variables.Set ("TERM", "xterm-256color");
   Ada.Environment_Variables.Set ("COLORTERM", "truecolor");
   Ada.Environment_Variables.Clear ("DIARY_KEYMAP");
   Check_Command_Line;
   Check_Emacs;
   Check_Helix;
   Check_Calendar;
   Ada.Text_IO.Put_Line
     ("PASS TUI calendar, Unicode CRUD, restart, confirmations, resize and both keymaps");
end TUI_Smoke;
