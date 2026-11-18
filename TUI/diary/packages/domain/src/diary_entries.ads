with Ada.Strings.Wide_Wide_Unbounded;
with Diary_Dates;

package Diary_Entries is
   type Entry_Data is record
      Day     : Diary_Dates.Date;
      Title   : Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
      Content : Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
   end record;
   function Is_Valid (Value : Entry_Data) return Boolean;
end Diary_Entries;
