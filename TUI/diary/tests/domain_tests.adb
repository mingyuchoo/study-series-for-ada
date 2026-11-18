with Ada.Text_IO;
with Ada.Strings.Wide_Wide_Unbounded;
with Diary_Dates;
with Diary_Entries;

procedure Domain_Tests is
   use Diary_Dates;
   use Ada.Strings.Wide_Wide_Unbounded;
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then
         raise Program_Error with Name;
      end if;
   end Check;
   procedure Reject_Date (Text : String) is
      Result : Date;
   begin
      Result := Parse (Text);
      raise Program_Error with "Accepted invalid date: " & Image (Result);
   exception
      when Invalid_Date =>
         null;
   end Reject_Date;
   Entry_Item : Diary_Entries.Entry_Data;
begin
   Check (Days_In_Month (2000, 2) = 29, "400-year leap");
   Check (Days_In_Month (1900, 2) = 28, "century common");
   Check (Days_In_Month (2024, 2) = 29, "four-year leap");
   Check (Weekday (Create (2026, 11, 18)) = 2, "Wednesday Monday-zero");
   Check (Weekday (Create (2000, 1, 1)) = 5, "Saturday");
   Check
     (Image (Shift_Days (Create (2024, 2, 28), 1)) = "2024-02-29", "leap day");
   Check
     (Image (Shift_Days (Create (2024, 3, 1), -1)) = "2024-02-29",
      "backward leap");
   Check
     (Image (Shift_Days (Create (2025, 12, 31), 1)) = "2026-01-01",
      "year rollover");
   Check
     (Image (Shift_Month (Create (2024, 1, 31), 1)) = "2024-02-29",
      "month clamp");
   Check
     (Image (Shift_Month (Create (2026, 1, 31), -1)) = "2025-12-31",
      "backward year");
   Check
     (Shift_Days (Create (1, 1, 1), -1) = Create (1, 1, 1), "minimum clamp");
   Check
     (Shift_Days (Create (9999, 12, 31), 1) = Create (9999, 12, 31),
      "maximum clamp");
   Check (Parse ("2026-11-18") = Create (2026, 11, 18), "parse");
   Reject_Date ("2025-02-29");
   Reject_Date ("2026/11/18");
   Reject_Date ("2026-1a-18");
   Reject_Date ("0000-01-01");
   Entry_Item :=
     (Day     => Create (2026, 11, 18),
      Title   => To_Unbounded_Wide_Wide_String ("오늘의 기록"),
      Content =>
        To_Unbounded_Wide_Wide_String
          ("안녕하세요" & Wide_Wide_Character'Val (10) & "두 번째 줄"));
   Check (Diary_Entries.Is_Valid (Entry_Item), "Unicode entry");
   Entry_Item.Title :=
     To_Unbounded_Wide_Wide_String ("   " & Wide_Wide_Character'Val (9));
   Check (not Diary_Entries.Is_Valid (Entry_Item), "blank title");
   Entry_Item.Title :=
     To_Unbounded_Wide_Wide_String ("Title" & Wide_Wide_Character'Val (10));
   Check (not Diary_Entries.Is_Valid (Entry_Item), "multiline title");
   Entry_Item.Title := To_Unbounded_Wide_Wide_String ("Title");
   Entry_Item.Content :=
     To_Unbounded_Wide_Wide_String ("escape" & Wide_Wide_Character'Val (27));
   Check (not Diary_Entries.Is_Valid (Entry_Item), "terminal control");
   Entry_Item.Title :=
     To_Unbounded_Wide_Wide_String ([1 => Wide_Wide_Character'Val (16#3000#)]);
   Entry_Item.Content := Null_Unbounded_Wide_Wide_String;
   Check
     (not Diary_Entries.Is_Valid (Entry_Item), "full-width whitespace title");
   Entry_Item.Title :=
     To_Unbounded_Wide_Wide_String ([1 => Wide_Wide_Character'Val (16#D800#)]);
   Check (not Diary_Entries.Is_Valid (Entry_Item), "surrogate title");
   Ada.Text_IO.Put_Line ("PASS domain dates and entry validation");
end Domain_Tests;
