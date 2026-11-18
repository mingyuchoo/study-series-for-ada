package body Diary_Text is
   function Cell_Width (Value : Wide_Wide_Character) return Positive is
      Code : constant Natural := Wide_Wide_Character'Pos (Value);
   begin
      if Code in 16#1100# .. 16#115F# | 16#2329# .. 16#232A# | 16#2E80# .. 16#A4CF# | 16#AC00# .. 16#D7A3# | 16#F900# .. 16#FAFF# | 16#FE10# .. 16#FE19# | 16#FE30# .. 16#FE6F# | 16#FF01# .. 16#FF60# | 16#FFE0# .. 16#FFE6# | 16#1F300# .. 16#1FAFF# | 16#20000# .. 16#3FFFD# then
         return 2;
      end if;
      return 1;
   end Cell_Width;
   procedure Advance (Position : in out Cell_Position; Value : Wide_Wide_Character; Width : Positive) is
      Size : constant Positive := Cell_Width (Value);
   begin
      if Wide_Wide_Character'Pos (Value) = 10 then
         Position := (Position.Row + 1, 0);
      else
         if Position.Col + Size > Width then
            Position := (Position.Row + 1, 0);
         end if;
         Position.Col := Position.Col + Size;
      end if;
   end Advance;
   function Position_At (Value : Wide_Wide_String; Offset : Natural; Width : Positive) return Cell_Position is
      Result : Cell_Position;
   begin
      for Index in 0 .. Natural'Min (Offset, Value'Length) - 1 loop
         Advance (Result, Value (Value'First + Index), Width);
      end loop;
      if Result.Col >= Width then
         Result := (Result.Row + 1, 0);
      end if;
      return Result;
   end Position_At;
end Diary_Text;
