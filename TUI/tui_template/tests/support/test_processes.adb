with Ada.Directories;
with Ada.Exceptions;
with Ada.Interrupts.Names;
with Ada.Real_Time;
with Ada.Text_IO;
with Interfaces.C.Strings;
with System;
with Test_Fixtures;
with Test_POSIX;

package body Test_Processes is
   use Ada.Real_Time;
   use Ada.Strings.Unbounded;
   use GNAT.OS_Lib;
   use Interfaces.C;
   use Interfaces.C.Strings;
   use Test_Fixtures;
   use Test_POSIX;

   function Fork return int
   with Import, Convention => C, External_Name => "fork";

   function Setsid return int
   with Import, Convention => C, External_Name => "setsid";

   function Dup2 (Source, Destination : File_Descriptor) return int
   with Import, Convention => C, External_Name => "dup2";

   function Execv (Program : chars_ptr; Argv : System.Address) return int
   with Import, Convention => C, External_Name => "execv";

   procedure Immediate_Exit (Status : int)
   with Import, Convention => C, External_Name => "_exit", No_Return;

   function Waitpid (Id : int; Status : access int; Flags : int) return int
   with Import, Convention => C, External_Name => "waitpid";

   function Kill (Id, Signal : int) return int
   with Import, Convention => C, External_Name => "kill";

   No_Wait     : constant := 1;
   Setup_Error : constant := 126;
   Exec_Error  : constant := 127;

   procedure Start
     (Object  : in out Process;
      Program : String;
      Options : Arguments;
      Input   : File_Descriptor := Standin;
      Output  : File_Descriptor := Standout;
      Errors  : File_Descriptor := Standerr)
   is
      Argv     : aliased chars_ptr_array (0 .. size_t (Options'Length) + 1) :=
        [others => Null_Ptr];
      Position : size_t := 1;
      Failure  : int;
      pragma Unreferenced (Failure);
      procedure Free_Arguments is
      begin
         for Item of Argv loop
            Free (Item);
         end loop;
      end Free_Arguments;
   begin
      Check
        (Is_Executable_File (Program),
         "Test executable not found: " & Program);
      Argv (0) := New_String (Program);
      for Option of Options loop
         Argv (Position) := New_String (To_String (Option));
         Position := Position + 1;
      end loop;
      Object.Id := Fork;
      Check_Result (Object.Id, "Start " & Program);
      if Object.Id = 0 then
         if Setsid < 0
           or else Dup2 (Input, Standin) < 0
           or else Dup2 (Output, Standout) < 0
           or else Dup2 (Errors, Standerr) < 0
         then
            Immediate_Exit (Setup_Error);
         end if;
         Failure := Execv (Argv (0), Argv'Address);
         Immediate_Exit (Exec_Error);
      end if;
      Free_Arguments;
   exception
      when others =>
         Free_Arguments;
         raise;
   end Start;

   procedure Wait_For_Exit
     (Object : in out Process; Timeout : Duration; Status : out Integer)
   is
      Deadline   : constant Time := Clock + To_Time_Span (Timeout);
      Raw_Status : aliased int;
      Next_Poll  : Time;
      Result     : int;
   begin
      loop
         Result := Waitpid (Object.Id, Raw_Status'Access, No_Wait);
         if Result = Object.Id then
            Object.Id := 0;
            Status :=
              (if Raw_Status mod 256 = 0
               then Integer (Raw_Status / 256)
               else -Integer (Raw_Status mod 128));
            return;
         elsif Result < 0 and then Errno /= Interrupted then
            Check_Result (Result, "Wait for child");
         end if;
         Check (Clock < Deadline, "Child process timed out");
         Next_Poll := Clock + Milliseconds (10);
         delay until (if Next_Poll < Deadline then Next_Poll else Deadline);
      end loop;
   end Wait_For_Exit;

   procedure Notify (Object : Process; Signal : Ada.Interrupts.Interrupt_ID) is
   begin
      Check_Result (Kill (Object.Id, int (Signal)), "Signal child");
   end Notify;

   procedure Stop (Object : in out Process) is
      Status : Integer;
   begin
      if Object.Id > 0 then
         Notify (Object, Ada.Interrupts.Names.SIGKILL);
         Wait_For_Exit (Object, 1.0, Status);
      end if;
   end Stop;

   overriding
   procedure Finalize (Object : in out Process) is
   begin
      Stop (Object);
   exception
      when Error : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Clean up test process: "
            & Ada.Exceptions.Exception_Message (Error));
   end Finalize;

   procedure Check_Child_Started (Program : String; Status : Integer) is
   begin
      Check
        (Status /= Setup_Error, "Could not configure child for " & Program);
      Check (Status /= Exec_Error, "Could not execute " & Program);
   end Check_Child_Started;

   function Run
     (Program : String; Options : Arguments; Timeout : Duration) return Integer
   is
      Child  : Process;
      Status : Integer;
   begin
      Start (Child, Program, Options);
      Wait_For_Exit (Child, Timeout, Status);
      Check_Child_Started (Program, Status);
      return Status;
   end Run;

   function Capture
     (Program : String; Options : Arguments) return Captured_Result
   is
      Directory : Temporary_Directory;
   begin
      Create (Directory, "ada-tui-template-command-");
      declare
         Output_Path : constant String :=
           Ada.Directories.Compose (Path (Directory), "stdout");
         Error_Path  : constant String :=
           Ada.Directories.Compose (Path (Directory), "stderr");
         Output      : Descriptor;
         Errors      : Descriptor;
         Child       : Process;
         Status      : Integer;
      begin
         Own
           (Output,
            Create_New_File (Output_Path, Binary),
            "Create stdout capture file");
         Own
           (Errors,
            Create_New_File (Error_Path, Binary),
            "Create stderr capture file");
         Start
           (Child,
            Program,
            Options,
            Output => Handle (Output),
            Errors => Handle (Errors));
         Wait_For_Exit (Child, 3.0, Status);
         Check_Child_Started (Program, Status);
         return
           (Status,
            To_Unbounded_String (Read_File (Output_Path)),
            To_Unbounded_String (Read_File (Error_Path)));
      end;
   end Capture;
end Test_Processes;
