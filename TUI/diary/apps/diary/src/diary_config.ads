with Diary_Keymaps;
with Diary_Bindings;

package Diary_Config is
   Config_Error : exception;
   function File_Name return String;
   function Load_Settings return Diary_Bindings.Preferences;
   procedure Save (Value : Diary_Bindings.Preferences);
   function Load return Diary_Keymaps.Kind;
   procedure Save (Keymap : Diary_Keymaps.Kind);
end Diary_Config;
