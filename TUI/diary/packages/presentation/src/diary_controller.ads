with Diary_Bindings;
with Diary_Dates;
with Diary_Keymaps;
with Diary_Repositories;
with Diary_Screen;

package Diary_Controller is
   procedure Run
     (Store    : in out Diary_Repositories.Repository'Class;
      Screen   : in out Diary_Screen.Port'Class;
      Today    : Diary_Dates.Date;
      Keymap   : Diary_Keymaps.Kind := Diary_Keymaps.Emacs;
      Bindings : Diary_Bindings.Binding_Table := Diary_Bindings.Defaults);
end Diary_Controller;
