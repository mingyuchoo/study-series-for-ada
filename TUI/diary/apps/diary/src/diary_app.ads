with Diary_Dates;
with Diary_Keymaps;
with Diary_Repositories;

package Diary_App is
   procedure Run
     (Store  : in out Diary_Repositories.Repository'Class;
      Today  : Diary_Dates.Date;
      Keymap : Diary_Keymaps.Kind := Diary_Keymaps.Emacs);
end Diary_App;
