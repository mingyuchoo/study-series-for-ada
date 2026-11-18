with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with GNAT.OS_Lib;
with Interfaces.C.Strings;
with System;
with Test_POSIX;

package body Test_Fixtures is
   use Ada.Directories;
   use Ada.Strings.Unbounded;
   use Interfaces.C;
   use Interfaces.C.Strings;

   function Mkdtemp (Template : System.Address) return chars_ptr
   with Import, Convention => C, External_Name => "mkdtemp";

   function Mkfifo (Name : char_array; Mode : unsigned) return int
   with Import, Convention => C, External_Name => "mkfifo";

   function Unlink (Name : char_array) return int
   with Import, Convention => C, External_Name => "unlink";

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

   procedure Create_FIFO (Object : in out Temporary_Directory; Name : String)
   is
      File : constant String := Compose (Path (Object), Name);
   begin
      Test_POSIX.Check_Result
        (Mkfifo (To_C (File), 8#600#), "Create test FIFO");
      Object.FIFO := To_Unbounded_String (File);
   end Create_FIFO;

   function Path (Object : Temporary_Directory) return String
   is (To_String (Object.Name));

   overriding
   procedure Finalize (Object : in out Temporary_Directory) is
   begin
      if Length (Object.FIFO) > 0 then
         Test_POSIX.Check_Result
           (Unlink (To_C (To_String (Object.FIFO))), "Remove test FIFO");
      end if;
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

   procedure Find_Diary_Files
     (Directory : String; Count : out Natural; First : out Unbounded_String)
   is
      Search : Search_Type;
      Item   : Directory_Entry_Type;
   begin
      Count := 0;
      First := Null_Unbounded_String;
      Start_Search (Search, Directory, "*.diary");
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Item);
         if Count = 0 then
            First := To_Unbounded_String (Full_Name (Item));
         end if;
         Count := Count + 1;
      end loop;
      End_Search (Search);
   end Find_Diary_Files;

   function Diary_File_Count (Directory : String) return Natural is
      Count : Natural;
      First : Unbounded_String;
   begin
      Find_Diary_Files (Directory, Count, First);
      return Count;
   end Diary_File_Count;

   function Only_Diary_File (Directory : String) return String is
      Count : Natural;
      First : Unbounded_String;
   begin
      Find_Diary_Files (Directory, Count, First);
      Check
        (Count = 1,
         "Expected one entry file; found" & Count'Image & " in " & Directory);
      return To_String (First);
   end Only_Diary_File;
end Test_Fixtures;
