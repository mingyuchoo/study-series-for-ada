with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Text_IO;
with Diary_Tooling_Files;
with Diary_Tooling_Host;
with GNAT.OS_Lib;

procedure Tooling_File_Tests is
   use Diary_Tooling_Files;
   use GNAT.OS_Lib;
   Descriptor : File_Descriptor;
   Name       : String_Access;
   procedure Check (Condition : Boolean; Label_Text : String) is
   begin
      if not Condition then
         raise Program_Error with Label_Text;
      end if;
   end Check;
   procedure Check_Host (Root : String) is
      Original_Path   : constant String :=
        Ada.Environment_Variables.Value ("PATH");
      Native_Platform : constant String := Diary_Tooling_Host.Platform;
      Script          : constant String := Root & "/host/uname";
   begin
      Ada.Directories.Create_Directory (Root & "/host");
      Write_File (Script, "#!/bin/sh" & ASCII.LF & "exit 42" & ASCII.LF);
      Set_Executable (Script);
      Ada.Environment_Variables.Set ("PATH", Root & "/host:" & Original_Path);
      Check
        (Diary_Tooling_Host.Platform = Native_Platform,
         "Native host detection must not execute PATH programs");
      Ada.Environment_Variables.Set ("PATH", Original_Path);
   exception
      when others =>
         Ada.Environment_Variables.Set ("PATH", Original_Path);
         raise;
   end Check_Host;
begin
   Create_Temp_File (Descriptor, Name);
   if Descriptor = Invalid_FD then
      raise Program_Error with "Cannot allocate file test workspace";
   end if;
   Close (Descriptor);
   Ada.Directories.Delete_File (Name.all);
   Ada.Directories.Create_Directory (Name.all);
   declare
      Root     : constant String := Name.all;
      Expected : constant String :=
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  a.txt"
        & ASCII.LF
        & "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  empty"
        & ASCII.LF;
   begin
      Write_File (Root & "/a.txt", "abc");
      Write_File (Root & "/empty", "");
      Ada.Directories.Create_Directory (Root & "/subdirectory");
      Check
        (Hash_File (Root & "/a.txt")
         = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
         "known SHA-256");
      Write_Checksums (Root, "SHA256SUMS");
      Check
        (Read_File (Root & "/SHA256SUMS") = Expected,
         "sorted checksums and directory exclusion");
      Write_Checksums (Root, "SHA256SUMS");
      Check
        (Read_File (Root & "/SHA256SUMS") = Expected,
         "checksum manifest excludes itself");
      Write_File (Root & "/COPYING", "fallback");
      Check (License_Path (Root) = Root & "/COPYING", "license fallback");
      Write_File (Root & "/LICENSE", "preferred");
      Check (License_Path (Root) = Root & "/LICENSE", "license preference");
      declare
         Content : String (1 .. 70_000) := [others => 'x'];
      begin
         Content (65_536) := ASCII.NUL;
         Content (65_537) := Character'Val (255);
         Content (70_000) := ASCII.LF;
         Write_File (Root & "/binary", Content);
         Check
           (Read_File (Root & "/binary") = Content, "binary chunk boundaries");
      end;
      Check_Host (Root);
      Ada.Directories.Delete_Tree (Root);
   end;
   Free (Name);
   Ada.Text_IO.Put_Line
     ("PASS tooling file bytes, SHA-256 manifests, licenses and native host detection");
exception
   when others =>
      if Name /= null and then Ada.Directories.Exists (Name.all) then
         Ada.Directories.Delete_Tree (Name.all);
      end if;
      Free (Name);
      raise;
end Tooling_File_Tests;
