with Ada.Text_IO;
with System;

package body Test_POSIX is
   use Interfaces.C;
   use GNAT.OS_Lib;

   function Uname (Information : System.Address) return int
   with Import, Convention => C, External_Name => "uname";

   function Fcntl (File : File_Descriptor; Command, Argument : int) return int
   with Import, Convention => C_Variadic_2, External_Name => "fcntl";

   function Host return Host_Kind is
      Information : aliased char_array (0 .. 4095);
   begin
      Check_Result (Uname (Information'Address), "Identify host");
      declare
         Name : constant String := To_Ada (Information);
      begin
         if Name = "Linux" then
            return Linux;
         elsif Name = "Darwin" then
            return Darwin;
         end if;
         raise Program_Error
           with "Integration tests require Linux or macOS; found " & Name;
      end;
   end Host;

   procedure Check_Result (Result : int; Operation : String) is
   begin
      if Result < 0 then
         raise Program_Error with Operation & ": " & Errno_Message;
      end if;
   end Check_Result;

   procedure Own
     (Object : in out Descriptor; Handle : File_Descriptor; Operation : String)
   is
      Set_Descriptor_Flags : constant := 2;
      Close_On_Exec        : constant := 1;
   begin
      Check_Result (int (Handle), Operation);
      Object.Value := Handle;
      Check_Result
        (Fcntl (Handle, Set_Descriptor_Flags, Close_On_Exec),
         "Mark descriptor close-on-exec");
   end Own;

   function Handle (Object : Descriptor) return File_Descriptor
   is (Object.Value);

   procedure Make_Nonblocking (Object : Descriptor; Platform : Host_Kind) is
      Get_Status_Flags : constant := 3;
      Set_Status_Flags : constant := 4;
      Nonblocking      : constant unsigned :=
        (case Platform is
           when Linux  => 16#800#,
           when Darwin => 4);
      Flags            : constant int :=
        Fcntl (Handle (Object), Get_Status_Flags, 0);
   begin
      Check_Result (Flags, "Read file status flags");
      Check_Result
        (Fcntl
           (Handle (Object),
            Set_Status_Flags,
            int (unsigned (Flags) or Nonblocking)),
         "Set nonblocking mode");
   end Make_Nonblocking;

   overriding
   procedure Finalize (Object : in out Descriptor) is
      Closed : Boolean;
   begin
      if Object.Value /= Invalid_FD then
         Close (Object.Value, Closed);
         Object.Value := Invalid_FD;
         if not Closed then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Close test descriptor: " & Errno_Message);
         end if;
      end if;
   end Finalize;
end Test_POSIX;
