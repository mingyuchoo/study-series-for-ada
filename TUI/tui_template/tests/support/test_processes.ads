with Ada.Finalization;
with Ada.Interrupts;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Interfaces.C;

package Test_Processes is
   type Arguments is
     array (Positive range <>) of Ada.Strings.Unbounded.Unbounded_String;

   function Argument
     (Value : String) return Ada.Strings.Unbounded.Unbounded_String
   renames Ada.Strings.Unbounded.To_Unbounded_String;

   type Process is new Ada.Finalization.Limited_Controlled with private;

   procedure Start
     (Object  : in out Process;
      Program : String;
      Options : Arguments;
      Input   : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Standin;
      Output  : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Standout;
      Errors  : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Standerr);
   procedure Wait_For_Exit
     (Object : in out Process; Timeout : Duration; Status : out Integer);
   procedure Notify (Object : Process; Signal : Ada.Interrupts.Interrupt_ID);
   procedure Stop (Object : in out Process);

   function Run
     (Program : String; Options : Arguments; Timeout : Duration)
      return Integer;

   type Captured_Result is record
      Exit_Status : Integer;
      Output      : Ada.Strings.Unbounded.Unbounded_String;
      Errors      : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Capture
     (Program : String; Options : Arguments) return Captured_Result;

private
   type Process is new Ada.Finalization.Limited_Controlled with record
      Id : Interfaces.C.int := 0;
   end record;

   overriding
   procedure Finalize (Object : in out Process);
end Test_Processes;
