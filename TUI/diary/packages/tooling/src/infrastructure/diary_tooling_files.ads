package Diary_Tooling_Files is
   function Read_File (Path : String) return String;
   procedure Write_File (Path, Content : String);
   function Hash_File (Path : String) return String;
   procedure Write_Checksums (Directory, Manifest_Name : String);
   function License_Path (Directory : String) return String;
end Diary_Tooling_Files;
