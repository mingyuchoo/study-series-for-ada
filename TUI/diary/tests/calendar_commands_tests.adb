with Ada.Text_IO;
with Diary_Calendar_Commands;
with Diary_Input;
with Diary_Keymaps;

procedure Calendar_Commands_Tests is
   use Diary_Calendar_Commands;
   use Diary_Input;
   use Diary_Keymaps;
begin
   pragma Assert (Resolve ((Left_Key, ' '), Emacs) = Day_Back);
   pragma Assert (Resolve ((Meta_Key, '}'), Helix) = Month_Forward);
   pragma Assert (Resolve ((Character_Key, 'j'), Emacs) = Scroll_Down);
   pragma Assert (Resolve ((Character_Key, 'j'), Helix) = Week_Forward);
   pragma Assert (Resolve ((Character_Key, ':'), Helix) = Open_Prompt);
   pragma Assert (Resolve ((Character_Key, ':'), Emacs) = No_Command);
   pragma Assert (Resolve ((Resize_Key, 'q'), Emacs) = No_Command);
   Ada.Text_IO.Put_Line ("PASS calendar commands for Emacs and Helix");
end Calendar_Commands_Tests;
