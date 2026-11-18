with Diary_Dates;
with Diary_Repositories;

package Diary_App is
   procedure Run (Store : in out Diary_Repositories.Repository'Class; Today : Diary_Dates.Date);
end Diary_App;
