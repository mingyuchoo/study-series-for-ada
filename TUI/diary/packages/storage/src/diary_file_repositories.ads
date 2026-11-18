with Ada.Finalization;
with Ada.Strings.Unbounded;
with Diary_Dates;
with Diary_Entries;
with Diary_Repositories;

package Diary_File_Repositories is
   type File_Repository is new Ada.Finalization.Limited_Controlled and Diary_Repositories.Repository with private;
   procedure Open (Store : in out File_Repository; Directory : String);
   procedure Close (Store : in out File_Repository);
   overriding function Contains (Store : in out File_Repository; Day : Diary_Dates.Date) return Boolean;
   overriding function Read (Store : in out File_Repository; Day : Diary_Dates.Date) return Diary_Repositories.Entry_Result;
   overriding procedure Write (Store : in out File_Repository; Item : Diary_Entries.Entry_Data);
   overriding procedure Remove (Store : in out File_Repository; Day : Diary_Dates.Date);
   overriding procedure Finalize (Store : in out File_Repository);
private
   type File_Repository is new Ada.Finalization.Limited_Controlled and Diary_Repositories.Repository with record
      Directory : Ada.Strings.Unbounded.Unbounded_String;
      Owns_Lock : Boolean := False;
   end record;
end Diary_File_Repositories;
