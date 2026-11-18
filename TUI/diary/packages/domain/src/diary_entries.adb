package body Diary_Entries is
   use Ada.Strings.Wide_Wide_Unbounded;
   function Is_Whitespace (Letter : Wide_Wide_Character) return Boolean is
      Code : constant Natural := Wide_Wide_Character'Pos (Letter);
   begin
      return
        Code
        in 9 .. 13
         | 32
         | 16#A0#
         | 16#1680#
         | 16#2000# .. 16#200A#
         | 16#2028# .. 16#2029#
         | 16#202F#
         | 16#205F#
         | 16#3000#;
   end Is_Whitespace;
   function Is_Scalar (Letter : Wide_Wide_Character) return Boolean is
      Code : constant Natural := Wide_Wide_Character'Pos (Letter);
   begin
      return Code <= 16#10FFFF# and then Code not in 16#D800# .. 16#DFFF#;
   end Is_Scalar;
   function Is_Valid (Value : Entry_Data) return Boolean is
      Has_Title : Boolean := False;
   begin
      for Letter of To_Wide_Wide_String (Value.Title) loop
         if not Is_Whitespace (Letter) then
            Has_Title := True;
         end if;
         if not Is_Scalar (Letter)
           or else Wide_Wide_Character'Pos (Letter) < 32
           or else Wide_Wide_Character'Pos (Letter) in 127 .. 159
         then
            return False;
         end if;
      end loop;
      for Letter of To_Wide_Wide_String (Value.Content) loop
         if not Is_Scalar (Letter)
           or else (Wide_Wide_Character'Pos (Letter) < 32
                    and then Wide_Wide_Character'Pos (Letter) not in 9 | 10)
           or else Wide_Wide_Character'Pos (Letter) in 127 .. 159
         then
            return False;
         end if;
      end loop;
      return Has_Title;
   end Is_Valid;
end Diary_Entries;
