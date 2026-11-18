with Ada.Finalization;
with Ada.Strings.Unbounded;

package Test_Fixtures is
   type Temporary_Directory is
     new Ada.Finalization.Limited_Controlled with private;

   procedure Create (Object : in out Temporary_Directory; Prefix : String);
   procedure Create_FIFO (Object : in out Temporary_Directory; Name : String);
   function Path (Object : Temporary_Directory) return String;

   procedure Check (Condition : Boolean; Message : String);
   function Sibling_Executable (Name : String) return String;
   function Read_File (Name : String) return String;
   function Diary_File_Count (Directory : String) return Natural;
   function Only_Diary_File (Directory : String) return String;

private
   type Temporary_Directory is new Ada.Finalization.Limited_Controlled
   with record
      Name : Ada.Strings.Unbounded.Unbounded_String;
      FIFO : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   overriding
   procedure Finalize (Object : in out Temporary_Directory);
end Test_Fixtures;
