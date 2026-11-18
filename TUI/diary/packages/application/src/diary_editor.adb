package body Diary_Editor is
   use Ada.Strings.Wide_Wide_Unbounded;
   Newline : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);
   procedure Load (Buffer : out Text_Buffer; Value : Wide_Wide_String) is
   begin
      Buffer := (To_Unbounded_Wide_Wide_String (Value), Value'Length);
   end Load;
   function Text (Buffer : Text_Buffer) return Wide_Wide_String is (To_Wide_Wide_String (Buffer.Content));
   function Position (Buffer : Text_Buffer) return Natural is (Buffer.Cursor);
   procedure Insert (Buffer : in out Text_Buffer; Value : Wide_Wide_Character) is
   begin
      Insert (Buffer.Content, Buffer.Cursor + 1, Wide_Wide_String'(1 => Value));
      Buffer.Cursor := Buffer.Cursor + 1;
   end Insert;
   procedure Backspace (Buffer : in out Text_Buffer) is
   begin
      if Buffer.Cursor > 0 then
         Delete (Buffer.Content, Buffer.Cursor, Buffer.Cursor);
         Buffer.Cursor := Buffer.Cursor - 1;
      end if;
   end Backspace;
   procedure Move (Buffer : in out Text_Buffer; Direction : Movement) is
      Value : constant Wide_Wide_String := Text (Buffer);
      First : Natural := Buffer.Cursor;
      Last : Natural := Buffer.Cursor;
      Column : Natural;
      Target : Natural;
   begin
      while First > 0 and then Value (First) /= Newline loop
         First := First - 1;
      end loop;
      while Last < Value'Length and then Value (Last + 1) /= Newline loop
         Last := Last + 1;
      end loop;
      Column := Buffer.Cursor - First;
      case Direction is
         when Backward => Buffer.Cursor := Natural'Max (1, Buffer.Cursor) - 1;
         when Forward => Buffer.Cursor := Natural'Min (Value'Length, Buffer.Cursor + 1);
         when Line_Start => Buffer.Cursor := First;
         when Line_End => Buffer.Cursor := Last;
         when Upward =>
            if First > 0 then
               Target := First - 1;
               while Target > 0 and then Value (Target) /= Newline loop
                  Target := Target - 1;
               end loop;
               Buffer.Cursor := Natural'Min (First - 1, Target + Column);
            end if;
         when Downward =>
            if Last < Value'Length then
               Target := Last + 1;
               while Target < Value'Length and then Value (Target + 1) /= Newline loop
                  Target := Target + 1;
               end loop;
               Buffer.Cursor := Natural'Min (Target, Last + 1 + Column);
            end if;
      end case;
   end Move;
end Diary_Editor;
