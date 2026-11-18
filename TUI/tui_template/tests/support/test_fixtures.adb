with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with GNAT.OS_Lib;
with Interfaces.C.Strings;
with System;

package body Test_Fixtures is
   use Ada.Directories;
   use Ada.Strings.Unbounded;
   use Interfaces.C;
   use Interfaces.C.Strings;

   function Mkdtemp (Template : System.Address) return chars_ptr
   with Import, Convention => C, External_Name => "mkdtemp";

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Check;

   procedure Create (Object : in out Temporary_Directory; Prefix : String) is
      Temp      : constant String :=
        Ada.Environment_Variables.Value ("TMPDIR", "/tmp");
      Parent    : constant String :=
        (if Temp = "" then "/tmp" else Full_Name (Temp));
      Template  : aliased char_array :=
        To_C (Compose (Parent, Prefix & "XXXXXX"));
      Directory : constant chars_ptr := Mkdtemp (Template'Address);
   begin
      Check
        (Directory /= Null_Ptr,
         "Create test directory: " & GNAT.OS_Lib.Errno_Message);
      Object.Name := To_Unbounded_String (Value (Directory));
   end Create;

   function Path (Object : Temporary_Directory) return String
   is (To_String (Object.Name));

   overriding
   procedure Finalize (Object : in out Temporary_Directory) is
   begin
      if Length (Object.Name) > 0 then
         Delete_Tree (Path (Object));
      end if;
   end Finalize;

   function Sibling_Executable (Name : String) return String is
      use GNAT.OS_Lib;
      Command    : constant String := Ada.Command_Line.Command_Name;
      Located    : GNAT.OS_Lib.String_Access :=
        (if Ada.Strings.Fixed.Index (Command, "/") = 0
         then Locate_Exec_On_Path (Command)
         else null);
      Executable : constant String :=
        Normalize_Pathname ((if Located = null then Command else Located.all));
   begin
      Free (Located);
      return Compose (Containing_Directory (Executable), Name);
   end Sibling_Executable;

   function Read_File (Name : String) return String is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      File : File_Type;
   begin
      Check (Kind (Name) = Ordinary_File, "Expected a regular file: " & Name);
      Open (File, In_File, Name);
      declare
         Data :
           Stream_Element_Array (1 .. Stream_Element_Offset (Size (File)));
         Last : Stream_Element_Offset;
         Text : String (1 .. Data'Length);
      begin
         Read (File, Data, Last);
         Close (File);
         Check (Last = Data'Last, "Incomplete read of " & Name);
         for Index in Data'Range loop
            Text (Integer (Index)) := Character'Val (Data (Index));
         end loop;
         return Text;
      end;
   end Read_File;
end Test_Fixtures;
