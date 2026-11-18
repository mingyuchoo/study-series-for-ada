with Ada.Text_IO;
with Diary_Editor;
with Diary_Text;

procedure Editor_Tests is
   use Diary_Editor;
   Buffer : Text_Buffer;
   First  : Natural;
   Last   : Natural;
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
   Load (Buffer, "hello, 한글 world");
   Move (Buffer, Buffer_Start);
   Move (Buffer, Word_Forward);
   Check (Position (Buffer) = 5, "word forward stops after word");
   Move (Buffer, Word_Forward);
   Check (Position (Buffer) = 9, "word forward skips punctuation");
   Move (Buffer, Word_Backward);
   Check (Position (Buffer) = 7, "word backward");
   Move (Buffer, Buffer_End);
   Check (Position (Buffer) = 15, "buffer end");
   Set_Position (Buffer, 99);
   Check (Position (Buffer) = 15, "position is clamped");
   Remove (Buffer, 5, 9);
   Check (Text (Buffer) = "hello world", "remove range");
   Check (Position (Buffer) = 5, "remove leaves cursor at start");
   Remove (Buffer, 11, 20);
   Check (Text (Buffer) = "hello world", "remove past end");
   Set_Position (Buffer, 5);
   Insert (Buffer, ", 한글");
   Check (Text (Buffer) = "hello, 한글 world", "insert string");
   Check (Position (Buffer) = 9, "insert string advances cursor");
   Set_Position (Buffer, 0);
   Word_Range (Buffer, Next_Word_Start, First, Last);
   Check (First = 0 and then Last = 4, "next word start stops at comma");
   Set_Position (Buffer, 4);
   Word_Range (Buffer, Next_Word_Start, First, Last);
   Check (First = 5 and then Last = 6, "next word start from boundary");
   Set_Position (Buffer, 5);
   Word_Range (Buffer, Next_Word_End, First, Last);
   Check (First = 6 and then Last = 8, "next word end");
   Set_Position (Buffer, 10);
   Word_Range (Buffer, Previous_Word_Start, First, Last);
   Check (First = 9 and then Last = 7, "previous word start");
   Set_Position (Buffer, 15);
   Word_Range (Buffer, Previous_Word_Start, First, Last);
   Check (First = 14 and then Last = 10, "previous word from end");
   Word_Range (Buffer, Next_Word_Start, First, Last);
   Check (First = 15 and then Last = 15, "word motion at end");
   Load (Buffer, "");
   for Motion in Word_Motion loop
      Word_Range (Buffer, Motion, First, Last);
      Check (First = 0 and then Last = 0, "empty word motion");
   end loop;
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
