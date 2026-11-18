with Ada.Containers.Indefinite_Vectors;

package Release_Test_Files is
   package Names is new Ada.Containers.Indefinite_Vectors (Positive, String);

   function Read_File (Path : String) return String;
   procedure Write_File (Path : String; Content : String);
   function Matching_Files (Directory, Pattern : String) return Names.Vector;
   function Lines (Content : String) return Names.Vector;
   function Find_Executable (Command : String) return String;
end Release_Test_Files;
