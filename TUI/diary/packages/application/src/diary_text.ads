package Diary_Text
  with Pure
is
   type Cell_Position is record
      Row : Natural := 0;
      Col : Natural := 0;
   end record;
   function Cell_Width (Value : Wide_Wide_Character) return Positive;
   procedure Advance
     (Position : in out Cell_Position;
      Value    : Wide_Wide_Character;
      Width    : Positive);
   function Position_At
     (Value : Wide_Wide_String; Offset : Natural; Width : Positive)
      return Cell_Position;
end Diary_Text;
