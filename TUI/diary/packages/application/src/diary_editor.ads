with Ada.Strings.Wide_Wide_Unbounded;

package Diary_Editor is
   type Text_Buffer is private;
   type Movement is (Backward, Forward, Upward, Downward, Line_Start, Line_End);
   procedure Load (Buffer : out Text_Buffer; Value : Wide_Wide_String);
   function Text (Buffer : Text_Buffer) return Wide_Wide_String;
   function Position (Buffer : Text_Buffer) return Natural;
   procedure Insert (Buffer : in out Text_Buffer; Value : Wide_Wide_Character);
   procedure Backspace (Buffer : in out Text_Buffer);
   procedure Move (Buffer : in out Text_Buffer; Direction : Movement);
private
   type Text_Buffer is record
      Content : Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
      Cursor : Natural := 0;
   end record;
end Diary_Editor;
