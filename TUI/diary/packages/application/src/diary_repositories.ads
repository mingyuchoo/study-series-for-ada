with Diary_Dates;
with Diary_Entries;

package Diary_Repositories is
   Storage_Error : exception;
   type Entry_Result is record
      Found : Boolean := False;
      Item  : Diary_Entries.Entry_Data;
   end record;
   type Repository is limited interface;
   function Contains
     (Store : in out Repository; Day : Diary_Dates.Date) return Boolean
   is abstract;
   function Read
     (Store : in out Repository; Day : Diary_Dates.Date) return Entry_Result
   is abstract;
   procedure Write (Store : in out Repository; Item : Diary_Entries.Entry_Data)
   is abstract;
   procedure Remove (Store : in out Repository; Day : Diary_Dates.Date)
   is abstract;
end Diary_Repositories;
