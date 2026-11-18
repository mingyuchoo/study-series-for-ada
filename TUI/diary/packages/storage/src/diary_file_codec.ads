with Diary_Dates;
with Diary_Entries;

package Diary_File_Codec is
   function Encode (Item : Diary_Entries.Entry_Data) return String;
   function Decode
     (Day : Diary_Dates.Date; Value : String) return Diary_Entries.Entry_Data;
end Diary_File_Codec;
