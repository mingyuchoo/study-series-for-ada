with Ada.Strings.Wide_Wide_Unbounded;
with Diary_Dates;
with Diary_Editor;
with Diary_Entries;
with Diary_Keymaps;
with Diary_Service;

package Diary_Screen_State is
   type Screen_Mode is (Reading, Editing, Confirm_Delete, Confirm_Discard);
   type Edit_Field is (Title_Field, Body_Field);
   type Modal_Mode is (Normal_Mode, Insert_Mode, Select_Mode);
   type State is record
      Selected     : Diary_Dates.Date;
      Today        : Diary_Dates.Date;
      Item         : Diary_Entries.Entry_Data;
      Exists       : Boolean := False;
      Read_Failed  : Boolean := False;
      Markers      : Diary_Service.Day_Markers := [others => False];
      Mode         : Screen_Mode := Reading;
      Field        : Edit_Field := Title_Field;
      Title        : Diary_Editor.Text_Buffer;
      Content      : Diary_Editor.Text_Buffer;
      Was_Existing : Boolean := False;
      Scroll       : Natural := 0;
      Keymap       : Diary_Keymaps.Kind := Diary_Keymaps.Emacs;
      Modal        : Modal_Mode := Normal_Mode;
      Anchor       : Natural := 0;
      Mark_Active  : Boolean := False;
      Select_From  : Natural := 0;
      Select_To    : Natural := 0;
      Prompt_Shown : Boolean := False;
      Prompt       :
        Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
      Message      :
        Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
   end record;
end Diary_Screen_State;
