with Diary_Input;
with Diary_Keymaps;

package Diary_Calendar_Commands
  with Pure
is
   type Calendar_Command is
     (No_Command,
      Day_Back,
      Day_Forward,
      Week_Back,
      Week_Forward,
      Month_Back,
      Month_Forward,
      Go_Today,
      New_Entry,
      Edit_Entry,
      Delete_Entry,
      Scroll_Down,
      Scroll_Up,
      Switch_Keymap,
      Open_Settings,
      Open_Prompt,
      Quit);
   function Resolve
     (Event : Diary_Input.Input_Event; Keymap : Diary_Keymaps.Kind)
      return Calendar_Command;
end Diary_Calendar_Commands;
