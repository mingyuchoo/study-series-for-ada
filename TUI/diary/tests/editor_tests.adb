with Ada.Text_IO;
with Diary_Editor;
with Diary_Text;

procedure Editor_Tests is
   use Diary_Editor;
   Buffer : Text_Buffer;
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then
         raise Program_Error with Name;
      end if;
   end Check;
begin
   Load (Buffer, "가나");
   Move (Buffer, Backward);
   Insert (Buffer, '다');
   Check (Text (Buffer) = "가다나", "Unicode cursor insertion");
   Backspace (Buffer);
   Check (Text (Buffer) = "가나", "Unicode backspace");
   Move (Buffer, Line_Start);
   Backspace (Buffer);
   Check (Text (Buffer) = "가나", "backspace at start");
   Move (Buffer, Line_End);
   Insert (Buffer, Wide_Wide_Character'Val (10));
   Insert (Buffer, 'A');
   Insert (Buffer, 'B');
   Move (Buffer, Upward);
   Check (Position (Buffer) = 2, "up preserves column");
   Move (Buffer, Backward);
   Move (Buffer, Downward);
   Check (Position (Buffer) = 4, "down preserves column");
   Backspace (Buffer);
   Check
     (Text (Buffer) = "가나" & Wide_Wide_Character'Val (10) & "B",
      "delete within multiline");
   Move (Buffer, Line_Start);
   Backspace (Buffer);
   Check (Text (Buffer) = "가나B", "join lines");
   Load (Buffer, "");
   for Direction in Movement loop
      Move (Buffer, Direction);
   end loop;
   Check
     (Position (Buffer) = 0 and then Text (Buffer) = "", "empty navigation");
   Check (Diary_Text.Cell_Width ('한') = 2, "Hangul cell width");
   Check (Diary_Text.Cell_Width ('A') = 1, "ASCII cell width");
   Check
     (Diary_Text.Position_At ("가나다", 2, 4).Row = 1, "wide text wrapping");
   Check
     (Diary_Text.Position_At
        ("abc" & Wide_Wide_Character'Val (10) & "d", 5, 10)
        .Col
      = 1,
      "newline column");
   Check
     (Diary_Text.Position_At
        ("abcd" & Wide_Wide_Character'Val (10) & "X", 6, 4)
        .Row
      = 1,
      "full line newline wraps once");
   Ada.Text_IO.Put_Line ("PASS editor Unicode, cursor and multiline editing");
end Editor_Tests;
