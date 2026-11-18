with Ada.Text_IO;
with Ada.Strings.Wide_Wide_Unbounded;
with Diary_Dates;
with Diary_Entries;
with Diary_File_Codec;
with Diary_Repositories;

procedure Codec_Tests is
   use Ada.Strings.Wide_Wide_Unbounded;
   Header : constant String := "ADA-DIARY-1" & ASCII.LF;
   Mark   : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#FEFF#);
   BOM    : constant String :=
     Character'Val (16#EF#) & Character'Val (16#BB#) & Character'Val (16#BF#);
   Item   : Diary_Entries.Entry_Data;
   procedure Reject (Value : String) is
   begin
      Item :=
        Diary_File_Codec.Decode (Diary_Dates.Create (2026, 11, 18), Value);
      raise Program_Error with "Accepted noncanonical UTF-8";
   exception
      when Diary_Repositories.Storage_Error =>
         null;
   end Reject;
begin
   Item :=
     Diary_File_Codec.Decode
       (Diary_Dates.Create (2026, 11, 18),
        Header & BOM & "Title" & ASCII.LF & BOM & "Body");
   if To_Wide_Wide_String (Item.Title) /= Mark & "Title"
     or else To_Wide_Wide_String (Item.Content) /= Mark & "Body"
   then
      raise Program_Error with "Leading field BOM was lost";
   end if;
   Reject
     (Header
      & Character'Val (16#C1#)
      & Character'Val (16#A1#)
      & ASCII.LF
      & "body");
   Reject
     (Header
      & Character'Val (16#ED#)
      & Character'Val (16#A0#)
      & Character'Val (16#80#)
      & ASCII.LF);
   Ada.Text_IO.Put_Line
     ("PASS codec preserves field BOMs and rejects invalid UTF-8");
end Codec_Tests;
