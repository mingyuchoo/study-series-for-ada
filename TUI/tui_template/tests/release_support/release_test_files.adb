with Ada.Characters.Latin_1;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;

package body Release_Test_Files is
   function Read_File (Path : String) return String is
      use Ada.Streams;
      package Files renames Ada.Streams.Stream_IO;
      File : Files.File_Type;
   begin
      Files.Open (File, Files.In_File, Path);
      declare
         Data :
           Stream_Element_Array
             (1 .. Stream_Element_Offset (Files.Size (File)));
         Last : Stream_Element_Offset;
      begin
         Files.Read (File, Data, Last);
         Files.Close (File);
         return Text : String (1 .. Natural (Last)) do
            for Index in Text'Range loop
               Text (Index) :=
                 Character'Val (Data (Stream_Element_Offset (Index)));
            end loop;
         end return;
      end;
   end Read_File;

   procedure Write_File (Path : String; Content : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);
   end Write_File;

   function Matching_Files (Directory, Pattern : String) return Names.Vector is
      use Ada.Directories;
      Matched : Names.Vector;

      procedure Add_File (Item : Directory_Entry_Type) is
      begin
         Matched.Append (Simple_Name (Item));
      end Add_File;

   begin
      if Exists (Directory) then
         Search
           (Directory,
            Pattern,
            [Ordinary_File => True, others => False],
            Add_File'Access);
      end if;
      return Matched;
   end Matching_Files;

   function Lines (Content : String) return Names.Vector is
      Start  : Natural := Content'First;
      Result : Names.Vector;

      procedure Append_Line (Last : Natural) is
         Line : constant String (1 .. Last - Start + 1) :=
           Content (Start .. Last);
      begin
         Result.Append (Line);
      end Append_Line;

   begin
      while Start <= Content'Last loop
         declare
            Break : constant Natural :=
              Ada.Strings.Fixed.Index
                (Content, [Ada.Characters.Latin_1.LF], From => Start);
         begin
            if Break = 0 then
               Append_Line (Content'Last);
               exit;
            end if;
            Append_Line (Break - 1);
            Start := Break + 1;
         end;
      end loop;
      return Result;
   end Lines;

   function Find_Executable (Command : String) return String is
      use GNAT.OS_Lib;
      Location : String_Access := Locate_Exec_On_Path (Command);
   begin
      if Location = null then
         return "";
      end if;
      return Path : constant String := Location.all do
         Free (Location);
      end return;
   end Find_Executable;
end Release_Test_Files;
