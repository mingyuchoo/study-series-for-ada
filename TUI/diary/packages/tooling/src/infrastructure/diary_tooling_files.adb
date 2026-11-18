with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with GNAT.SHA256;

package body Diary_Tooling_Files is
   use Ada.Streams;
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   package File_IO renames Ada.Streams.Stream_IO;
   function Read_File (Path : String) return String is
      File   : File_IO.File_Type;
      Result : Unbounded_String;
      Buffer : Stream_Element_Array (1 .. 65_536);
      Last   : Stream_Element_Offset;
   begin
      File_IO.Open (File, File_IO.In_File, Path);
      while not File_IO.End_Of_File (File) loop
         File_IO.Read (File, Buffer, Last);
         for Index in Buffer'First .. Last loop
            Append (Result, Character'Val (Buffer (Index)));
         end loop;
      end loop;
      File_IO.Close (File);
      return To_String (Result);
   exception
      when others =>
         if File_IO.Is_Open (File) then
            File_IO.Close (File);
         end if;
         raise;
   end Read_File;
   procedure Write_File (Path, Content : String) is
      File     : File_IO.File_Type;
      Buffer   : Stream_Element_Array (1 .. 65_536);
      Position : Integer := Content'First;
      Count    : Stream_Element_Offset;
   begin
      File_IO.Create (File, File_IO.Out_File, Path);
      while Position <= Content'Last loop
         Count :=
           Stream_Element_Offset
             (Integer'Min (Buffer'Length, Content'Last - Position + 1));
         for Index in 1 .. Count loop
            Buffer (Index) := Character'Pos (Content (Position));
            Position := Position + 1;
         end loop;
         File_IO.Write (File, Buffer (1 .. Count));
      end loop;
      File_IO.Close (File);
   exception
      when others =>
         if File_IO.Is_Open (File) then
            File_IO.Close (File);
         end if;
         raise;
   end Write_File;
   function Hash_File (Path : String) return String is
      File    : File_IO.File_Type;
      Context : GNAT.SHA256.Context := GNAT.SHA256.Initial_Context;
      Buffer  : Stream_Element_Array (1 .. 65_536);
      Last    : Stream_Element_Offset;
   begin
      File_IO.Open (File, File_IO.In_File, Path);
      while not File_IO.End_Of_File (File) loop
         File_IO.Read (File, Buffer, Last);
         GNAT.SHA256.Update (Context, Buffer (1 .. Last));
      end loop;
      File_IO.Close (File);
      return GNAT.SHA256.Digest (Context);
   exception
      when others =>
         if File_IO.Is_Open (File) then
            File_IO.Close (File);
         end if;
         raise;
   end Hash_File;
   procedure Write_Checksums (Directory, Manifest_Name : String) is
      package Names is new
        Ada.Containers.Indefinite_Vectors (Positive, String);
      package Sorting is new Names.Generic_Sorting;
      Files       : Names.Vector;
      Search      : Ada.Directories.Search_Type;
      Entry_Value : Ada.Directories.Directory_Entry_Type;
      Result      : Unbounded_String;
   begin
      if Ada.Directories.Simple_Name (Manifest_Name) /= Manifest_Name
        or else Manifest_Name'Length = 0
      then
         raise Constraint_Error with "Checksum manifest must be a file name";
      end if;
      Ada.Directories.Start_Search
        (Search,
         Directory,
         "*",
         [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Entry_Value);
         declare
            Name : constant String :=
              Ada.Directories.Simple_Name (Entry_Value);
         begin
            if Name /= Manifest_Name then
               for Value of Name loop
                  if Value in ASCII.LF | ASCII.CR | '\' then
                     raise Constraint_Error
                       with "Unsupported checksum file name";
                  end if;
               end loop;
               Files.Append (Name);
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
      Sorting.Sort (Files);
      for Name of Files loop
         Append
           (Result,
            Hash_File (Ada.Directories.Compose (Directory, Name))
            & "  "
            & Name
            & ASCII.LF);
      end loop;
      Write_File
        (Ada.Directories.Compose (Directory, Manifest_Name),
         To_String (Result));
   exception
      when others =>
         Ada.Directories.End_Search (Search);
         raise;
   end Write_Checksums;
   function License_Path (Directory : String) return String is
      Names : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("LICENSE"),
         To_Unbounded_String ("LICENSE.txt"),
         To_Unbounded_String ("COPYING"),
         To_Unbounded_String ("LICENSE.md")];
   begin
      for Name of Names loop
         declare
            Path : constant String :=
              Ada.Directories.Compose (Directory, To_String (Name));
         begin
            if Ada.Directories.Exists (Path)
              and then Ada.Directories.Kind (Path)
                       = Ada.Directories.Ordinary_File
            then
               return Path;
            end if;
         end;
      end loop;
      raise Constraint_Error with "Malef license file is missing";
   end License_Path;
end Diary_Tooling_Files;
