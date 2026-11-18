with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Strings.Wide_Wide_Fixed;
with Diary_Repositories;

package body Diary_File_Codec is
   use Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
   use Ada.Strings.Wide_Wide_Unbounded;
   Header : constant String := "ADA-DIARY-1" & ASCII.LF;
   function Encode (Item : Diary_Entries.Entry_Data) return String is
   begin
      return
        Header
        & Encode (To_Wide_Wide_String (Item.Title))
        & ASCII.LF
        & Encode (To_Wide_Wide_String (Item.Content));
   end Encode;
   function Decode
     (Day : Diary_Dates.Date; Value : String) return Diary_Entries.Entry_Data
   is
      Data        : constant Wide_Wide_String := Decode (Value);
      Wide_Header : constant Wide_Wide_String :=
        "ADA-DIARY-1" & Wide_Wide_Character'Val (10);
      Separator   : Natural;
      Result      : Diary_Entries.Entry_Data;
   begin
      if Encode (Data) /= Value then
         raise Diary_Repositories.Storage_Error
           with "Noncanonical UTF-8 diary contents";
      elsif Data'Length < Wide_Header'Length + 1
        or else Data (1 .. Wide_Header'Length) /= Wide_Header
      then
         raise Diary_Repositories.Storage_Error
           with "Unrecognized diary file format";
      end if;
      Separator :=
        Ada.Strings.Wide_Wide_Fixed.Index
          (Data,
           Wide_Wide_String'(1 => Wide_Wide_Character'Val (10)),
           From => Wide_Header'Length + 1);
      if Separator = 0 then
         raise Diary_Repositories.Storage_Error
           with "Diary title separator is missing";
      end if;
      Result :=
        (Day,
         To_Unbounded_Wide_Wide_String
           (Data (Wide_Header'Length + 1 .. Separator - 1)),
         To_Unbounded_Wide_Wide_String (Data (Separator + 1 .. Data'Last)));
      if not Diary_Entries.Is_Valid (Result) then
         raise Diary_Repositories.Storage_Error with "Invalid diary contents";
      end if;
      return Result;
   exception
      when Ada.Strings.UTF_Encoding.Encoding_Error =>
         raise Diary_Repositories.Storage_Error
           with "Invalid UTF-8 diary contents";
   end Decode;
end Diary_File_Codec;
