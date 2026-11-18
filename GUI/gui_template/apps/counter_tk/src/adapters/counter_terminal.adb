with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Counter_Actions;

package body Counter_Terminal is
   procedure Run is
      use Ada.Text_IO;
      use Counter_Actions;

      Value : Counter_Actions.Count := Initial_Count;

      procedure Publish_Count is
      begin
         Put_Line (Ada.Strings.Fixed.Trim (Value'Image, Ada.Strings.Left));
         Flush;
      end Publish_Count;
   begin
      Publish_Count;

      while not End_Of_File loop
         declare
            Command : constant String := Get_Line;
         begin
            if Command = "increment" then
               Value := Apply (Value, Increment);
               Publish_Count;
            elsif Command = "reset" then
               Value := Apply (Value, Reset);
               Publish_Count;
            else
               Put_Line ("error unknown command");
               Flush;
            end if;
         end;
      end loop;
   end Run;
end Counter_Terminal;
