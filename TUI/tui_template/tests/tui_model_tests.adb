with Ada.Text_IO;
with Test_Fixtures;
with Tui_Input;
with Tui_Model;

procedure Tui_Model_Tests is
   use Test_Fixtures;
   use Tui_Input;
   use Tui_Model;
begin
   Check (Update (Idle, (Character_Key, ' ')) = Active, "Space activates");
   Check (Update (Active, (Character_Key, ' ')) = Idle, "Space deactivates");
   for Current in State loop
      Check (Update (Current, (Character_Key, 'q')) = Quit, "Lowercase quit");
      Check (Update (Current, (Character_Key, 'Q')) = Quit, "Uppercase quit");
      Check (Update (Current, (Character_Key, 'x')) = Current, "Unused key");
      for Kind in Key_Kind loop
         if Kind /= Character_Key then
            Check
              (Update (Current, (Kind, 'q')) = Current,
               "Non-character event changes state: " & Kind'Image);
         end if;
      end loop;
   end loop;
   Check (Update (Quit, (Character_Key, ' ')) = Quit, "Quit is final");
   Ada.Text_IO.Put_Line ("TUI model tests passed");
end Tui_Model_Tests;
