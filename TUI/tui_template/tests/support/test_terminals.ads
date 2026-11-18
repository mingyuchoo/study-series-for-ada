with Ada.Finalization;
with Ada.Strings.Unbounded;
with Interfaces.C;
with Test_POSIX;
with Test_Processes;

package Test_Terminals is
   type Session is new Ada.Finalization.Limited_Controlled with private;

   procedure Open
     (Object  : in out Session;
      Program : String;
      Options : Test_Processes.Arguments;
      Rows    : Positive := 30;
      Columns : Positive := 110);
   procedure Resize (Object : in out Session; Rows, Columns : Positive);
   procedure Send (Object : in out Session; Keys : String);
   procedure Expect (Object : Session; Text : String);
   procedure Finish (Object : in out Session);

private
   use Interfaces.C;

   type Linux_Control_Characters is array (1 .. 32) of unsigned_char
   with Convention => C;
   type Darwin_Control_Characters is array (1 .. 20) of unsigned_char
   with Convention => C;

   type Linux_Termios is record
      Input_Flags, Output_Flags, Control_Flags, Local_Flags : unsigned := 0;
      Line_Discipline                                       : unsigned_char :=
        0;
      Control_Characters                                    :
        Linux_Control_Characters := [others => 0];
      Input_Speed, Output_Speed                             : unsigned := 0;
   end record
   with Convention => C;

   type Darwin_Termios is record
      Input_Flags, Output_Flags, Control_Flags, Local_Flags : unsigned_long :=
        0;
      Control_Characters                                    :
        Darwin_Control_Characters := [others => 0];
      Input_Speed, Output_Speed                             : unsigned_long :=
        0;
   end record
   with Convention => C;

   type Terminal_Mode (Host : Test_POSIX.Host_Kind := Test_POSIX.Linux) is
   record
      case Host is
         when Test_POSIX.Linux =>
            Linux_Mode : aliased Linux_Termios;

         when Test_POSIX.Darwin =>
            Darwin_Mode : aliased Darwin_Termios;
      end case;
   end record;

   type Session is new Ada.Finalization.Limited_Controlled with record
      Master, Slave : Test_POSIX.Descriptor;
      Child         : Test_Processes.Process;
      Original      : Terminal_Mode;
      Mode_Saved    : Boolean := False;
      Output        : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   overriding
   procedure Finalize (Object : in out Session);
end Test_Terminals;
