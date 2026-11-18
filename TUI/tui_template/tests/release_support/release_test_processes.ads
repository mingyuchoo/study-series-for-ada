with Ada.Strings.Unbounded;

package Release_Test_Processes is
   use Ada.Strings.Unbounded;

   type Arguments is array (Positive range <>) of Unbounded_String;
   function "+" (Value : String) return Unbounded_String
   renames To_Unbounded_String;

   type Result is record
      Status : Integer;
      Output : Unbounded_String;
      Errors : Unbounded_String;
   end record;

   function Run
     (Command : Arguments; Directory : String; Timeout : Duration := 60.0)
      return Result;
   function Command_Output (Process : Result) return String;
end Release_Test_Processes;
