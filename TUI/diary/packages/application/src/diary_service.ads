with Diary_Dates;
with Diary_Entries;
with Diary_Repositories;

package Diary_Service is
   type Outcome is (Success, Already_Exists, Not_Found, Invalid_Entry);
   type Day_Markers is array (Diary_Dates.Day_Number) of Boolean;
   function Create (Store : in out Diary_Repositories.Repository'Class; Item : Diary_Entries.Entry_Data) return Outcome;
   function Update (Store : in out Diary_Repositories.Repository'Class; Item : Diary_Entries.Entry_Data) return Outcome;
   function Delete (Store : in out Diary_Repositories.Repository'Class; Day : Diary_Dates.Date) return Outcome;
   function Read (Store : in out Diary_Repositories.Repository'Class; Day : Diary_Dates.Date) return Diary_Repositories.Entry_Result;
   function Month_Days (Store : in out Diary_Repositories.Repository'Class; Day : Diary_Dates.Date) return Day_Markers;
end Diary_Service;
