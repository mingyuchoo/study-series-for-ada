with Ada.Characters.Latin_1;
with Ada.Real_Time;
with GNAT.OS_Lib;
with Interfaces.C.Strings;
with Release_Test_Files;
with System;

package body Release_Test_Processes is
   use Ada.Real_Time;
   use Interfaces.C;
   use Interfaces.C.Strings;
   use Release_Test_Files;

   function Fork return int
   with Import, Convention => C, External_Name => "fork";
   function Set_Process_Group (Process, Group : int) return int
   with Import, Convention => C, External_Name => "setpgid";
   function Execute (Program : chars_ptr; Command : System.Address) return int
   with Import, Convention => C, External_Name => "execv";
   function Wait (Process : int; Status : access int; Options : int) return int
   with Import, Convention => C, External_Name => "waitpid";
   function Send_Signal (Process, Signal : int) return int
   with Import, Convention => C, External_Name => "kill";
   procedure Exit_Child (Status : int)
   with Import, Convention => C, External_Name => "_exit", No_Return;

   Signal_Kill       : constant := 9;
   Wait_No_Hang      : constant := 1;
   Error_Interrupted : constant := 4;

   type C_Arguments is array (Positive range <>) of chars_ptr
   with Convention => C;

   function Reap
     (Process : int; Timeout : Duration; Status : out int) return Boolean
   is
      Deadline    : constant Time := Clock + To_Time_Span (Timeout);
      Wait_Status : aliased int := 0;
      Waited      : int;
   begin
      loop
         Waited := Wait (Process, Wait_Status'Access, Wait_No_Hang);
         if Waited = Process then
            Status := Wait_Status;
            return True;
         elsif Waited = -1 and then GNAT.OS_Lib.Errno /= Error_Interrupted then
            raise Program_Error with "waitpid: " & GNAT.OS_Lib.Errno_Message;
         elsif Clock >= Deadline then
            Status := 0;
            return False;
         end if;
         delay 0.02;
      end loop;
   end Reap;

   procedure Stop (Process : int) is
      Signal_Status : int := Send_Signal (-Process, Signal_Kill);
      Wait_Status   : int;
   begin
      if Signal_Status /= 0 then
         Signal_Status := Send_Signal (Process, Signal_Kill);
         if Signal_Status /= 0 then
            raise Program_Error with "kill: " & GNAT.OS_Lib.Errno_Message;
         end if;
      end if;
      if not Reap (Process, 2.0, Wait_Status) then
         raise Program_Error with "Could not reap the terminated process";
      end if;
   end Stop;

   function Run
     (Command : Arguments; Directory : String; Timeout : Duration := 60.0)
      return Result
   is
      Output_File : constant String := Directory & "/stdout";
      Error_File  : constant String := Directory & "/stderr";
      Invocation  : constant Arguments :=
        [+"/bin/sh",
         +"-c",
         +"exec >""$1"" 2>""$2""; cd -- ""$3"" || exit; shift 3; exec ""$@""",
         +"release-test",
         +Output_File,
         +Error_File,
         +Directory]
        & Command;
      C_Command   : C_Arguments (1 .. Invocation'Length + 1) :=
        [others => Null_Ptr];
      Process     : int := 0;
      Wait_Status : int;

      procedure Free_Arguments is
      begin
         for Argument of C_Command loop
            Free (Argument);
         end loop;
      end Free_Arguments;

   begin
      for Index in Invocation'Range loop
         C_Command (Index) := New_String (To_String (Invocation (Index)));
      end loop;
      Process := Fork;
      if Process = -1 then
         raise Program_Error with "fork: " & GNAT.OS_Lib.Errno_Message;
      elsif Process = 0 then
         if Set_Process_Group (0, 0) /= 0 then
            Exit_Child (126);
         end if;
         Exit_Child
           (if Execute (C_Command (1), C_Command'Address) = -1
            then 127
            else 126);
      end if;
      Free_Arguments;
      if not Reap (Process, Timeout, Wait_Status) then
         raise Program_Error
           with "Timed out running " & To_String (Command (Command'First));
      end if;
      Process := 0;
      return
        (Status =>
           (if Wait_Status mod 128 = 0
            then Integer (Wait_Status / 256 mod 256)
            else 128 + Integer (Wait_Status mod 128)),
         Output => +Read_File (Output_File),
         Errors => +Read_File (Error_File));
   exception
      when others =>
         Free_Arguments;
         if Process > 0 then
            Stop (Process);
         end if;
         raise;
   end Run;

   function Command_Output (Process : Result) return String
   is ("Exit status"
       & Integer'Image (Process.Status)
       & Ada.Characters.Latin_1.LF
       & To_String (Process.Errors & Process.Output));
end Release_Test_Processes;
