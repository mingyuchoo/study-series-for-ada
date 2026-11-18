package body Diary_Editor is
   use Ada.Strings.Wide_Wide_Unbounded;
   Newline : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);
   type Class is (Blank, Word, Punctuation);
   function Class_Of (Value : Wide_Wide_Character) return Class is
      Code : constant Natural := Wide_Wide_Character'Pos (Value);
   begin
      if Code in 9 | 10 | 13 | 32 then
         return Blank;
      elsif Code in 48 .. 57 | 65 .. 90 | 95 | 97 .. 122 or else Code >= 128
      then
         return Word;
      else
         return Punctuation;
      end if;
   end Class_Of;
   procedure Load (Buffer : out Text_Buffer; Value : Wide_Wide_String) is
   begin
      Buffer := (To_Unbounded_Wide_Wide_String (Value), Value'Length);
   end Load;
   function Text (Buffer : Text_Buffer) return Wide_Wide_String
   is (To_Wide_Wide_String (Buffer.Content));
   function Position (Buffer : Text_Buffer) return Natural
   is (Buffer.Cursor);
   procedure Insert (Buffer : in out Text_Buffer; Value : Wide_Wide_Character)
   is
   begin
      Insert
        (Buffer.Content, Buffer.Cursor + 1, Wide_Wide_String'(1 => Value));
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
      Value  : constant Wide_Wide_String := Text (Buffer);
      First  : Natural := Buffer.Cursor;
      Last   : Natural := Buffer.Cursor;
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
         when Backward      =>
            Buffer.Cursor := Natural'Max (1, Buffer.Cursor) - 1;

         when Forward       =>
            Buffer.Cursor := Natural'Min (Value'Length, Buffer.Cursor + 1);

         when Line_Start    =>
            Buffer.Cursor := First;

         when Line_End      =>
            Buffer.Cursor := Last;

         when Buffer_Start  =>
            Buffer.Cursor := 0;

         when Buffer_End    =>
            Buffer.Cursor := Value'Length;

         when Word_Forward  =>
            Target := Buffer.Cursor;
            while Target < Value'Length
              and then Class_Of (Value (Target + 1)) /= Word
            loop
               Target := Target + 1;
            end loop;
            while Target < Value'Length
              and then Class_Of (Value (Target + 1)) = Word
            loop
               Target := Target + 1;
            end loop;
            Buffer.Cursor := Target;

         when Word_Backward =>
            Target := Buffer.Cursor;
            while Target > 0 and then Class_Of (Value (Target)) /= Word loop
               Target := Target - 1;
            end loop;
            while Target > 0 and then Class_Of (Value (Target)) = Word loop
               Target := Target - 1;
            end loop;
            Buffer.Cursor := Target;

         when Upward        =>
            if First > 0 then
               Target := First - 1;
               while Target > 0 and then Value (Target) /= Newline loop
                  Target := Target - 1;
               end loop;
               Buffer.Cursor := Natural'Min (First - 1, Target + Column);
            end if;

         when Downward      =>
            if Last < Value'Length then
               Target := Last + 1;
               while Target < Value'Length
                 and then Value (Target + 1) /= Newline
               loop
                  Target := Target + 1;
               end loop;
               Buffer.Cursor := Natural'Min (Target, Last + 1 + Column);
            end if;
      end case;
   end Move;
   procedure Set_Position (Buffer : in out Text_Buffer; Value : Natural) is
   begin
      Buffer.Cursor := Natural'Min (Value, Length (Buffer.Content));
   end Set_Position;
   procedure Insert (Buffer : in out Text_Buffer; Value : Wide_Wide_String) is
   begin
      Insert (Buffer.Content, Buffer.Cursor + 1, Value);
      Buffer.Cursor := Buffer.Cursor + Value'Length;
   end Insert;
   procedure Remove (Buffer : in out Text_Buffer; From, To : Natural) is
      Last : constant Natural := Natural'Min (To, Length (Buffer.Content));
   begin
      if From < Last then
         Delete (Buffer.Content, From + 1, Last);
      end if;
      Buffer.Cursor := Natural'Min (From, Length (Buffer.Content));
   end Remove;
   procedure Word_Range
     (Buffer : Text_Buffer;
      Motion : Word_Motion;
      Anchor : out Natural;
      Head   : out Natural)
   is
      Value : constant Wide_Wide_String := Text (Buffer);
      Size  : constant Natural := Value'Length;
      Start : Natural := Buffer.Cursor;
      Index : Natural;
      Kind  : Class;
      function Kind_At (Offset : Natural) return Class
      is (Class_Of (Value (Offset + 1)));
   begin
      Anchor := Buffer.Cursor;
      Head := Buffer.Cursor;
      if Size = 0 then
         return;
      end if;
      case Motion is
         when Next_Word_Start | Next_Word_End =>
            if Start + 1 < Size and then Kind_At (Start) /= Kind_At (Start + 1)
            then
               Start := Start + 1;
            end if;
            Index := Start;
            if Motion = Next_Word_End then
               while Index < Size and then Kind_At (Index) = Blank loop
                  Index := Index + 1;
               end loop;
            end if;
            if Index < Size and then Kind_At (Index) /= Blank then
               Kind := Kind_At (Index);
               while Index < Size and then Kind_At (Index) = Kind loop
                  Index := Index + 1;
               end loop;
            end if;
            if Motion = Next_Word_Start then
               while Index < Size and then Kind_At (Index) = Blank loop
                  Index := Index + 1;
               end loop;
            end if;
            Anchor := Start;
            Head := Natural'Max (Start + 1, Index) - 1;

         when Previous_Word_Start             =>
            if Start = 0 then
               return;
            elsif Start >= Size then
               Start := Size - 1;
            elsif Kind_At (Start - 1) /= Kind_At (Start) then
               Start := Start - 1;
            end if;
            Index := Start;
            while Index > 0 and then Kind_At (Index) = Blank loop
               Index := Index - 1;
            end loop;
            Kind := Kind_At (Index);
            while Index > 0 and then Kind_At (Index - 1) = Kind loop
               Index := Index - 1;
            end loop;
            Anchor := Start;
            Head := Index;
      end case;
   end Word_Range;
end Diary_Editor;
