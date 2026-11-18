with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Test_Fixtures;
with Test_Processes;
with Test_Terminals;

procedure TUI_Smoke is
   use Ada.Strings.Unbounded;
   use Test_Fixtures;
   use Test_Processes;
   use Test_Terminals;

   Program  : constant String := Sibling_Executable ("tui_template");
   Help     : constant Captured_Result :=
     Capture (Program, [Argument ("--help")]);
   Invalid  : constant Captured_Result :=
     Capture (Program, [Argument ("--unknown")]);
   Terminal : Session;
begin
   Check (Help.Exit_Status = 0, "Help command failed");
   Check (Index (Help.Output, "Usage: tui_template") > 0, "Help lacks usage");
   Check (Invalid.Exit_Status /= 0, "Accepted an unknown option");

   Open (Terminal, Program, [], Rows => 4, Columns => 40);
   Expect (Terminal, "TUI Template");
   Expect (Terminal, "Status: Idle");
   Send (Terminal, " ");
   Expect (Terminal, "Status: Active");
   Resize (Terminal, Rows => 10, Columns => 60);
   Expect (Terminal, "Space: toggle");
   Send (Terminal, " ");
   Expect (Terminal, "Status: Idle");
   Send (Terminal, "q");
   Finish (Terminal);
   Ada.Text_IO.Put_Line ("TUI smoke tests passed");
end TUI_Smoke;
