with Ada.Characters.Latin_1;
with Ada.Exceptions;
with Ada.Interrupts.Names;
with Ada.Real_Time;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with GNAT.Regpat;
with Interfaces.C.Strings;
with System;
with Test_Fixtures;

package body Test_Terminals is
   use Ada.Characters.Latin_1;
   use Ada.Real_Time;
   use Ada.Strings.Unbounded;
   use GNAT.OS_Lib;
   use Interfaces.C.Strings;
   use Test_Fixtures;
   use Test_POSIX;

   type Window_Size is record
      Rows, Columns, Width, Height : unsigned_short;
   end record
   with Convention => C;

   type Poll_Descriptor is record
      File                : File_Descriptor;
      Requested, Returned : unsigned_short;
   end record
   with Convention => C;

   function Open_Pseudo_Terminal (Flags : int) return File_Descriptor
   with Import, Convention => C, External_Name => "posix_openpt";

   function Grant (File : File_Descriptor) return int
   with Import, Convention => C, External_Name => "grantpt";

   function Unlock (File : File_Descriptor) return int
   with Import, Convention => C, External_Name => "unlockpt";

   function Slave_Name (File : File_Descriptor) return chars_ptr
   with Import, Convention => C, External_Name => "ptsname";

   function Open_File (Name : chars_ptr; Flags : int) return File_Descriptor
   with Import, Convention => C_Variadic_2, External_Name => "open";

   function Ioctl
     (File    : File_Descriptor;
      Request : unsigned_long;
      Size    : access Window_Size) return int
   with Import, Convention => C_Variadic_2, External_Name => "ioctl";

   function Get_Mode (File : File_Descriptor; Mode : System.Address) return int
   with Import, Convention => C, External_Name => "tcgetattr";

   function Set_Mode
     (File : File_Descriptor; Action : int; Mode : System.Address) return int
   with Import, Convention => C, External_Name => "tcsetattr";

   function Linux_Poll
     (File : access Poll_Descriptor; Count : unsigned_long; Timeout : int)
      return int
   with Import, Convention => C, External_Name => "poll";

   function Darwin_Poll
     (File : access Poll_Descriptor; Count : unsigned; Timeout : int)
      return int
   with Import, Convention => C, External_Name => "poll";

   Read_Write        : constant := 2;
   Write_Only        : constant := 1;
   Apply_Immediately : constant := 0;
   Readable          : constant := 1;
   Writable          : constant := 4;

   ANSI_Escape : constant GNAT.Regpat.Pattern_Matcher :=
     GNAT.Regpat.Compile
       (ESC
        & "\[[0-?]*[ -/]*[@-~]|"
        & ESC
        & "\][^"
        & BEL
        & "]*("
        & BEL
        & "|"
        & ESC
        & "\\)");

   function Mode_Address (Mode : aliased Terminal_Mode) return System.Address
   is (case Mode.Host is
         when Linux  => Mode.Linux_Mode'Address,
         when Darwin => Mode.Darwin_Mode'Address);

   function Read_Mode
     (File : File_Descriptor; Platform : Host_Kind) return Terminal_Mode
   is
      Mode : aliased Terminal_Mode (Platform);
   begin
      Check_Result
        (Get_Mode (File, Mode_Address (Mode)), "Read terminal mode");
      return Mode;
   end Read_Mode;

   function Would_Block (Platform : Host_Kind) return Integer
   is (case Platform is
         when Linux  => 11,
         when Darwin => 35);

   function Await_IO
     (Object : Session; Event : unsigned_short; Deadline : Time) return Boolean
   is
      File              : aliased Poll_Descriptor :=
        (Handle (Object.Master), Event, 0);
      Result            : int;
      Milliseconds_Left : int;
   begin
      while Clock < Deadline loop
         Milliseconds_Left :=
           int'Max (0, int (1_000 * To_Duration (Deadline - Clock)));
         Result :=
           (case Object.Original.Host is
              when Linux  => Linux_Poll (File'Access, 1, Milliseconds_Left),
              when Darwin => Darwin_Poll (File'Access, 1, Milliseconds_Left));
         if Result = 0 then
            return False;
         elsif Result > 0 then
            Check
              ((File.Returned and Event) /= 0,
               "Terminal descriptor became unavailable");
            return True;
         elsif Errno /= Interrupted then
            Check_Result (Result, "Poll terminal");
         end if;
      end loop;
      return False;
   end Await_IO;

   procedure Drain (Object : in out Session; Interval : Duration) is
      Deadline : constant Time := Clock + To_Time_Span (Interval);
      Data     : String (1 .. 65_536);
      Count    : Integer;
   begin
      while Await_IO (Object, Readable, Deadline) loop
         Count := Read (Handle (Object.Master), Data'Address, Data'Length);
         if Count > 0 then
            Append (Object.Output, Data (1 .. Count));
         elsif Count = 0 then
            return;
         elsif Errno not in Interrupted | Would_Block (Object.Original.Host)
         then
            Check_Result (int (Count), "Read terminal");
         end if;
      end loop;
   end Drain;

   procedure Set_Size (Object : Session; Rows, Columns : Positive) is
      Request : constant unsigned_long :=
        (case Object.Original.Host is
           when Linux  => 16#5414#,
           when Darwin => 16#8008_7467#);
      Size    : aliased Window_Size :=
        (unsigned_short (Rows), unsigned_short (Columns), 0, 0);
   begin
      Check_Result
        (Ioctl (Handle (Object.Slave), Request, Size'Access),
         "Resize terminal");
   end Set_Size;

   procedure Open
     (Object  : in out Session;
      Program : String;
      Options : Test_Processes.Arguments;
      Rows    : Positive := 30;
      Columns : Positive := 110)
   is
      Platform                : constant Host_Kind := Host;
      No_Controlling_Terminal : constant int :=
        (case Platform is
           when Linux  => 16#100#,
           when Darwin => 16#2_0000#);
      Slave_Device            : chars_ptr;
      Output                  : Descriptor;
   begin
      Own
        (Object.Master,
         Open_Pseudo_Terminal (Read_Write + No_Controlling_Terminal),
         "Open PTY master");
      Make_Nonblocking (Object.Master, Platform);
      Check_Result (Grant (Handle (Object.Master)), "Grant PTY access");
      Check_Result (Unlock (Handle (Object.Master)), "Unlock PTY");
      Slave_Device := Slave_Name (Handle (Object.Master));
      Check (Slave_Device /= Null_Ptr, "Get PTY slave name: " & Errno_Message);
      Own
        (Object.Slave,
         Open_File (Slave_Device, Read_Write + No_Controlling_Terminal),
         "Open PTY slave");
      Object.Original := Read_Mode (Handle (Object.Slave), Platform);
      Object.Mode_Saved := True;
      Set_Size (Object, Rows, Columns);
      Own
        (Output,
         Open_File (Slave_Device, Write_Only + No_Controlling_Terminal),
         "Open PTY output");
      Test_Processes.Start
        (Object.Child,
         Program,
         Options,
         Input  => Handle (Object.Slave),
         Output => Handle (Output),
         Errors => Handle (Output));
      Drain (Object, 0.7);
   end Open;

   procedure Resize (Object : in out Session; Rows, Columns : Positive) is
   begin
      Set_Size (Object, Rows, Columns);
      Test_Processes.Notify (Object.Child, Ada.Interrupts.Names.SIGWINCH);
      Drain (Object, 0.3);
   end Resize;

   procedure Send (Object : in out Session; Keys : String) is
      Deadline : constant Time := Clock + Seconds (1);
      Next     : Integer := Keys'First;
      Written  : Integer;
   begin
      while Next <= Keys'Last loop
         Check
           (Await_IO (Object, Writable, Deadline), "Terminal input timed out");
         Written :=
           Write
             (Handle (Object.Master),
              Keys (Next)'Address,
              Keys'Last - Next + 1);
         if Written > 0 then
            Next := Next + Written;
         elsif Written < 0
           and then Errno
                    not in Interrupted | Would_Block (Object.Original.Host)
         then
            Check_Result (int (Written), "Write terminal");
         end if;
      end loop;
      Drain (Object, 0.2);
   end Send;

   function Visible_Output (Object : Session) return String is
      use GNAT.Regpat;
      Raw     : constant String := To_String (Object.Output);
      Visible : Unbounded_String;
      Next    : Positive := Raw'First;
      Matches : Match_Array (0 .. 0);
   begin
      while Next <= Raw'Last loop
         Match (ANSI_Escape, Raw, Matches, Data_First => Next);
         exit when Matches (0) = No_Match;
         Append (Visible, Raw (Next .. Matches (0).First - 1));
         Next := Matches (0).Last + 1;
      end loop;
      Append (Visible, Raw (Next .. Raw'Last));
      return To_String (Visible);
   end Visible_Output;

   function Recent (Output : String) return String
   is (Output
         (Integer'Max (Output'First, Output'Last - 1_499) .. Output'Last));

   procedure Expect (Object : Session; Text : String) is
      Output : constant String := Visible_Output (Object);
   begin
      Check
        (Ada.Strings.Fixed.Index (Output, Text) > 0,
         "Expected " & Text & "; recent output: " & Recent (Output));
   end Expect;

   procedure Finish (Object : in out Session) is
      Status : Integer;
   begin
      Test_Processes.Wait_For_Exit (Object.Child, 3.0, Status);
      declare
         Restored      : Terminal_Mode :=
           Read_Mode (Handle (Object.Slave), Object.Original.Host);
         Original      : Terminal_Mode := Object.Original;
         -- Darwin's PENDIN reports pending input, not a terminal setting.
         Pending_Input : constant unsigned_long := 16#2000_0000#;
      begin
         if Original.Host = Darwin then
            Restored.Darwin_Mode.Local_Flags :=
              Restored.Darwin_Mode.Local_Flags and not Pending_Input;
            Original.Darwin_Mode.Local_Flags :=
              Original.Darwin_Mode.Local_Flags and not Pending_Input;
         end if;
         Check (Restored = Original, "Terminal mode was not restored");
      end;
      Object.Mode_Saved := False;
      if Status /= 0 then
         raise Program_Error
           with
             "Diary exited with status"
             & Status'Image
             & ": "
             & Recent (Visible_Output (Object));
      end if;
   end Finish;

   overriding
   procedure Finalize (Object : in out Session) is
      Original : aliased constant Terminal_Mode := Object.Original;
   begin
      Test_Processes.Stop (Object.Child);
      if Object.Mode_Saved then
         Check_Result
           (Set_Mode
              (Handle (Object.Slave),
               Apply_Immediately,
               Mode_Address (Original)),
            "Restore terminal mode during cleanup");
      end if;
   exception
      when Error : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Clean up terminal session: "
            & Ada.Exceptions.Exception_Message (Error));
   end Finalize;
end Test_Terminals;
